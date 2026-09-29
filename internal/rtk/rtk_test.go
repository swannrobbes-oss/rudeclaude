package rtk

import (
	"testing"
	"time"
)

func TestParse(t *testing.T) {
	raw := []byte(`{
		"summary": {"total_commands": 909, "total_saved": 5973566, "avg_savings_pct": 93.4},
		"daily": [
			{"date": "2026-09-01", "commands": 50, "saved_tokens": 9000},
			{"date": "2026-09-24", "commands": 3, "saved_tokens": 100},
			{"date": "2026-09-28", "commands": 32, "saved_tokens": 2150},
			{"date": "2026-09-29", "commands": 15, "saved_tokens": 402}
		]
	}`)
	now := time.Date(2026, 9, 29, 9, 30, 0, 0, time.Local)
	s, err := parse(raw, now)
	if err != nil {
		t.Fatal(err)
	}
	if s.Commands != 909 || s.Saved != 5973566 || s.Savings != 93.4 {
		t.Errorf("résumé : %+v", s)
	}
	if first := s.Days[0].Date.Format(time.DateOnly); first != "2026-09-23" {
		t.Errorf("premier jour : %s, attendu 2026-09-23", first)
	}
	want := [Days]int{0, 100, 0, 0, 0, 2150, 402}
	for i, d := range s.Days {
		if d.Saved != want[i] {
			t.Errorf("jour %d (%s) : %d, attendu %d", i, d.Date.Format(time.DateOnly), d.Saved, want[i])
		}
	}
	if s.Today().Commands != 15 {
		t.Errorf("commandes du jour : %d, attendu 15", s.Today().Commands)
	}
}

func TestParseRejectsOtherTool(t *testing.T) {
	if _, err := parse([]byte(`{}`), time.Now()); err == nil {
		t.Error("une sortie sans résumé devrait être refusée")
	}
}
