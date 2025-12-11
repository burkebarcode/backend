-- +goose Up
-- Add user_id and is_public to venues table
ALTER TABLE venues
  ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN is_public SMALLINT DEFAULT 1;

-- Create index for user_id queries
CREATE INDEX idx_venues_user_id ON venues(user_id);

-- +goose Down
DROP INDEX IF EXISTS idx_venues_user_id;
ALTER TABLE venues
  DROP COLUMN user_id,
  DROP COLUMN is_public;
