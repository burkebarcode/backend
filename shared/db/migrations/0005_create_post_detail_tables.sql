-- +goose Up
-- Create detail tables that were missing from initial migration
CREATE TABLE IF NOT EXISTS cocktail_post_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  base_spirit TEXT,
  cocktail_family TEXT,
  preparation TEXT,
  presentation TEXT,
  garnish TEXT,
  sweetness TEXT,
  booziness TEXT,
  balance TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS beer_post_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  brewery TEXT,
  abv NUMERIC(4,2),
  ibu INTEGER,
  acidity TEXT,
  beer_style TEXT,
  serving TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS wine_post_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sweetness TEXT,
  body TEXT,
  tannin TEXT,
  acidity TEXT,
  wine_style TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add detail columns to posts table
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS wine_post_details_id UUID REFERENCES wine_post_details(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS beer_post_details_id UUID REFERENCES beer_post_details(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS cocktail_post_details_id UUID REFERENCES cocktail_post_details(id) ON DELETE CASCADE;

-- +goose Down
ALTER TABLE posts
  DROP COLUMN IF EXISTS wine_post_details_id,
  DROP COLUMN IF EXISTS beer_post_details_id,
  DROP COLUMN IF EXISTS cocktail_post_details_id;

DROP TABLE IF EXISTS wine_post_details;
DROP TABLE IF EXISTS beer_post_details;
DROP TABLE IF EXISTS cocktail_post_details;
