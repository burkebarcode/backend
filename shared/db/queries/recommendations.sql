-- User Taste Profiles

-- name: GetUserTasteProfile :one
SELECT * FROM user_taste_profiles
WHERE user_id = $1 AND category = $2;

-- name: UpsertUserTasteProfile :one
INSERT INTO user_taste_profiles (
  user_id, category, liked_tags_json, disliked_tags_json,
  mean_rating, std_rating, post_count, last_computed_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, now())
ON CONFLICT (user_id, category)
DO UPDATE SET
  liked_tags_json = EXCLUDED.liked_tags_json,
  disliked_tags_json = EXCLUDED.disliked_tags_json,
  mean_rating = EXCLUDED.mean_rating,
  std_rating = EXCLUDED.std_rating,
  post_count = EXCLUDED.post_count,
  last_computed_at = EXCLUDED.last_computed_at
RETURNING *;

-- name: GetUserPostsForCategory :many
SELECT p.*, pt.tag, pt.tag_type, pt.confidence
FROM posts p
LEFT JOIN post_tags pt ON p.id = pt.post_id
WHERE p.user_id = $1
  AND p.drink_category = $2
ORDER BY p.created_at DESC;

-- name: GetUserPostCountByCategory :one
SELECT COUNT(*) AS count
FROM posts
WHERE user_id = $1 AND drink_category = $2;

-- Recommendation Feedback

-- name: CreateRecommendationFeedback :one
INSERT INTO recommendation_feedback (user_id, beverage_id, feedback_type)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, beverage_id, feedback_type) DO NOTHING
RETURNING *;

-- name: GetUserFeedback :many
SELECT * FROM recommendation_feedback
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: GetUserFeedbackForBeverage :many
SELECT * FROM recommendation_feedback
WHERE user_id = $1 AND beverage_id = $2;

-- name: GetHiddenBeveragesForUser :many
SELECT beverage_id FROM recommendation_feedback
WHERE user_id = $1 AND feedback_type = 'hide';

-- name: DeleteFeedback :exec
DELETE FROM recommendation_feedback
WHERE user_id = $1 AND beverage_id = $2 AND feedback_type = $3;

-- Recommendation Candidates

-- name: GetRecommendationCandidates :many
SELECT b.id, b.name, b.brand, b.category, b.image_url, b.created_at, b.updated_at,
       COUNT(DISTINCT p.id) AS review_count,
       COALESCE(AVG(
         CASE
           WHEN p.score IS NOT NULL AND p.score != 0 THEN p.score
           WHEN p.stars IS NOT NULL THEN p.stars * 2.0
           ELSE NULL
         END
       ), 0) AS avg_rating
FROM beverages b
LEFT JOIN posts p ON b.id = p.beverage_id
WHERE b.category = $1
  AND b.id NOT IN (
    SELECT rf.beverage_id FROM recommendation_feedback rf
    WHERE rf.user_id = $2 AND rf.feedback_type = 'hide'
  )
  AND b.id NOT IN (
    SELECT p2.beverage_id FROM posts p2
    WHERE p2.user_id = $2 AND p2.beverage_id IS NOT NULL
    ORDER BY p2.created_at DESC
    LIMIT 20
  )
GROUP BY b.id, b.name, b.brand, b.category, b.image_url, b.created_at, b.updated_at
HAVING COUNT(DISTINCT p.id) >= 2 OR EXISTS (
  SELECT 1 FROM beverage_tag_aggregates bta
  WHERE bta.beverage_id = b.id
)
ORDER BY review_count DESC, avg_rating DESC
LIMIT $3;

-- name: GetBeverageWithTags :one
SELECT b.*,
       COALESCE(
         json_agg(
           json_build_object(
             'tag', bta.tag,
             'tag_type', bta.tag_type,
             'count', bta.count
           )
         ) FILTER (WHERE bta.tag IS NOT NULL),
         '[]'::json
       ) AS tags_json
FROM beverages b
LEFT JOIN beverage_tag_aggregates bta ON b.id = bta.beverage_id
WHERE b.id = $1
GROUP BY b.id;

-- User Embeddings (optional)

-- name: GetUserEmbedding :one
SELECT * FROM user_embeddings
WHERE user_id = $1 AND category = $2;

-- name: UpsertUserEmbedding :one
INSERT INTO user_embeddings (user_id, category, embedding_text, embedding_vector, model)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (user_id, category)
DO UPDATE SET
  embedding_text = EXCLUDED.embedding_text,
  embedding_vector = EXCLUDED.embedding_vector,
  model = EXCLUDED.model
RETURNING *;
