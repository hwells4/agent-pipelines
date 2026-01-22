package state

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestInitCreatesState(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	path := filepath.Join(tmp, "state.json")

	state, err := Init(path, "session-1", "pipeline", "refine.yaml")
	if err != nil {
		t.Fatalf("init: %v", err)
	}

	if state.Session != "session-1" {
		t.Fatalf("session mismatch: %q", state.Session)
	}
	if state.Type != "pipeline" {
		t.Fatalf("type mismatch: %q", state.Type)
	}
	if state.Pipeline != "refine.yaml" {
		t.Fatalf("pipeline mismatch: %q", state.Pipeline)
	}
	if state.Status != StateRunning {
		t.Fatalf("status mismatch: %q", state.Status)
	}
	if state.Iteration != 0 || state.IterationCompleted != 0 {
		t.Fatalf("iteration counters not zero: %d/%d", state.Iteration, state.IterationCompleted)
	}
	if state.IterationStarted != nil {
		t.Fatalf("iteration_started expected nil, got %v", *state.IterationStarted)
	}
	if state.StartedAt == "" {
		t.Fatal("started_at empty")
	}
	if state.CompletedAt != nil {
		t.Fatalf("completed_at expected nil, got %v", *state.CompletedAt)
	}
	if state.Error != nil || state.ErrorType != nil {
		t.Fatalf("unexpected error fields: %v/%v", state.Error, state.ErrorType)
	}
	if len(state.Stages) != 0 {
		t.Fatalf("stages should be empty, got %d", len(state.Stages))
	}
	if len(state.History) != 0 {
		t.Fatalf("history should be empty, got %d", len(state.History))
	}
	if state.EventOffset != 0 {
		t.Fatalf("event_offset should be 0, got %d", state.EventOffset)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("state.json missing: %v", err)
	}
}

func TestMarkIterationLifecycle(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	path := filepath.Join(tmp, "state.json")

	if _, err := Init(path, "session-2", "loop", ""); err != nil {
		t.Fatalf("init: %v", err)
	}

	if _, err := MarkIterationStarted(path, 2); err != nil {
		t.Fatalf("mark iteration started: %v", err)
	}

	state, err := Load(path)
	if err != nil {
		t.Fatalf("load after start: %v", err)
	}
	if state.Iteration != 2 {
		t.Fatalf("iteration mismatch: %d", state.Iteration)
	}
	if state.IterationStarted == nil {
		t.Fatal("iteration_started missing")
	}
	if _, err := time.Parse(time.RFC3339, *state.IterationStarted); err != nil {
		t.Fatalf("iteration_started not RFC3339: %v", err)
	}

	if _, err := MarkIterationCompleted(path, 2); err != nil {
		t.Fatalf("mark iteration completed: %v", err)
	}

	state, err = Load(path)
	if err != nil {
		t.Fatalf("load after completion: %v", err)
	}
	if state.IterationCompleted != 2 {
		t.Fatalf("iteration_completed mismatch: %d", state.IterationCompleted)
	}
	if state.IterationStarted != nil {
		t.Fatalf("iteration_started expected nil, got %v", *state.IterationStarted)
	}
}

func TestUpdateIterationHistory(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	path := filepath.Join(tmp, "state.json")

	if _, err := Init(path, "session-3", "loop", ""); err != nil {
		t.Fatalf("init: %v", err)
	}

	if _, err := UpdateIteration(path, 3, map[string]any{"plateau": true, "risk": "low"}, "plan"); err != nil {
		t.Fatalf("update iteration: %v", err)
	}

	state, err := Load(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if state.Iteration != 3 {
		t.Fatalf("iteration mismatch: %d", state.Iteration)
	}
	if len(state.History) != 1 {
		t.Fatalf("history length mismatch: %d", len(state.History))
	}

	entry := state.History[0]
	iterValue, ok := entry["iteration"].(float64)
	if !ok || int(iterValue) != 3 {
		t.Fatalf("history iteration mismatch: %v", entry["iteration"])
	}
	if stageValue, ok := entry["stage"].(string); !ok || stageValue != "plan" {
		t.Fatalf("history stage mismatch: %v", entry["stage"])
	}
	if tsValue, ok := entry["timestamp"].(string); !ok || tsValue == "" {
		t.Fatalf("history timestamp missing: %v", entry["timestamp"])
	} else if _, err := time.Parse(time.RFC3339, tsValue); err != nil {
		t.Fatalf("history timestamp invalid: %v", err)
	}
}

func TestTransitionValidation(t *testing.T) {
	t.Parallel()

	state := &SessionState{Status: StateRunning}
	if err := state.Transition(StateRunning); err == nil {
		t.Fatal("expected error for running -> running transition")
	}
	if err := state.Transition(StateCompleted); err != nil {
		t.Fatalf("expected running -> completed to succeed: %v", err)
	}
	if err := state.Transition(StateRunning); err == nil {
		t.Fatal("expected completed -> running to fail")
	}
}

func TestResumeFrom(t *testing.T) {
	t.Parallel()

	state := &SessionState{IterationCompleted: 4}
	if got := ResumeFrom(state); got != 5 {
		t.Fatalf("resume_from mismatch: %d", got)
	}
	if got := ResumeFrom(nil); got != 1 {
		t.Fatalf("resume_from nil mismatch: %d", got)
	}
}

func TestMarkFailed(t *testing.T) {
	t.Parallel()

	tmp := t.TempDir()
	path := filepath.Join(tmp, "state.json")

	if _, err := Init(path, "session-4", "loop", ""); err != nil {
		t.Fatalf("init: %v", err)
	}

	if _, err := MarkFailed(path, "provider_failed", "exit 1"); err != nil {
		t.Fatalf("mark failed: %v", err)
	}

	state, err := Load(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if state.Status != StateFailed {
		t.Fatalf("status mismatch: %q", state.Status)
	}
	if state.Error == nil || *state.Error != "exit 1" {
		t.Fatalf("error mismatch: %v", state.Error)
	}
	if state.ErrorType == nil || *state.ErrorType != "provider_failed" {
		t.Fatalf("error_type mismatch: %v", state.ErrorType)
	}
}
