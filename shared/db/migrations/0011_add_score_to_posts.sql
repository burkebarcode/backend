-- +goose Up
-- Add decimal score column (0.0-10.0 with 1 decimal precision)
ALTER TABLE posts ADD COLUMN score NUMERIC(3,1);

-- Add check constraint to ensure score is between 0.0 and 10.0
ALTER TABLE posts ADD CONSTRAINT chk_score CHECK (score IS NULL OR (score >= 0.0 AND score <= 10.0));

-- Make stars nullable since we're transitioning from stars to score
ALTER TABLE posts ALTER COLUMN stars DROP NOT NULL;

-- Drop the old stars constraint and add a new one that allows NULL
ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_stars;
ALTER TABLE posts ADD CONSTRAINT chk_stars CHECK (stars IS NULL OR (stars BETWEEN 1 AND 5));

-- +goose Down
-- Remove the constraints
ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_score;
ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_stars;

-- Restore original stars constraint
ALTER TABLE posts ADD CONSTRAINT chk_stars CHECK (stars BETWEEN 1 AND 5);

-- Make stars required again
ALTER TABLE posts ALTER COLUMN stars SET NOT NULL;

-- Remove the score column
ALTER TABLE posts DROP COLUMN IF EXISTS score;
