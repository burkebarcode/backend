-- +goose Up
-- +goose StatementBegin

-- Add beverage_id to posts table for linking posts to canonical beverages
ALTER TABLE posts ADD COLUMN beverage_id UUID REFERENCES beverages(id) ON DELETE SET NULL;
CREATE INDEX idx_posts_beverage_id ON posts(beverage_id) WHERE beverage_id IS NOT NULL;

-- Beverage summaries: AI-generated "what people say" summaries
CREATE TABLE beverage_summaries (
  beverage_id UUID PRIMARY KEY REFERENCES beverages(id) ON DELETE CASCADE,
  summary_text TEXT NOT NULL,
  descriptors_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  pros_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  cons_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  coverage_score NUMERIC(3,2) DEFAULT 0.0 CHECK (coverage_score >= 0.0 AND coverage_score <= 1.0),
  source_review_count INT DEFAULT 0,
  model TEXT,
  model_version TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_beverage_summaries_updated_at
BEFORE UPDATE ON beverage_summaries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Post tags: AI-extracted tags from individual post notes
CREATE TABLE post_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  beverage_id UUID REFERENCES beverages(id) ON DELETE SET NULL,
  tag TEXT NOT NULL,
  tag_type TEXT NOT NULL CHECK (tag_type IN ('descriptor', 'style', 'region', 'varietal', 'structure', 'other')),
  confidence NUMERIC(3,2) DEFAULT 1.0 CHECK (confidence >= 0.0 AND confidence <= 1.0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_post_tags_post_id ON post_tags(post_id);
CREATE INDEX idx_post_tags_beverage_id ON post_tags(beverage_id) WHERE beverage_id IS NOT NULL;
CREATE INDEX idx_post_tags_tag ON post_tags(tag);
CREATE INDEX idx_post_tags_tag_type ON post_tags(tag_type);

-- Beverage tag aggregates: Pre-computed tag counts per beverage
CREATE TABLE beverage_tag_aggregates (
  beverage_id UUID NOT NULL REFERENCES beverages(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  tag_type TEXT NOT NULL,
  count INT NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (beverage_id, tag, tag_type)
);

CREATE INDEX idx_beverage_tag_aggregates_beverage_id ON beverage_tag_aggregates(beverage_id);
CREATE INDEX idx_beverage_tag_aggregates_tag ON beverage_tag_aggregates(tag);

CREATE TRIGGER trg_beverage_tag_aggregates_updated_at
BEFORE UPDATE ON beverage_tag_aggregates
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- OpenAI jobs: Async job queue for AI processing
CREATE TABLE openai_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_type TEXT NOT NULL CHECK (job_type IN ('summary', 'post_tagging')),
  beverage_id UUID REFERENCES beverages(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
  attempts INT DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_openai_jobs_status ON openai_jobs(status, created_at);
CREATE INDEX idx_openai_jobs_beverage_id ON openai_jobs(beverage_id) WHERE beverage_id IS NOT NULL;
CREATE INDEX idx_openai_jobs_post_id ON openai_jobs(post_id) WHERE post_id IS NOT NULL;

CREATE TRIGGER trg_openai_jobs_updated_at
BEFORE UPDATE ON openai_jobs
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose StatementEnd

-- +goose Down
DROP TRIGGER IF EXISTS trg_openai_jobs_updated_at ON openai_jobs;
DROP TABLE IF EXISTS openai_jobs;

DROP TRIGGER IF EXISTS trg_beverage_tag_aggregates_updated_at ON beverage_tag_aggregates;
DROP TABLE IF EXISTS beverage_tag_aggregates;

DROP INDEX IF EXISTS idx_post_tags_tag_type;
DROP INDEX IF EXISTS idx_post_tags_tag;
DROP INDEX IF EXISTS idx_post_tags_beverage_id;
DROP INDEX IF EXISTS idx_post_tags_post_id;
DROP TABLE IF EXISTS post_tags;

DROP TRIGGER IF EXISTS trg_beverage_summaries_updated_at ON beverage_summaries;
DROP TABLE IF EXISTS beverage_summaries;

DROP INDEX IF EXISTS idx_posts_beverage_id;
ALTER TABLE posts DROP COLUMN IF EXISTS beverage_id;
