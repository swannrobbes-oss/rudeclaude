package usage

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"
)

// On macOS, Claude Code keeps its credentials in the login keychain. It only
// falls back to .credentials.json when the keychain is unavailable.
func readCredentials() ([]byte, error) {
	raw, kerr := readKeychain()
	if kerr == nil {
		return raw, nil
	}
	raw, ferr := readCredentialsFile()
	if ferr == nil {
		return raw, nil
	}
	return nil, kerr
}

// Same naming as Claude Code: a custom CLAUDE_CONFIG_DIR gets its own entry,
// suffixed with the start of the directory's SHA-256.
func keychainService() string {
	const base = "Claude Code-credentials"
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		sum := sha256.Sum256([]byte(dir))
		return base + "-" + hex.EncodeToString(sum[:])[:8]
	}
	return base
}

func readKeychain() ([]byte, error) {
	// Leaves time to answer the keychain access prompt on first use.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	service := keychainService()
	out, err := exec.CommandContext(ctx, "/usr/bin/security",
		"find-generic-password", "-s", service, "-w").Output()
	if err != nil {
		if ee := (*exec.ExitError)(nil); errors.As(err, &ee) && ee.ExitCode() == 44 {
			return nil, fmt.Errorf("aucun identifiant %q dans le trousseau : connecte-toi avec claude", service)
		}
		return nil, fmt.Errorf("lecture du trousseau macOS : %w", err)
	}
	return bytes.TrimSpace(out), nil
}
