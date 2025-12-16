-- name: CreateMedia :one
INSERT INTO media (user_id, bucket, object_key, content_type, size_bytes, width, height, status, thumbnail_object_key)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: GetMediaByID :one
SELECT * FROM media WHERE id = $1;

-- name: GetMediaByObjectKey :one
SELECT * FROM media WHERE object_key = $1;

-- name: UpdateMediaStatus :one
UPDATE media
SET status = $2, updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: UpdateMediaMetadata :one
UPDATE media
SET etag = $2, size_bytes = $3, width = $4, height = $5, updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: AttachMediaToPost :one
INSERT INTO post_media (post_id, media_id, sort_order)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetMediaForPost :many
SELECT m.* FROM media m
JOIN post_media pm ON m.id = pm.media_id
WHERE pm.post_id = $1
AND m.object_key NOT LIKE '%_thumb.jpg'
ORDER BY pm.sort_order ASC;

-- name: GetThumbnailForPost :one
SELECT object_key FROM media
WHERE object_key LIKE $1 || '%_thumb.jpg'
AND object_key LIKE '%_thumb.jpg'
LIMIT 1;

-- name: DeleteStagedMediaOlderThan :exec
DELETE FROM media
WHERE status = 'staged' AND created_at < $1;
