-- name: GetBeverageSummary :one
SELECT * FROM beverage_summaries WHERE beverage_id = $1;

-- name: UpsertBeverageSummary :one
INSERT INTO beverage_summaries (
  beverage_id, summary_text, descriptors_json, pros_json, cons_json,
  coverage_score, source_review_count, model, model_version
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
ON CONFLICT (beverage_id)
DO UPDATE SET
  summary_text = EXCLUDED.summary_text,
  descriptors_json = EXCLUDED.descriptors_json,
  pros_json = EXCLUDED.pros_json,
  cons_json = EXCLUDED.cons_json,
  coverage_score = EXCLUDED.coverage_score,
  source_review_count = EXCLUDED.source_review_count,
  model = EXCLUDED.model,
  model_version = EXCLUDED.model_version,
  generated_at = NOW(),
  updated_at = NOW()
RETURNING *;

-- name: DeleteBeverageSummary :exec
DELETE FROM beverage_summaries WHERE beverage_id = $1;

-- name: CreatePostTag :one
INSERT INTO post_tags (post_id, beverage_id, tag, tag_type, confidence)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetPostTags :many
SELECT * FROM post_tags WHERE post_id = $1;

-- name: DeletePostTags :exec
DELETE FROM post_tags WHERE post_id = $1;

-- name: GetBeverageTags :many
SELECT tag, tag_type, COUNT(*) as count
FROM post_tags
WHERE beverage_id = $1
GROUP BY tag, tag_type
ORDER BY count DESC, tag;

-- name: UpsertBeverageTagAggregate :exec
INSERT INTO beverage_tag_aggregates (beverage_id, tag, tag_type, count)
VALUES ($1, $2, $3, $4)
ON CONFLICT (beverage_id, tag, tag_type)
DO UPDATE SET
  count = EXCLUDED.count,
  updated_at = NOW();

-- name: GetBeverageTagAggregates :many
SELECT * FROM beverage_tag_aggregates
WHERE beverage_id = $1
ORDER BY count DESC, tag;

-- name: DeleteBeverageTagAggregates :exec
DELETE FROM beverage_tag_aggregates WHERE beverage_id = $1;

-- name: CreateOpenAIJob :one
INSERT INTO openai_jobs (job_type, beverage_id, post_id, status)
VALUES ($1, $2, $3, 'queued')
RETURNING *;

-- name: GetOpenAIJob :one
SELECT * FROM openai_jobs WHERE id = $1;

-- name: GetQueuedJobs :many
SELECT * FROM openai_jobs
WHERE status = 'queued'
ORDER BY created_at
LIMIT $1
FOR UPDATE SKIP LOCKED;

-- name: UpdateOpenAIJobStatus :exec
UPDATE openai_jobs
SET status = $2, attempts = $3, last_error = $4, updated_at = NOW()
WHERE id = $1;

-- name: DeleteOpenAIJob :exec
DELETE FROM openai_jobs WHERE id = $1;

-- name: GetPendingSummaryJob :one
SELECT * FROM openai_jobs
WHERE job_type = 'summary' AND beverage_id = $1 AND status IN ('queued', 'running')
ORDER BY created_at DESC
LIMIT 1;
