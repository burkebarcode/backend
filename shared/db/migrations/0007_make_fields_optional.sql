-- +goose Up
-- Make stars and notes optional in posts table
ALTER TABLE posts ALTER COLUMN stars DROP NOT NULL;
ALTER TABLE posts ALTER COLUMN notes DROP NOT NULL;

-- Update the constraint to allow NULL stars
ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_stars;
ALTER TABLE posts ADD CONSTRAINT chk_stars CHECK (stars IS NULL OR stars BETWEEN 1 AND 5);

-- +goose Down
-- Revert stars and notes to NOT NULL
-- Note: This migration down will fail if there are posts without stars or notes
UPDATE posts SET stars = 3 WHERE stars IS NULL;
UPDATE posts SET notes = '' WHERE notes IS NULL;

ALTER TABLE posts ALTER COLUMN stars SET NOT NULL;
ALTER TABLE posts ALTER COLUMN notes SET NOT NULL;

ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_stars;
ALTER TABLE posts ADD CONSTRAINT chk_stars CHECK (stars BETWEEN 1 AND 5);
