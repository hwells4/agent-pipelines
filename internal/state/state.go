// Package state provides atomic state.json lifecycle management.
package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// State represents the session lifecycle state.
type State string

const (
	StatePending   State = "pending"
	StateRunning   State = "running"
	StatePaused    State = "paused"
	StateCompleted State = "completed"
	StateFailed    State = "failed"
	StateAborted   State = "aborted"
)

var (
	// ErrMissingPath indicates the state file path is empty.
	ErrMissingPath = errors.New("state file path is empty")
	// ErrInvalidTransition indicates an invalid state transition.
	ErrInvalidTransition = errors.New("invalid state transition")
	// ErrStateMissing indicates the state file does not exist.
	ErrStateMissing = errors.New("state file does not exist")
)

// ValidTransitions defines allowed state changes.
var ValidTransitions = map[State][]State{
	StatePending:   {StateRunning},
	StateRunning:   {StateCompleted, StateFailed, StatePaused},
	StatePaused:    {StateRunning, StateAborted},
	StateCompleted: {},
	StateFailed:    {StateRunning},
	StateAborted:   {},
}

// StageState captures multi-stage progress details.
type StageState struct {
	Name        string  `json:"name"`
	Index       int     `json:"index"`
	Iterations  int     `json:"iterations"`
	CompletedAt *string `json:"completed_at"`
}

// SessionState matches the state.json schema from the PRD.
type SessionState struct {
	Session            string           `json:"session"`
	Type               string           `json:"type"`
	Pipeline           string           `json:"pipeline"`
	Status             State            `json:"status"`
	Iteration          int              `json:"iteration"`
	IterationCompleted int              `json:"iteration_completed"`
	IterationStarted   *string          `json:"iteration_started"`
	StartedAt          string           `json:"started_at"`
	CompletedAt        *string          `json:"completed_at"`
	CurrentStage       string           `json:"current_stage"`
	Stages             []StageState     `json:"stages"`
	History            []map[string]any `json:"history"`
	EventOffset        int              `json:"event_offset"`
	Error              *string          `json:"error"`
	ErrorType          *string          `json:"error_type"`
}

// Transition attempts a state change, returning error if invalid.
func (s *SessionState) Transition(to State) error {
	if s == nil {
		return errors.New("state is nil")
	}
	valid, ok := ValidTransitions[s.Status]
	if !ok {
		return fmt.Errorf("%w: unknown status %q", ErrInvalidTransition, s.Status)
	}
	for _, allowed := range valid {
		if allowed == to {
			s.Status = to
			return nil
		}
	}
	return fmt.Errorf("%w: %s → %s", ErrInvalidTransition, s.Status, to)
}

// Init creates state.json if it does not exist and returns the current state.
func Init(path, session, kind, pipeline string) (*SessionState, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, ErrMissingPath
	}

	if fileExists(path) {
		return Load(path)
	}

	state := newSessionState(session, kind, pipeline, time.Now().UTC())
	if err := Write(path, state); err != nil {
		return nil, err
	}
	return state, nil
}

// Load reads state.json from disk.
func Load(path string) (*SessionState, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, ErrMissingPath
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, fmt.Errorf("%w: %s", ErrStateMissing, path)
		}
		return nil, fmt.Errorf("read state: %w", err)
	}

	var state SessionState
	if err := json.Unmarshal(data, &state); err != nil {
		return nil, fmt.Errorf("parse state: %w", err)
	}
	if state.Stages == nil {
		state.Stages = []StageState{}
	}
	if state.History == nil {
		state.History = []map[string]any{}
	}
	return &state, nil
}

// Write persists state.json atomically.
func Write(path string, state *SessionState) error {
	path = strings.TrimSpace(path)
	if path == "" {
		return ErrMissingPath
	}
	if state == nil {
		return errors.New("state is nil")
	}
	payload, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal state: %w", err)
	}
	payload = append(payload, '\n')
	return writeFileAtomic(path, payload, 0o644)
}

// Update loads state.json, mutates it, and writes it atomically.
func Update(path string, update func(*SessionState) error) (*SessionState, error) {
	state, err := Load(path)
	if err != nil {
		return nil, err
	}
	if err := update(state); err != nil {
		return nil, err
	}
	if err := Write(path, state); err != nil {
		return nil, err
	}
	return state, nil
}

// UpdateIteration records iteration output data in history.
func UpdateIteration(path string, iteration int, outputVars map[string]any, stageName string) (*SessionState, error) {
	return Update(path, func(state *SessionState) error {
		state.UpdateIteration(iteration, outputVars, stageName, time.Now().UTC())
		return nil
	})
}

// MarkIterationStarted updates iteration tracking at the start of an iteration.
func MarkIterationStarted(path string, iteration int) (*SessionState, error) {
	return Update(path, func(state *SessionState) error {
		return state.MarkIterationStarted(iteration, time.Now().UTC())
	})
}

// MarkIterationCompleted updates iteration tracking at the end of an iteration.
func MarkIterationCompleted(path string, iteration int) (*SessionState, error) {
	return Update(path, func(state *SessionState) error {
		state.MarkIterationCompleted(iteration)
		return nil
	})
}

// MarkCompleted transitions the session to completed and stamps completion time.
func MarkCompleted(path string) (*SessionState, error) {
	return Update(path, func(state *SessionState) error {
		return state.MarkCompleted(time.Now().UTC())
	})
}

// MarkFailed transitions the session to failed with error details.
func MarkFailed(path, errType, errMessage string) (*SessionState, error) {
	return Update(path, func(state *SessionState) error {
		return state.MarkFailed(errType, errMessage)
	})
}

// ResumeFrom returns the iteration number to resume from.
func ResumeFrom(state *SessionState) int {
	if state == nil {
		return 1
	}
	if state.IterationCompleted < 0 {
		return 1
	}
	return state.IterationCompleted + 1
}

// UpdateIteration appends a history entry for an iteration.
func (s *SessionState) UpdateIteration(iteration int, outputVars map[string]any, stageName string, at time.Time) {
	if s == nil {
		return
	}

	s.Iteration = iteration
	entry := map[string]any{
		"iteration": iteration,
		"timestamp": at.UTC().Format(time.RFC3339),
	}
	if stageName != "" {
		entry["stage"] = stageName
	}
	for key, value := range outputVars {
		entry[key] = value
	}
	s.History = append(s.History, entry)
}

// MarkIterationStarted marks the iteration as running.
func (s *SessionState) MarkIterationStarted(iteration int, startedAt time.Time) error {
	if s == nil {
		return errors.New("state is nil")
	}
	if s.Status != StateRunning {
		if err := s.Transition(StateRunning); err != nil {
			return err
		}
	}
	s.Iteration = iteration
	ts := startedAt.UTC().Format(time.RFC3339)
	s.IterationStarted = &ts
	return nil
}

// MarkIterationCompleted marks the iteration as completed.
func (s *SessionState) MarkIterationCompleted(iteration int) {
	if s == nil {
		return
	}
	s.Iteration = iteration
	s.IterationCompleted = iteration
	s.IterationStarted = nil
}

// MarkCompleted marks the session as completed.
func (s *SessionState) MarkCompleted(completedAt time.Time) error {
	if s == nil {
		return errors.New("state is nil")
	}
	if err := s.Transition(StateCompleted); err != nil {
		return err
	}
	ts := completedAt.UTC().Format(time.RFC3339)
	s.CompletedAt = &ts
	s.IterationStarted = nil
	return nil
}

// MarkFailed marks the session as failed with error details.
func (s *SessionState) MarkFailed(errType, errMessage string) error {
	if s == nil {
		return errors.New("state is nil")
	}
	if err := s.Transition(StateFailed); err != nil {
		return err
	}
	msg := strings.TrimSpace(errMessage)
	etype := strings.TrimSpace(errType)
	if msg != "" {
		s.Error = &msg
	}
	if etype != "" {
		s.ErrorType = &etype
	}
	return nil
}

func newSessionState(session, kind, pipeline string, startedAt time.Time) *SessionState {
	started := startedAt.UTC().Format(time.RFC3339)
	return &SessionState{
		Session:            session,
		Type:               kind,
		Pipeline:           pipeline,
		Status:             StateRunning,
		Iteration:          0,
		IterationCompleted: 0,
		IterationStarted:   nil,
		StartedAt:          started,
		CompletedAt:        nil,
		CurrentStage:       "",
		Stages:             []StageState{},
		History:            []map[string]any{},
		EventOffset:        0,
		Error:              nil,
		ErrorType:          nil,
	}
}

func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create state dir: %w", err)
	}

	tmpFile, err := os.CreateTemp(dir, ".state.json.tmp-*")
	if err != nil {
		return fmt.Errorf("create temp state: %w", err)
	}
	defer func() {
		_ = os.Remove(tmpFile.Name())
	}()

	if err := tmpFile.Chmod(perm); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("chmod temp state: %w", err)
	}
	if _, err := tmpFile.Write(data); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("write temp state: %w", err)
	}
	if err := tmpFile.Sync(); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("sync temp state: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("close temp state: %w", err)
	}

	if err := os.Rename(tmpFile.Name(), path); err != nil {
		return fmt.Errorf("rename temp state: %w", err)
	}
	return nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
