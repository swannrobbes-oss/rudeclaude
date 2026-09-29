// Package rtk reads the token savings recorded by rtk (Rust Token Killer),
// the CLI proxy that compacts command output before Claude Code reads it.
package rtk

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// Days is the length of the daily history kept in Stats.
const Days = 7

type Day struct {
	Date     time.Time
	Commands int
	Saved    int
}

type Stats struct {
	Commands int     // all time
	Saved    int     // tokens, all time
	Savings  float64 // average share of output saved, in %
	Days     [Days]Day
}

// Today is the last entry of Days.
func (s *Stats) Today() Day { return s.Days[Days-1] }

// Load runs `rtk gain` and returns nil, without error, when rtk is not
// installed.
func Load(ctx context.Context, now time.Time) (*Stats, error) {
	bin := binary()
	if bin == "" {
		return nil, nil
	}
	out, err := exec.CommandContext(ctx, bin, "gain", "--daily", "--format", "json").Output()
	if err != nil {
		return nil, err
	}
	return parse(out, now)
}

// An app started from the Finder does not get the shell's PATH, hence the
// usual install paths as a fallback.
func binary() string {
	if p, err := exec.LookPath("rtk"); err == nil {
		return p
	}
	home, _ := os.UserHomeDir()
	for _, p := range []string{
		"/opt/homebrew/bin/rtk",
		"/usr/local/bin/rtk",
		filepath.Join(home, ".cargo/bin/rtk"),
		filepath.Join(home, ".local/bin/rtk"),
	} {
		if info, err := os.Stat(p); err == nil && info.Mode()&0o111 != 0 {
			return p
		}
	}
	return ""
}

type gain struct {
	Summary *struct {
		TotalCommands int     `json:"total_commands"`
		TotalSaved    int     `json:"total_saved"`
		AvgSavingsPct float64 `json:"avg_savings_pct"`
	} `json:"summary"`
	Daily []struct {
		Date        string `json:"date"`
		Commands    int    `json:"commands"`
		SavedTokens int    `json:"saved_tokens"`
	} `json:"daily"`
}

// parse keeps the last Days days up to now, oldest first, with zeros for
// the days without commands.
func parse(raw []byte, now time.Time) (*Stats, error) {
	var g gain
	if err := json.Unmarshal(raw, &g); err != nil {
		return nil, err
	}
	// Another tool also installs itself as rtk (Rust Type Kit).
	if g.Summary == nil {
		return nil, errors.New("rtk : sortie inattendue")
	}
	s := &Stats{
		Commands: g.Summary.TotalCommands,
		Saved:    g.Summary.TotalSaved,
		Savings:  g.Summary.AvgSavingsPct,
	}
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	index := map[string]int{}
	for i := range Days {
		d := today.AddDate(0, 0, i-Days+1)
		s.Days[i].Date = d
		index[d.Format(time.DateOnly)] = i
	}
	for _, d := range g.Daily {
		if i, ok := index[d.Date]; ok {
			s.Days[i].Commands = d.Commands
			s.Days[i].Saved = d.SavedTokens
		}
	}
	return s, nil
}
