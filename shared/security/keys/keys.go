package keys

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
)

type KeySet struct {
	Private ed25519.PrivateKey
	Public  ed25519.PublicKey
	KID     string
	Issuer  string
	Audience string
}

func LoadFromEnv(privB64, pubB64, kid, issuer, aud string) (*KeySet, error) {
	privBytes, err := base64.StdEncoding.DecodeString(privB64)
	if err != nil {
		return nil, err
	}
	pubBytes, err := base64.StdEncoding.DecodeString(pubB64)
	if err != nil {
		return nil, err
	}
	if len(privBytes) != ed25519.PrivateKeySize || len(pubBytes) != ed25519.PublicKeySize {
		return nil, errors.New("invalid ed25519 key size")
	}

	return &KeySet{
		Private: ed25519.PrivateKey(privBytes),
		Public:  ed25519.PublicKey(pubBytes),
		KID:     kid,
		Issuer:  issuer,
		Audience: aud,
	}, nil
}

func LoadPublicKeyFromEnv(pubB64, kid, issuer, aud string) (*KeySet, error) {
	pubBytes, err := base64.StdEncoding.DecodeString(pubB64)
	if err != nil {
		return nil, err
	}
	if len(pubBytes) != ed25519.PublicKeySize {
		return nil, errors.New("invalid ed25519 public key size")
	}

	return &KeySet{
		Private: nil,
		Public:  ed25519.PublicKey(pubBytes),
		KID:     kid,
		Issuer:  issuer,
		Audience: aud,
	}, nil
}

// Resolve returns the public key for the given key ID
func (ks *KeySet) Resolve(kid string) (any, error) {
	if kid != ks.KID {
		return nil, errors.New("unknown key ID")
	}
	return ks.Public, nil
}
