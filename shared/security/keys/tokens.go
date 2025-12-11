package keys

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Claims struct {
	jwt.RegisteredClaims
	Handle string   `json:"handle"`
	Email  string   `json:"email"`
	Scopes []string `json:"scopes"`
}

func IssueAccessToken(ks *KeySet, userID uuid.UUID, handle, email string, scopes []string) (string, time.Time, error) {
	exp := time.Now().Add(15 * time.Minute)

	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    ks.Issuer,
			Subject:   userID.String(),
			Audience:  []string{ks.Audience},
			ExpiresAt: jwt.NewNumericDate(exp),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
		Handle: handle,
		Email:  email,
		Scopes: scopes,
	}

	tok := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	tok.Header["kid"] = ks.KID

	signed, err := tok.SignedString(ks.Private)
	return signed, exp, err
}

func NewRefreshToken() (raw string, hash string, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", "", err
	}
	raw = base64.RawURLEncoding.EncodeToString(b)

	h := sha256.Sum256([]byte(raw))
	hash = base64.RawURLEncoding.EncodeToString(h[:])
	return raw, hash, nil
}


