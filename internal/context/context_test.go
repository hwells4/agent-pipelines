package context

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestGenerateContextStructure(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	stageConfig := StageConfig{
		ID:            "work",
		Name:          "work",
		Index:         intPtr(0),
		Loop:          "work",
		MaxIterations: intPtr(25),
	}

	contextPath, err := GenerateContext("test-session", 1, stageConfig, tempDir)
	if err != nil {
		t.Fatalf("GenerateContext: %v", err)
	}
	if _, err := os.Stat(contextPath); err != nil {
		t.Fatalf("context.json not created: %v", err)
	}

	var manifest ContextManifest
	if err := readJSON(contextPath, &manifest); err != nil {
		t.Fatalf("read context.json: %v", err)
	}

	if manifest.Session != "test-session" {
		t.Fatalf("session mismatch: got %q", manifest.Session)
	}
	if manifest.Iteration != 1 {
		t.Fatalf("iteration mismatch: got %d", manifest.Iteration)
	}
	if manifest.Stage.ID != "work" {
		t.Fatalf("stage id mismatch: got %q", manifest.Stage.ID)
	}
	if manifest.Stage.Index != 0 {
		t.Fatalf("stage index mismatch: got %d", manifest.Stage.Index)
	}
	if manifest.Limits.MaxIterations != 25 {
		t.Fatalf("max_iterations mismatch: got %d", manifest.Limits.MaxIterations)
	}
}

func TestContextPathsAndInputs(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	stageConfig := StageConfig{
		ID:            "work",
		Name:          "work",
		Index:         intPtr(0),
		Loop:          "work",
		MaxIterations: intPtr(25),
	}

	contextPath, err := GenerateContext("test-session", 1, stageConfig, tempDir)
	if err != nil {
		t.Fatalf("GenerateContext: %v", err)
	}

	var manifest ContextManifest
	if err := readJSON(contextPath, &manifest); err != nil {
		t.Fatalf("read context.json: %v", err)
	}

	expectedStageDir := filepath.Join(tempDir, "stage-00-work")
	if manifest.Paths.SessionDir != tempDir {
		t.Fatalf("session_dir mismatch: got %q", manifest.Paths.SessionDir)
	}
	if manifest.Paths.StageDir != expectedStageDir {
		t.Fatalf("stage_dir mismatch: got %q", manifest.Paths.StageDir)
	}
	if !stringsContain(manifest.Paths.Progress, "progress.md") {
		t.Fatalf("progress path missing progress.md: %q", manifest.Paths.Progress)
	}
	if !stringsContain(manifest.Paths.Status, filepath.Join("iterations", "001", "status.json")) {
		t.Fatalf("status path missing iteration: %q", manifest.Paths.Status)
	}

	if len(manifest.Inputs.FromStage) != 0 {
		t.Fatalf("from_stage expected empty, got %v", manifest.Inputs.FromStage)
	}
	if len(manifest.Inputs.FromPreviousIterations) != 0 {
		t.Fatalf("from_previous_iterations expected empty, got %v", manifest.Inputs.FromPreviousIterations)
	}
	if len(manifest.Inputs.FromInitial) != 0 {
		t.Fatalf("from_initial expected empty, got %v", manifest.Inputs.FromInitial)
	}
}

func TestRemainingSecondsCalculation(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	stageConfig := StageConfig{
		ID:                "work",
		Name:              "work",
		Index:             intPtr(0),
		MaxRuntimeSeconds: intPtr(60),
	}

	startedAt := time.Now().UTC().Add(-120 * time.Second).Format(time.RFC3339)
	state := []byte(`{"started_at":"` + startedAt + `"}`)
	if err := os.WriteFile(filepath.Join(tempDir, "state.json"), state, 0o644); err != nil {
		t.Fatalf("write state.json: %v", err)
	}

	remaining, err := CalculateRemainingSeconds(tempDir, stageConfig)
	if err != nil {
		t.Fatalf("CalculateRemainingSeconds: %v", err)
	}
	if remaining != 0 {
		t.Fatalf("remaining expected 0, got %d", remaining)
	}
}

func TestRemainingSecondsDefaults(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	stageConfig := StageConfig{
		ID:                "work",
		Name:              "work",
		Index:             intPtr(0),
		MaxRuntimeSeconds: intPtr(3600),
	}

	remaining, err := CalculateRemainingSeconds(tempDir, stageConfig)
	if err != nil {
		t.Fatalf("CalculateRemainingSeconds: %v", err)
	}
	if remaining != 3600 {
		t.Fatalf("remaining expected 3600, got %d", remaining)
	}
}

func TestGuardrailsRuntimeLimit(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	stageConfig := StageConfig{
		ID:    "work",
		Name:  "work",
		Index: intPtr(0),
		Guardrails: &GuardrailsConfig{
			MaxRuntimeSeconds: intPtr(7200),
		},
	}

	remaining, err := CalculateRemainingSeconds(tempDir, stageConfig)
	if err != nil {
		t.Fatalf("CalculateRemainingSeconds: %v", err)
	}
	if remaining != 7200 {
		t.Fatalf("remaining expected 7200, got %d", remaining)
	}
}

func TestPlanInputsPreserved(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	planFile := filepath.Join(tempDir, "seed-plan.md")
	if err := os.WriteFile(planFile, []byte("# seed"), 0o644); err != nil {
		t.Fatalf("write plan file: %v", err)
	}

	planJSON := map[string]any{
		"version": 1,
		"session": map[string]any{
			"name":   "contract-session",
			"inputs": []string{planFile},
		},
		"nodes": []any{},
	}
	planBytes, err := json.Marshal(planJSON)
	if err != nil {
		t.Fatalf("marshal plan.json: %v", err)
	}
	if err := os.WriteFile(filepath.Join(tempDir, "plan.json"), planBytes, 0o644); err != nil {
		t.Fatalf("write plan.json: %v", err)
	}

	stageConfig := StageConfig{
		ID:    "work",
		Name:  "work",
		Index: intPtr(0),
	}
	inputs, err := BuildInputs(tempDir, stageConfig, 1)
	if err != nil {
		t.Fatalf("BuildInputs: %v", err)
	}
	if len(inputs.FromInitial) != 1 || inputs.FromInitial[0] != planFile {
		t.Fatalf("from_initial mismatch: %#v", inputs.FromInitial)
	}
}

func intPtr(value int) *int {
	return &value
}

func readJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func stringsContain(value, substr string) bool {
	return value != "" && strings.Contains(value, substr)
}
