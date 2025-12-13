-- +goose Up
-- Make venue_id nullable in posts table
ALTER TABLE posts ALTER COLUMN venue_id DROP NOT NULL;

-- Update the index to handle NULL values
DROP INDEX IF EXISTS idx_posts_venue_id;
CREATE INDEX idx_posts_venue_id ON posts(venue_id) WHERE venue_id IS NOT NULL;

-- +goose Down
-- Revert venue_id to NOT NULL (this requires all posts to have a venue)
-- Note: This migration down will fail if there are posts without venues
ALTER TABLE posts ALTER COLUMN venue_id SET NOT NULL;

-- Restore original index
DROP INDEX IF EXISTS idx_posts_venue_id;
CREATE INDEX idx_posts_venue_id ON posts(venue_id);
