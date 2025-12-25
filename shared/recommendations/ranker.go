package recommendations

import (
	"context"
	"encoding/json"
	"log"
	"math"
	"sort"

	"github.com/burkebarcode/backend/shared/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// RecommendationReason describes why a beverage was recommended
type RecommendationReason struct {
	Reason string  `json:"reason"`
	Score  float64 `json:"score"`
}

// RankedBeverage represents a recommended beverage with score and reasons
type RankedBeverage struct {
	BeverageID  string                  `json:"beverage_id"`
	Name        string                  `json:"name"`
	Brand       string                  `json:"brand,omitempty"`
	Category    string                  `json:"category"`
	MatchScore  int                     `json:"match_score"` // 0-100
	Reasons     []string                `json:"reasons"`
	AvgRating   float64                 `json:"avg_rating"`
	ReviewCount int                     `json:"review_count"`
}

// Ranker ranks beverages for personalized recommendations
type Ranker struct {
	Q *sqlc.Queries
}

func NewRanker(q *sqlc.Queries) *Ranker {
	return &Ranker{Q: q}
}

// RankRecommendations generates personalized recommendations for a user
func (r *Ranker) RankRecommendations(ctx context.Context, userID pgtype.UUID, category string, limit int32) ([]RankedBeverage, error) {
	// Get user's taste profile
	profile, err := r.Q.GetUserTasteProfile(ctx, sqlc.GetUserTasteProfileParams{
		UserID:   userID,
		Category: category,
	})

	var likedTags TagWeights
	var dislikedTags TagWeights
	coldStart := false

	if err != nil {
		// Cold start: user has no taste profile
		log.Printf("No taste profile for user, using cold-start recommendations")
		coldStart = true
		likedTags = make(TagWeights)
		dislikedTags = make(TagWeights)
	} else {
		json.Unmarshal(profile.LikedTagsJson, &likedTags)
		json.Unmarshal(profile.DislikedTagsJson, &dislikedTags)

		// Also cold start if user has very few posts
		if profile.PostCount.Int32 < 3 {
			coldStart = true
		}
	}

	// Get candidate beverages
	candidates, err := r.Q.GetRecommendationCandidates(ctx, sqlc.GetRecommendationCandidatesParams{
		Category: category,
		UserID:   userID,
		Limit:    limit * 3, // Get more candidates than needed for better ranking
	})
	if err != nil {
		return nil, err
	}

	if len(candidates) == 0 {
		return []RankedBeverage{}, nil
	}

	// Rank each candidate
	scored := make([]struct {
		bev     sqlc.GetRecommendationCandidatesRow
		score   float64
		reasons []RecommendationReason
	}, len(candidates))

	for i, candidate := range candidates {
		score, reasons := r.scoreBeverage(ctx, candidate, likedTags, dislikedTags, coldStart)
		scored[i] = struct {
			bev     sqlc.GetRecommendationCandidatesRow
			score   float64
			reasons []RecommendationReason
		}{candidate, score, reasons}
	}

	// Sort by score descending
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	// Convert to output format (limit results)
	results := []RankedBeverage{}
	for i := 0; i < len(scored) && i < int(limit); i++ {
		item := scored[i]

		// Extract top 2-3 reasons
		topReasons := extractTopReasons(item.reasons, 3)

		matchScore := int(math.Min(100, math.Max(0, item.score)))

		bevID := ""
		if item.bev.ID.Valid {
			bevID = uuid.UUID(item.bev.ID.Bytes).String()
		}

		brand := ""
		if item.bev.Brand.Valid {
			brand = item.bev.Brand.String
		}

		avgRating := 0.0
		if rating, ok := item.bev.AvgRating.(float64); ok {
			avgRating = rating
		}

		results = append(results, RankedBeverage{
			BeverageID:  bevID,
			Name:        item.bev.Name,
			Brand:       brand,
			Category:    item.bev.Category,
			MatchScore:  matchScore,
			Reasons:     topReasons,
			AvgRating:   avgRating,
			ReviewCount: int(item.bev.ReviewCount),
		})
	}

	return results, nil
}

// ScoreBeverageForMatch scores a single beverage for a user (used in scan results)
func (r *Ranker) ScoreBeverageForMatch(ctx context.Context, userID pgtype.UUID, beverageID pgtype.UUID) (int, []string, error) {
	// Get beverage with tags
	beverage, err := r.Q.GetBeverageWithTags(ctx, beverageID)
	if err != nil {
		return 0, nil, err
	}

	// Get user's taste profile
	profile, err := r.Q.GetUserTasteProfile(ctx, sqlc.GetUserTasteProfileParams{
		UserID:   userID,
		Category: beverage.Category,
	})

	var likedTags TagWeights
	var dislikedTags TagWeights
	coldStart := false

	if err != nil || profile.PostCount.Int32 < 3 {
		coldStart = true
		likedTags = make(TagWeights)
		dislikedTags = make(TagWeights)
	} else {
		json.Unmarshal(profile.LikedTagsJson, &likedTags)
		json.Unmarshal(profile.DislikedTagsJson, &dislikedTags)
	}

	// Parse beverage tags
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

	// Score based on tags
	score := 50.0 // Base score for cold start
	reasons := []RecommendationReason{}

	if !coldStart && len(beverageTags) > 0 {
		tagScore := 0.0
		tagMatches := 0

		for _, tag := range beverageTags {
			likeWeight := likedTags[tag.Tag]
			dislikeWeight := dislikedTags[tag.Tag]

			contribution := likeWeight - dislikeWeight
			tagScore += contribution

			if contribution > 0.3 {
				reasons = append(reasons, RecommendationReason{
					Reason: "You like '" + tag.Tag + "'",
					Score:  contribution,
				})
				tagMatches++
			}
		}

		// Scale tag score to 0-100
		if tagMatches > 0 {
			score = 50 + (tagScore / float64(tagMatches)) * 50
		}
	}

	matchScore := int(math.Min(100, math.Max(0, score)))
	topReasons := extractTopReasons(reasons, 3)

	if coldStart || len(topReasons) == 0 {
		topReasons = []string{"Popular choice in this category"}
	}

	return matchScore, topReasons, nil
}

// scoreBeverage calculates a score for a candidate beverage
func (r *Ranker) scoreBeverage(ctx context.Context, candidate sqlc.GetRecommendationCandidatesRow, likedTags, dislikedTags TagWeights, coldStart bool) (float64, []RecommendationReason) {
	// Get beverage tags
	var beverageID pgtype.UUID
	if candidate.ID.Valid {
		beverageID = candidate.ID
	}

	beverage, err := r.Q.GetBeverageWithTags(ctx, beverageID)
	if err != nil {
		log.Printf("Failed to get tags for beverage: %v", err)
		// Fall back to global score
		avgRating := 0.0
		if rating, ok := candidate.AvgRating.(float64); ok {
			avgRating = rating
		}
		return avgRating * 10, []RecommendationReason{{Reason: "Popular choice", Score: avgRating}}
	}

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

	reasons := []RecommendationReason{}

	if coldStart {
		// Cold start: rank by global popularity
		avgRating := 0.0
		if rating, ok := candidate.AvgRating.(float64); ok {
			avgRating = rating
		}
		reviewCount := float64(candidate.ReviewCount)

		// Score = avg_rating * 10 + log(review_count + 1) * 5
		popularityBonus := math.Log(reviewCount+1) * 5
		score := avgRating*10 + popularityBonus

		reasons = append(reasons, RecommendationReason{
			Reason: "Highly rated",
			Score:  avgRating,
		})

		return score, reasons
	}

	// Personalized scoring based on tags
	baseScore := 0.0
	for _, tag := range beverageTags {
		likeWeight := likedTags[tag.Tag]
		dislikeWeight := dislikedTags[tag.Tag]

		contribution := likeWeight - dislikeWeight
		baseScore += contribution

		if contribution > 0.3 {
			reasons = append(reasons, RecommendationReason{
				Reason: "You rate '" + tag.Tag + "' higher",
				Score:  contribution,
			})
		} else if contribution < -0.3 {
			reasons = append(reasons, RecommendationReason{
				Reason: "You rate '" + tag.Tag + "' lower",
				Score:  contribution,
			})
		}
	}

	// Add global popularity bonus (smaller weight)
	avgRating := 0.0
	if rating, ok := candidate.AvgRating.(float64); ok {
		avgRating = rating
	}
	reviewCount := float64(candidate.ReviewCount)
	popularityBonus := (avgRating / 10.0) + (math.Log(reviewCount+1) / 10.0)

	finalScore := (baseScore * 50) + (popularityBonus * 10) + 50 // Scale to ~0-100

	return finalScore, reasons
}

func extractTopReasons(reasons []RecommendationReason, limit int) []string {
	// Sort by score descending
	sort.Slice(reasons, func(i, j int) bool {
		return math.Abs(reasons[i].Score) > math.Abs(reasons[j].Score)
	})

	result := []string{}
	for i := 0; i < len(reasons) && i < limit; i++ {
		result = append(result, reasons[i].Reason)
	}

	return result
}
