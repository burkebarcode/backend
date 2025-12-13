-- name: CreatePost :one
INSERT INTO posts (user_id, venue_id, drink_name, drink_category, stars, notes, beer_post_details_id, wine_post_details_id, cocktail_post_details_id)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: CreateBeerPostDetails :one
INSERT INTO beer_post_details (brewery, abv, ibu, acidity, beer_style, serving)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: CreateWinePostDetails :one
INSERT INTO wine_post_details (sweetness, body, tannin, acidity, wine_style)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: CreateCocktailPostDetails :one
INSERT INTO cocktail_post_details (base_spirit, cocktail_family, preparation, presentation, garnish, sweetness, booziness, balance)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetPostByID :one
SELECT * FROM posts WHERE id = $1;

-- name: ListPosts :many
SELECT * FROM posts ORDER BY created_at DESC LIMIT $1;

-- name: ListPostsByExternalPlaceID :many
SELECT p.* FROM posts p
JOIN venues v ON p.venue_id = v.id
WHERE v.external_place_id = $1
ORDER BY p.created_at DESC;

-- name: GetWinePostDetails :one
SELECT * FROM wine_post_details WHERE id = $1;

-- name: GetBeerPostDetails :one
SELECT * FROM beer_post_details WHERE id = $1;

-- name: GetCocktailPostDetails :one
SELECT * FROM cocktail_post_details WHERE id = $1;

-- name: UpdatePost :one
UPDATE posts
SET drink_name = $2, stars = $3, notes = $4, updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeletePost :exec
DELETE FROM posts WHERE id = $1;

-- name: UpdateWinePostDetails :one
UPDATE wine_post_details
SET sweetness = $2, body = $3, tannin = $4, acidity = $5, wine_style = $6
WHERE id = $1
RETURNING *;

-- name: UpdateBeerPostDetails :one
UPDATE beer_post_details
SET brewery = $2, abv = $3, ibu = $4, acidity = $5, beer_style = $6, serving = $7
WHERE id = $1
RETURNING *;

-- name: UpdateCocktailPostDetails :one
UPDATE cocktail_post_details
SET base_spirit = $2, cocktail_family = $3, preparation = $4, presentation = $5, garnish = $6, sweetness = $7, booziness = $8, balance = $9
WHERE id = $1
RETURNING *;

