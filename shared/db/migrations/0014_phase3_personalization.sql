-- +goose Up
-- +goose StatementBegin

-- User taste profiles: per-user learned preferences for personalized recommendations
CREATE TABLE user_taste_profiles (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('wine', 'beer', 'cocktail')),
  liked_tags_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  disliked_tags_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  mean_rating NUMERIC(4,2) DEFAULT 0.0,
  std_rating NUMERIC(4,2) DEFAULT 0.0,
  post_count INT DEFAULT 0,
  last_computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

CREATE INDEX idx_user_taste_profiles_user_id ON user_taste_profiles(user_id);
CREATE INDEX idx_user_taste_profiles_updated_at ON user_taste_profiles(updated_at);

CREATE TRIGGER trg_user_taste_profiles_updated_at
BEFORE UPDATE ON user_taste_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Recommendation feedback: user explicit feedback on recommendations
CREATE TABLE recommendation_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  beverage_id UUID NOT NULL REFERENCES beverages(id) ON DELETE CASCADE,
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('more_like_this', 'less_like_this', 'hide')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, beverage_id, feedback_type)
);

CREATE INDEX idx_recommendation_feedback_user_id ON recommendation_feedback(user_id);
CREATE INDEX idx_recommendation_feedback_beverage_id ON recommendation_feedback(beverage_id);
CREATE INDEX idx_recommendation_feedback_type ON recommendation_feedback(feedback_type);

-- User embeddings (optional, behind RECO_EMBEDDINGS_ENABLED flag)
CREATE TABLE user_embeddings (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('wine', 'beer', 'cocktail')),
  embedding_text TEXT NOT NULL, -- concatenated tags/notes for re-embedding
  embedding_vector FLOAT4[], -- stored vector from OpenAI embeddings API
  model TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

CREATE INDEX idx_user_embeddings_user_id ON user_embeddings(user_id);

CREATE TRIGGER trg_user_embeddings_updated_at
BEFORE UPDATE ON user_embeddings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose StatementEnd

-- +goose Down
DROP TRIGGER IF EXISTS trg_user_embeddings_updated_at ON user_embeddings;
DROP TABLE IF EXISTS user_embeddings;

DROP INDEX IF EXISTS idx_recommendation_feedback_type;
DROP INDEX IF EXISTS idx_recommendation_feedback_beverage_id;
DROP INDEX IF EXISTS idx_recommendation_feedback_user_id;
DROP TABLE IF EXISTS recommendation_feedback;

DROP TRIGGER IF EXISTS trg_user_taste_profiles_updated_at ON user_taste_profiles;
DROP INDEX IF EXISTS idx_user_taste_profiles_updated_at;
DROP INDEX IF EXISTS idx_user_taste_profiles_user_id;
DROP TABLE IF EXISTS user_taste_profiles;
