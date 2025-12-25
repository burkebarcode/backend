package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

const (
	defaultBaseURL = "https://api.openai.com/v1"
	defaultModel   = "gpt-4o-mini"
	defaultTimeout = 60 * time.Second
	maxRetries     = 2
)

type Client struct {
	apiKey     string
	model      string
	baseURL    string
	httpClient *http.Client
}

type Config struct {
	APIKey  string
	Model   string
	BaseURL string
	Timeout time.Duration
}

func NewClient(cfg Config) *Client {
	if cfg.Model == "" {
		cfg.Model = defaultModel
	}
	if cfg.BaseURL == "" {
		cfg.BaseURL = defaultBaseURL
	}
	if cfg.Timeout == 0 {
		cfg.Timeout = defaultTimeout
	}

	return &Client{
		apiKey:  cfg.APIKey,
		model:   cfg.Model,
		baseURL: cfg.BaseURL,
		httpClient: &http.Client{
			Timeout: cfg.Timeout,
		},
	}
}

// BeverageSummaryInput contains reviews for summarization
type BeverageSummaryInput struct {
	BeverageName string
	Category     string
	Reviews      []ReviewForSummary
}

type ReviewForSummary struct {
	Rating float64
	Notes  string
}

// BeverageSummaryResponse is the structured output from OpenAI
type BeverageSummaryResponse struct {
	SummaryText   string   `json:"summary_text"`
	Descriptors   []string `json:"descriptors"`
	Pros          []string `json:"pros"`
	Cons          []string `json:"cons"`
	CoverageScore float64  `json:"coverage_score"`
}

// PostTaggingInput contains a single post for tag extraction
type PostTaggingInput struct {
	DrinkName string
	Category  string
	Notes     string
	Rating    float64
	// Optional structured details
	Winery   string
	Vintage  string
	Brewery  string
	Region   string
}

// PostTaggingResponse is the structured output for post tagging
type PostTaggingResponse struct {
	Tags       []Tag                  `json:"tags"`
	Structured PostTaggingStructured  `json:"structured"`
}

type Tag struct {
	Tag        string  `json:"tag"`
	TagType    string  `json:"tag_type"`
	Confidence float64 `json:"confidence"`
}

type PostTaggingStructured struct {
	Wine     *WineStructured     `json:"wine,omitempty"`
	Beer     *BeerStructured     `json:"beer,omitempty"`
	Cocktail *CocktailStructured `json:"cocktail,omitempty"`
}

type WineStructured struct {
	Sweetness *string `json:"sweetness,omitempty"`
	Body      *string `json:"body,omitempty"`
	Tannin    *string `json:"tannin,omitempty"`
	Acidity   *string `json:"acidity,omitempty"`
	Varietal  *string `json:"varietal,omitempty"`
	Region    *string `json:"region,omitempty"`
}

type BeerStructured struct {
	Style *string `json:"style,omitempty"`
}

type CocktailStructured struct {
	BaseSpirit *string `json:"base_spirit,omitempty"`
	Family     *string `json:"family,omitempty"`
}

// GenerateBeverageSummary creates an AI summary from reviews
func (c *Client) GenerateBeverageSummary(ctx context.Context, input BeverageSummaryInput) (*BeverageSummaryResponse, error) {
	if len(input.Reviews) == 0 {
		return nil, fmt.Errorf("no reviews provided")
	}

	// Cap reviews to 50 for token limits
	reviews := input.Reviews
	if len(reviews) > 50 {
		reviews = reviews[:50]
	}

	// Build prompt
	reviewsText := ""
	for i, r := range reviews {
		notes := truncateText(r.Notes, 500)
		reviewsText += fmt.Sprintf("%d. Rating: %.1f/10, Notes: %s\n", i+1, r.Rating, notes)
	}

	systemPrompt := `You are a sommelier and beverage expert. Generate a concise summary of what people say about this beverage based ONLY on the provided reviews. Be honest and grounded - only mention flavors, characteristics, and opinions explicitly stated in the reviews. Do not hallucinate tasting notes.

Output format (JSON):
{
  "summary_text": "2-4 sentence summary",
  "descriptors": ["keyword1", "keyword2", ...],  // 5-10 descriptive keywords found in reviews
  "pros": ["positive point 1", "positive point 2"],  // 2-4 positive aspects
  "cons": ["negative point 1", "negative point 2"],  // 2-4 negative aspects (if any)
  "coverage_score": 0.0-1.0  // confidence based on review count and diversity
}`

	userPrompt := fmt.Sprintf("Beverage: %s (%s category)\n\nReviews (%d total):\n%s",
		input.BeverageName, input.Category, len(input.Reviews), reviewsText)

	response, err := c.chatCompletion(ctx, systemPrompt, userPrompt, "beverage_summary_response")
	if err != nil {
		return nil, err
	}

	var summary BeverageSummaryResponse
	if err := json.Unmarshal([]byte(response), &summary); err != nil {
		return nil, fmt.Errorf("failed to parse summary response: %w", err)
	}

	// Validate
	if summary.SummaryText == "" {
		return nil, fmt.Errorf("empty summary text")
	}

	return &summary, nil
}

// ExtractPostTags extracts tags from a single post
func (c *Client) ExtractPostTags(ctx context.Context, input PostTaggingInput) (*PostTaggingResponse, error) {
	if input.Notes == "" {
		// No notes, return empty tags
		return &PostTaggingResponse{
			Tags:       []Tag{},
			Structured: PostTaggingStructured{},
		}, nil
	}

	notes := truncateText(input.Notes, 1000)

	systemPrompt := `You are a beverage tasting note analyzer. Extract structured tags from the tasting note. Output JSON only.

Tag types:
- descriptor: flavor/aroma descriptors (e.g., "fruity", "oaky", "hoppy")
- style: beverage style if mentioned (e.g., "IPA", "Cabernet", "Old Fashioned")
- region: geographic region if mentioned (e.g., "Napa", "Bordeaux")
- varietal: grape varietal if mentioned (e.g., "Chardonnay", "Pinot Noir")
- structure: structural terms (e.g., "full-bodied", "dry", "sweet", "bitter")

Output format (JSON):
{
  "tags": [
    {"tag": "oaky", "tag_type": "descriptor", "confidence": 0.9},
    ...
  ],
  "structured": {
    "wine": {
      "sweetness": "dry|off-dry|semi-sweet|sweet|null",
      "body": "light|medium|full|null",
      "tannin": "low|medium|high|null",
      "acidity": "low|medium|high|null",
      "varietal": "string|null",
      "region": "string|null"
    },
    "beer": {
      "style": "string|null"
    },
    "cocktail": {
      "base_spirit": "string|null",
      "family": "string|null"
    }
  }
}`

	userPrompt := fmt.Sprintf("Beverage: %s (%s)\nRating: %.1f/10\nNotes: %s",
		input.DrinkName, input.Category, input.Rating, notes)

	if input.Winery != "" {
		userPrompt += fmt.Sprintf("\nWinery: %s", input.Winery)
	}
	if input.Vintage != "" {
		userPrompt += fmt.Sprintf("\nVintage: %s", input.Vintage)
	}
	if input.Brewery != "" {
		userPrompt += fmt.Sprintf("\nBrewery: %s", input.Brewery)
	}
	if input.Region != "" {
		userPrompt += fmt.Sprintf("\nRegion: %s", input.Region)
	}

	response, err := c.chatCompletion(ctx, systemPrompt, userPrompt, "post_tagging_response")
	if err != nil {
		return nil, err
	}

	var tagging PostTaggingResponse
	if err := json.Unmarshal([]byte(response), &tagging); err != nil {
		return nil, fmt.Errorf("failed to parse tagging response: %w", err)
	}

	return &tagging, nil
}

func (c *Client) chatCompletion(ctx context.Context, systemPrompt, userPrompt, responseFormat string) (string, error) {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(attempt) * time.Second
			log.Printf("OpenAI retry %d/%d after %v", attempt, maxRetries, backoff)
			time.Sleep(backoff)
		}

		result, err := c.doRequest(ctx, systemPrompt, userPrompt, responseFormat)
		if err == nil {
			return result, nil
		}

		lastErr = err
		log.Printf("OpenAI request failed (attempt %d/%d): %v", attempt+1, maxRetries+1, err)
	}

	return "", fmt.Errorf("all retry attempts failed: %w", lastErr)
}

func (c *Client) doRequest(ctx context.Context, systemPrompt, userPrompt, responseFormat string) (string, error) {
	requestBody := map[string]interface{}{
		"model": c.model,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
		"response_format": map[string]string{
			"type": "json_object",
		},
		"temperature": 0.3,
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/chat/completions", bytes.NewReader(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}

	var completion struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(body, &completion); err != nil {
		return "", fmt.Errorf("failed to parse completion: %w", err)
	}

	if len(completion.Choices) == 0 {
		return "", fmt.Errorf("no completion choices returned")
	}

	return completion.Choices[0].Message.Content, nil
}

func truncateText(text string, maxLen int) string {
	if len(text) <= maxLen {
		return text
	}
	return text[:maxLen] + "..."
}
