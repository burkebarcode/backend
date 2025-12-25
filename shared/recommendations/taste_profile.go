package recommendations

import (
	"context"
	"encoding/json"
	"log"
	"math"

	"github.com/burkebarcode/backend/shared/db/sqlc"
	"github.com/jackc/pgx/v5/pgtype"
)

// TagWeights represents weighted preferences for tags
type TagWeights map[string]float64

// TasteProfileComputer computes and updates user taste profiles
type TasteProfileComputer struct {
	Q *sqlc.Queries
}

func NewTasteProfileComputer(q *sqlc.Queries) *TasteProfileComputer {
	return &TasteProfileComputer{Q: q}
}

// ComputeProfile computes the taste profile for a user in a category based on their posts
func (c *TasteProfileComputer) ComputeProfile(ctx context.Context, userID pgtype.UUID, category string) error {
	// Get user's posts with tags for this category
	posts, err := c.Q.GetUserPostsForCategory(ctx, sqlc.GetUserPostsForCategoryParams{
		UserID:        userID,
		DrinkCategory: category,
	})
	if err != nil {
		return err
	}

	if len(posts) == 0 {
		// No posts yet, create empty profile
		emptyLiked, _ := json.Marshal(TagWeights{})
		emptyDisliked, _ := json.Marshal(TagWeights{})
		_, err := c.Q.UpsertUserTasteProfile(ctx, sqlc.UpsertUserTasteProfileParams{
			UserID:           userID,
			Category:         category,
			LikedTagsJson:    emptyLiked,
			DislikedTagsJson: emptyDisliked,
			MeanRating:       pgtype.Numeric{Valid: false},
			StdRating:        pgtype.Numeric{Valid: false},
			PostCount:        pgtype.Int4{Int32: 0, Valid: true},
		})
		return err
	}

	// Calculate rating statistics
	ratings := []float64{}
	for _, post := range posts {
		var rating float64
		if post.Score.Valid {
			f, _ := post.Score.Float64Value()
			rating = f.Float64
		} else if post.Stars.Valid {
			rating = float64(post.Stars.Int32) * 2.0
		}
		if rating > 0 {
			ratings = append(ratings, rating)
		}
	}

	var meanRating, stdRating float64
	if len(ratings) > 0 {
		meanRating = mean(ratings)
		stdRating = stdDev(ratings, meanRating)
	}

	// Compute tag weights based on ratings
	likedTags := make(TagWeights)
	dislikedTags := make(TagWeights)

	// Group posts by rating threshold
	// High rating: > mean + 0.5*std
	// Low rating: < mean - 0.5*std
	highThreshold := meanRating + 0.5*stdRating
	lowThreshold := meanRating - 0.5*stdRating

	for _, post := range posts {
		var rating float64
		if post.Score.Valid {
			f, _ := post.Score.Float64Value()
			rating = f.Float64
		} else if post.Stars.Valid {
			rating = float64(post.Stars.Int32) * 2.0
		}

		if rating == 0 || !post.Tag.Valid {
			continue
		}

		tag := post.Tag.String
		confidence := 1.0
		if post.Confidence.Valid {
			f, _ := post.Confidence.Float64Value()
			confidence = f.Float64
		}

		// Weight contribution based on rating and confidence
		weight := confidence

		if rating >= highThreshold {
			// Liked tag
			likedTags[tag] += weight
		} else if rating <= lowThreshold {
			// Disliked tag
			dislikedTags[tag] += weight
		}
	}

	// Normalize weights (0-1 scale)
	normalizeWeights(likedTags)
	normalizeWeights(dislikedTags)

	// Store profile
	likedJSON, _ := json.Marshal(likedTags)
	dislikedJSON, _ := json.Marshal(dislikedTags)

	meanRatingPg := pgtype.Numeric{}
	meanRatingPg.Scan(meanRating)
	stdRatingPg := pgtype.Numeric{}
	stdRatingPg.Scan(stdRating)

	_, err = c.Q.UpsertUserTasteProfile(ctx, sqlc.UpsertUserTasteProfileParams{
		UserID:           userID,
		Category:         category,
		LikedTagsJson:    likedJSON,
		DislikedTagsJson: dislikedJSON,
		MeanRating:       meanRatingPg,
		StdRating:        stdRatingPg,
		PostCount:        pgtype.Int4{Int32: int32(len(posts)), Valid: true},
	})

	return err
}

// UpdateProfileWithFeedback incrementally updates taste profile based on explicit feedback
func (c *TasteProfileComputer) UpdateProfileWithFeedback(ctx context.Context, userID pgtype.UUID, beverageID pgtype.UUID, feedbackType string) error {
	// Get beverage tags
	beverage, err := c.Q.GetBeverageWithTags(ctx, beverageID)
	if err != nil {
		return err
	}

	// Parse existing tags from JSON
	var beverageTags []struct {
		Tag     string `json:"tag"`
		TagType string `json:"tag_type"`
		Count   int    `json:"count"`
	}
	if beverage.TagsJson != nil {
		if tagsBytes, ok := beverage.TagsJson.([]byte); ok {
			json.Unmarshal(tagsBytes, &beverageTags)
		}
	}

	if len(beverageTags) == 0 {
		log.Printf("No tags for beverage %v, skipping taste profile update", beverageID)
		return nil
	}

	category := beverage.Category

	// Get or create taste profile
	profile, err := c.Q.GetUserTasteProfile(ctx, sqlc.GetUserTasteProfileParams{
		UserID:   userID,
		Category: category,
	})
	if err != nil {
		// Profile doesn't exist, compute it first
		if err := c.ComputeProfile(ctx, userID, category); err != nil {
			return err
		}
		profile, err = c.Q.GetUserTasteProfile(ctx, sqlc.GetUserTasteProfileParams{
			UserID:   userID,
			Category: category,
		})
		if err != nil {
			return err
		}
	}

	// Parse existing weights
	var likedTags TagWeights
	var dislikedTags TagWeights
	json.Unmarshal(profile.LikedTagsJson, &likedTags)
	json.Unmarshal(profile.DislikedTagsJson, &dislikedTags)

	// Update weights based on feedback
	feedbackWeight := 0.5 // Base weight for feedback

	for _, tag := range beverageTags {
		tagName := tag.Tag

		switch feedbackType {
		case "more_like_this":
			likedTags[tagName] += feedbackWeight
			// Reduce dislike if present
			if dislikedTags[tagName] > 0 {
				dislikedTags[tagName] = math.Max(0, dislikedTags[tagName]-feedbackWeight)
			}
		case "less_like_this":
			dislikedTags[tagName] += feedbackWeight
			// Reduce like if present
			if likedTags[tagName] > 0 {
				likedTags[tagName] = math.Max(0, likedTags[tagName]-feedbackWeight)
			}
		case "hide":
			// Don't modify weights for hide, just exclude in queries
			continue
		}
	}

	// Normalize weights
	normalizeWeights(likedTags)
	normalizeWeights(dislikedTags)

	// Update profile
	likedJSON, _ := json.Marshal(likedTags)
	dislikedJSON, _ := json.Marshal(dislikedTags)

	_, err = c.Q.UpsertUserTasteProfile(ctx, sqlc.UpsertUserTasteProfileParams{
		UserID:           userID,
		Category:         category,
		LikedTagsJson:    likedJSON,
		DislikedTagsJson: dislikedJSON,
		MeanRating:       profile.MeanRating,
		StdRating:        profile.StdRating,
		PostCount:        profile.PostCount,
	})

	return err
}

// Helper functions

func mean(values []float64) float64 {
	if len(values) == 0 {
		return 0
	}
	sum := 0.0
	for _, v := range values {
		sum += v
	}
	return sum / float64(len(values))
}

func stdDev(values []float64, mean float64) float64 {
	if len(values) <= 1 {
		return 0
	}
	variance := 0.0
	for _, v := range values {
		diff := v - mean
		variance += diff * diff
	}
	return math.Sqrt(variance / float64(len(values)-1))
}

func normalizeWeights(weights TagWeights) {
	if len(weights) == 0 {
		return
	}

	// Find max weight
	maxWeight := 0.0
	for _, w := range weights {
		if w > maxWeight {
			maxWeight = w
		}
	}

	if maxWeight == 0 {
		return
	}

	// Normalize to 0-1
	for tag, weight := range weights {
		weights[tag] = weight / maxWeight
	}
}
