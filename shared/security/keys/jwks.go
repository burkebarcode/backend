package keys

import (
	"encoding/base64"
	"net/http"

	"github.com/gin-gonic/gin"
)

type jwksKey struct {
	Kty string `json:"kty"` // OKP for Ed25519
	Crv string `json:"crv"`
	Kid string `json:"kid"`
	X   string `json:"x"`   // public key bytes base64url
	Alg string `json:"alg"`
	Use string `json:"use"`
}

func (ks *KeySet) JWKSHandler(c *gin.Context) {
	x := base64.RawURLEncoding.EncodeToString(ks.Public)
	c.JSON(http.StatusOK, gin.H{
		"keys": []jwksKey{
			{
				Kty: "OKP",
				Crv: "Ed25519",
				Kid: ks.KID,
				X:   x,
				Alg: "EdDSA",
				Use: "sig",
			},
		},
	})
}


