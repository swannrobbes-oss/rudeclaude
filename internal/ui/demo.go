package ui

import (
	"math"
	"time"

	"github.com/rudeops/rudeclaude/internal/activity"
	"github.com/rudeops/rudeclaude/internal/rtk"
	"github.com/rudeops/rudeclaude/internal/usage"
)

func demoReport(now time.Time) *usage.Report {
	pct := math.Min(100, float64(now.Unix()%60)*110/60)
	fiveReset := now.Add(3 * time.Hour)
	weekReset := now.Add(4 * 24 * time.Hour)
	return &usage.Report{
		FiveHour: &usage.Window{Utilization: pct, ResetsAt: &fiveReset},
		SevenDay: &usage.Window{Utilization: pct * 0.6, ResetsAt: &weekReset},
		Spend: &usage.Spend{
			Enabled: true,
			Used:    &usage.Money{AmountMinor: 350, Currency: "EUR", Exponent: 2},
			Limit:   &usage.Money{AmountMinor: 2000, Currency: "EUR", Exponent: 2},
		},
		SevenDayBreakdown: &usage.Breakdown{Rows: []usage.BreakdownRow{
			{Key: "claude_code", DisplayName: "Claude Code", Percent: 58},
			{Key: "chat", DisplayName: "Chats", Percent: 31},
			{Key: "cowork", DisplayName: "Cowork", Percent: 11},
			{Key: "other", DisplayName: "Other", Percent: 0},
		}},
	}
}

func demoSnapshot(now time.Time) activity.Snapshot {
	var snap activity.Snapshot
	t := float64(now.Unix())
	for i := range snap.Minutes {
		x := (t/60 + float64(i)) / 4
		snap.Minutes[i] = math.Max(0, 12000+9000*math.Sin(x)+5000*math.Sin(x*2.7))
	}
	snap.Rate = snap.Minutes[len(snap.Minutes)-1]
	snap.Today = activity.Totals{Replies: 214, Output: 186_000, Input: 4_000, CacheCreate: 60_000, CacheRead: 1_100_000}
	snap.Tools = []activity.ToolCount{{Name: "Bash", Count: 42}, {Name: "Read", Count: 12}, {Name: "Edit", Count: 7}, {Name: "Write", Count: 3}}
	tools := []string{"Bash", "Read", "Edit", ""}
	snap.Sessions = []activity.Session{
		{Project: "rudeclaude", Branch: "main", Model: "claude-opus-5-5", State: activity.Working,
			Tool: tools[(now.Unix()/4)%4], Since: now, Context: 147_000},
		{Project: "api-paiement", Branch: "feat/stripe", Model: "claude-opus-5-5", State: activity.Waiting,
			Tool: "AskUserQuestion", Since: now.Add(-1 * time.Minute), Context: 62_000},
		{Project: "site-vitrine", Branch: "main", Model: "claude-opus-5-5", State: activity.Waiting,
			Since: now.Add(-6 * time.Minute), Context: 41_000},
		{Project: "infra", Branch: "main", Model: "claude-sonnet-5", State: activity.Idle,
			Since: now.Add(-22 * time.Minute), Context: 18_000},
	}
	return snap
}

func demoRtk(now time.Time) *rtk.Stats {
	s := &rtk.Stats{Commands: 1284, Saved: 4_870_000, Savings: 91.6}
	saved := [rtk.Days]int{61_000, 118_000, 0, 42_000, 156_000, 97_000, 38_000}
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	for i := range s.Days {
		s.Days[i] = rtk.Day{Date: today.AddDate(0, 0, i-rtk.Days+1), Commands: saved[i] / 900, Saved: saved[i]}
	}
	return s
}
