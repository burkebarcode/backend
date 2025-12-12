-- name: CreateVenue :one
INSERT INTO venues (name, description, venue_type, address, city, state, country, lat, lng, has_beer, has_wine, has_cocktails, map_provider, external_place_id, user_id, is_public)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
RETURNING *;

-- name: GetVenueByID :one
SELECT * FROM venues WHERE id = $1;

-- name: ListVenues :many
SELECT * FROM venues
WHERE is_public = 1 OR user_id = $1
ORDER BY created_at DESC
LIMIT $2;

-- name: SearchVenues :many
SELECT * FROM venues
WHERE (is_public = 1 OR user_id = $1)
  AND (name ILIKE '%' || $2 || '%'
   OR city ILIKE '%' || $2 || '%'
   OR address ILIKE '%' || $2 || '%')
ORDER BY created_at DESC
LIMIT $3;

-- name: GetVenueByExternalPlaceID :one
SELECT * FROM venues WHERE external_place_id = $1 LIMIT 1;
