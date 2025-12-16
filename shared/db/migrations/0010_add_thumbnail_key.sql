-- +goose Up
-- Add thumbnail_object_key to media table
ALTER TABLE media ADD COLUMN IF NOT EXISTS thumbnail_object_key TEXT;

-- +goose Down
ALTER TABLE media DROP COLUMN IF EXISTS thumbnail_object_key;
