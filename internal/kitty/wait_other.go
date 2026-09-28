//go:build !darwin

package kitty

import (
	"time"

	"golang.org/x/sys/unix"
)

func waitReadable(fd int, d time.Duration) bool {
	fds := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN}}
	n, err := unix.Poll(fds, int(d.Milliseconds())+1)
	return err == nil && n > 0
}
