package security

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/burkebarcode/backend/shared/security/keys"
)

type KeyResolver func(kid string) (any, error)

func JWTAuth(resolve KeyResolver, issuer, audience string) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
			return
		}
		raw := strings.TrimPrefix(h, "Bearer ")

		parsed, err := jwt.ParseWithClaims(raw, &keys.Claims{}, func(t *jwt.Token) (any, error) {
			kid, _ := t.Header["kid"].(string)
			return resolve(kid)
		},
			jwt.WithIssuer(issuer),
			jwt.WithAudience(audience),
			jwt.WithValidMethods([]string{jwt.SigningMethodEdDSA.Alg()}),
		)

		if err != nil || !parsed.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}

		claims := parsed.Claims.(*keys.Claims)
		c.Set("claims", claims)
		c.Set("user_id", claims.Subject)
		c.Set("handle", claims.Handle)
		c.Next()
	}
}
