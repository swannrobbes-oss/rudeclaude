//go:build !darwin

package usage

func readCredentials() ([]byte, error) {
	return readCredentialsFile()
}
