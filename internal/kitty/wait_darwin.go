package kitty

import (
	"time"

	"golang.org/x/sys/unix"
)

// poll(2) does not support terminal devices on macOS, select(2) does.
func waitReadable(fd int, d time.Duration) bool {
	var set unix.FdSet
	set.Set(fd)
	tv := unix.NsecToTimeval(d.Nanoseconds())
	n, err := unix.Select(fd+1, &set, nil, nil, &tv)
	return err == nil && n > 0
}
