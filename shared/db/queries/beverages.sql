-- name: CreateBeverage :one
INSERT INTO beverages (name, brand, category, vintage, image_url, name_normalized, brand_normalized)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetBeverageByID :one
SELECT * FROM beverages WHERE id = $1;

-- name: SearchBeveragesByTokens :many
SELECT
  b.*,
  -- Calculate match score
  (
    -- Exact name match (highest priority)
    CASE WHEN b.name_normalized = $1 THEN 100 ELSE 0 END +
    -- Name prefix match
    CASE WHEN b.name_normalized LIKE $1 || '%' THEN 50 ELSE 0 END +
    -- Name contains match
    CASE WHEN b.name_normalized LIKE '%' || $1 || '%' THEN 25 ELSE 0 END +
    -- Brand exact match
    CASE WHEN b.brand_normalized = $2 THEN 80 ELSE 0 END +
    -- Brand prefix match
    CASE WHEN b.brand_normalized LIKE $2 || '%' THEN 40 ELSE 0 END +
    -- Brand contains match
    CASE WHEN b.brand_normalized LIKE '%' || $2 || '%' THEN 20 ELSE 0 END +
    -- Vintage exact match bonus
    CASE WHEN $3::TEXT IS NOT NULL AND b.vintage = $3::TEXT THEN 30 ELSE 0 END +
    -- Category match bonus
    CASE WHEN b.category = $4 THEN 10 ELSE 0 END
  ) as match_score
FROM beverages b
WHERE
  (
    b.name_normalized LIKE '%' || $1 || '%' OR
    b.brand_normalized LIKE '%' || $2 || '%' OR
    ($3::TEXT IS NOT NULL AND b.vintage = $3::TEXT)
  )
ORDER BY match_score DESC, b.avg_rating DESC
LIMIT $5;

-- name: GetPostsForBeverage :many
SELECT p.* FROM posts p
WHERE
  (p.drink_name = $1 OR LOWER(p.drink_name) = $2) AND
  ($3::TEXT IS NULL OR p.drink_category = $3)
ORDER BY p.created_at DESC
LIMIT $4;

-- name: GetTopReviewsForBeverage :many
SELECT p.* FROM posts p
WHERE
  (p.drink_name = $1 OR LOWER(p.drink_name) = $2) AND
  ($3::TEXT IS NULL OR p.drink_category = $3) AND
  p.score IS NOT NULL
ORDER BY p.score DESC, p.created_at DESC
LIMIT $4;

-- name: UpdateBeverageStats :exec
UPDATE beverages
SET
  total_reviews = $2,
  avg_rating = $3,
  updated_at = NOW()
WHERE id = $1;
