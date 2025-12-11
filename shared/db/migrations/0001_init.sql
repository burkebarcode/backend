-- +goose Up
-- +goose StatementBegin
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- +goose StatementEnd

-- USERS
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  handle TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  oauth_provider TEXT,
  oauth_subject TEXT,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_handle_len CHECK (char_length(handle) >= 2),
  CONSTRAINT chk_handle_lower CHECK (handle = lower(handle))
);

-- One oauth identity per provider (only when oauth fields are set)
CREATE UNIQUE INDEX uniq_users_oauth
ON users(oauth_provider, oauth_subject)
WHERE oauth_provider IS NOT NULL;


-- VENUES
CREATE TABLE venues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  venue_type TEXT NOT NULL DEFAULT 'bar',  -- 'bar' | 'restaurant' etc.
  address TEXT,
  city TEXT,
  state TEXT,
  country TEXT DEFAULT 'US',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  has_beer SMALLINT DEFAULT 0,
  has_wine SMALLINT DEFAULT 0,
  has_cocktails SMALLINT DEFAULT 0,
  map_provider varchar(48),
  external_place_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_lat CHECK (lat IS NULL OR lat BETWEEN -90 AND 90),
  CONSTRAINT chk_lng CHECK (lng IS NULL OR lng BETWEEN -180 AND 180)
);

-- Drink types
--CREATE TABLE drink_categories (
  --id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  --name TEXT NOT NULL,    -- 'beer' | 'wine' | 'cocktail'
  --created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  --updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), 
--);

--ALTER TABLE drink_categories ADD CONSTRAINT unique_name UNIQUE (name);

-- cocktails
CREATE TABLE cocktail_post_details (
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

-- beer
CREATE TABLE beer_post_details (
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

-- wine
CREATE TABLE wine_post_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  sweetness TEXT,
  body TEXT,
  tannin TEXT,
  acidity TEXT,
  wine_style TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);



-- POSTS (ARE RATINGS)
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,

  drink_name TEXT NOT NULL,
  drink_category TEXT NOT NULL,    -- 'beer' | 'wine' | 'cocktail'
  --drink_category_id UUID NOT NULL REFERENCES drink_categories(id) ON DELETE CASCADE,

  stars INT NOT NULL,              -- 1..5
  notes TEXT NOT NULL DEFAULT '',  -- your "notes-like" feature
  wine_post_details_id UUID REFERENCES wine_post_details(id) ON DELETE CASCADE,
  beer_post_details_id UUID REFERENCES beer_post_details(id) ON DELETE CASCADE,
  cocktail_post_details_id UUID REFERENCES cocktail_post_details(id) ON DELETE CASCADE,

  price_cents INT,
  photo_url TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_stars CHECK (stars BETWEEN 1 AND 5),
  CONSTRAINT chk_drink_name_len CHECK (char_length(drink_name) > 0)
);

-- FK + sort indexes (important for performance)
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_venue_id ON posts(venue_id);
CREATE INDEX idx_posts_created_at ON posts(created_at);


-- UPDATED_AT TRIGGERS
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';
-- +goose StatementEnd

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_venues_updated_at
BEFORE UPDATE ON venues
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_posts_updated_at
BEFORE UPDATE ON posts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- +goose Down
DROP TRIGGER IF EXISTS trg_posts_updated_at ON posts;
DROP TRIGGER IF EXISTS trg_venues_updated_at ON venues;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;

DROP FUNCTION IF EXISTS set_updated_at;

DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS venues;
DROP TABLE IF EXISTS users;

