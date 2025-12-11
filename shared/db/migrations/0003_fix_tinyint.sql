-- +goose Up
-- Fix TINYINT columns (MySQL type) to SMALLINT (PostgreSQL type)
ALTER TABLE venues
  ALTER COLUMN has_beer TYPE SMALLINT,
  ALTER COLUMN has_wine TYPE SMALLINT,
  ALTER COLUMN has_cocktails TYPE SMALLINT;

-- +goose Down
-- Revert is not possible since TINYINT doesn't exist in PostgreSQL
