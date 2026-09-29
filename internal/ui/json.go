package ui

import (
	"context"
	"encoding/json"
	"io"
	"math"
	"time"

	"github.com/rudeops/rudeclaude/internal/gfx"
	"github.com/rudeops/rudeclaude/internal/rtk"
)

type jsonLimit struct {
	Label   string  `json:"label"`
	Used    float64 `json:"used"`
	Elapsed float64 `json:"elapsed"`
	Reset   string  `json:"reset"`
}

type jsonStat struct {
	Value string `json:"value"`
	Unit  string `json:"unit,omitempty"`
	Label string `json:"label"`
}

type jsonSession struct {
	Project     string  `json:"project"`
	Detail      string  `json:"detail"`
	State       string  `json:"state"`
	Doing       string  `json:"doing"`
	Context     string  `json:"context"`
	ContextFrac float64 `json:"context_frac"`
	Age         string  `json:"age"`
}

type jsonTool struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

type jsonRtkDay struct {
	Label string  `json:"label"`
	Saved float64 `json:"saved"`
}

type jsonRtk struct {
	SavedToday    string       `json:"saved_today"`
	CommandsToday int          `json:"commands_today"`
	SavedTotal    string       `json:"saved_total"`
	Savings       int          `json:"savings"`
	Days          []jsonRtkDay `json:"days"`
}

type jsonOverview struct {
	Updated     string        `json:"updated"`
	Alert       string        `json:"alert,omitempty"`
	Limits      []jsonLimit   `json:"limits"`
	Today       []jsonStat    `json:"today"`
	Activity    []float64     `json:"activity"`
	ActivityNow string        `json:"activity_now"`
	Sessions    []jsonSession `json:"sessions"`
	Tools       []jsonTool    `json:"tools"`
	Credits     string        `json:"credits,omitempty"`
	Rtk         *jsonRtk      `json:"rtk,omitempty"`
}

var stateNames = map[gfx.SessionState]string{
	gfx.Working: "working",
	gfx.Asking:  "asking",
	gfx.Done:    "done",
	gfx.Idle:    "idle",
}

// JSON writes the dashboard as JSON, for the macOS menu bar app. Unlike
// Snapshot, an API error is reported in "alert" rather than failing.
func JSON(w io.Writer, interval time.Duration, demo bool) error {
	c := newCore(interval, demo)
	if !demo {
		c.setReport(fetchReport(interval))
	}
	c.refresh()
	o := c.overview()

	out := jsonOverview{
		Updated:     o.Updated,
		Alert:       o.Alert,
		Activity:    o.Activity,
		ActivityNow: o.ActivityNow,
		Credits:     o.Credits,
		Sessions:    []jsonSession{},
		Tools:       []jsonTool{},
	}
	for _, l := range o.Limits {
		out.Limits = append(out.Limits, jsonLimit(l))
	}
	for _, s := range o.Today {
		out.Today = append(out.Today, jsonStat(s))
	}
	for _, s := range o.Sessions {
		out.Sessions = append(out.Sessions, jsonSession{
			Project: s.Project, Detail: s.Detail, State: stateNames[s.State], Doing: s.Doing,
			Context: s.Context, ContextFrac: s.ContextFrac, Age: s.Age,
		})
	}
	for _, t := range o.Tools {
		out.Tools = append(out.Tools, jsonTool(t))
	}
	out.Rtk = rtkStats(c.now, demo)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	return enc.Encode(out)
}

// rtkStats is nil when rtk is missing or fails: the block is optional.
func rtkStats(now time.Time, demo bool) *jsonRtk {
	var s *rtk.Stats
	if demo {
		s = demoRtk(now)
	} else {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		s, _ = rtk.Load(ctx, now)
	}
	if s == nil {
		return nil
	}
	today := s.Today()
	out := &jsonRtk{
		SavedToday:    formatTokens(float64(today.Saved)),
		CommandsToday: today.Commands,
		SavedTotal:    formatTokens(float64(s.Saved)),
		Savings:       int(math.Round(s.Savings)),
	}
	for _, d := range s.Days {
		out.Days = append(out.Days, jsonRtkDay{Label: weekdayInitials[d.Date.Weekday()], Saved: float64(d.Saved)})
	}
	return out
}

var weekdayInitials = [...]string{"D", "L", "M", "M", "J", "V", "S"}
