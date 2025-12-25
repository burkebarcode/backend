-- +goose Up
-- +goose StatementBegin
CREATE TABLE beverages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Basic info
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT NOT NULL,  -- 'beer' | 'wine' | 'cocktail' | 'other'

  -- Optional fields
  vintage TEXT,  -- Year for wines
  image_url TEXT,

  -- Normalized fields for searching
  name_normalized TEXT NOT NULL,
  brand_normalized TEXT,

  -- Aggregate statistics from posts
  total_reviews INT DEFAULT 0,
  avg_rating NUMERIC(3,2) DEFAULT 0.0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_name_len CHECK (char_length(name) > 0),
  CONSTRAINT chk_category CHECK (category IN ('wine', 'beer', 'cocktail', 'other'))
);

-- Indexes for fast searching
CREATE INDEX idx_beverages_name_normalized ON beverages(name_normalized);
CREATE INDEX idx_beverages_brand_normalized ON beverages(brand_normalized);
CREATE INDEX idx_beverages_category ON beverages(category);
CREATE INDEX idx_beverages_avg_rating ON beverages(avg_rating DESC);

-- Trigger for updated_at
CREATE TRIGGER trg_beverages_updated_at
BEFORE UPDATE ON beverages
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose StatementEnd

-- +goose Down
DROP TRIGGER IF EXISTS trg_beverages_updated_at ON beverages;
DROP TABLE IF EXISTS beverages;
