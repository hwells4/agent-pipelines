package stage

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestResolveStagePrecedence(t *testing.T) {
	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	pipelineDir := filepath.Join(tempDir, "pipeline")
	agentRoot := filepath.Join(tempDir, "agent")

	projectStages := filepath.Join(projectRoot, ".claude", "stages")
	pipelineStages := filepath.Join(pipelineDir, "stages")
	agentStages := filepath.Join(agentRoot, "scripts", "stages")

	projectStageDir := writeStage(t, projectStages, "alpha", "", "prompt.md")
	writeStage(t, pipelineStages, "alpha", "", "prompt.md")
	writeStage(t, agentStages, "alpha", "", "prompt.md")

	def, err := ResolveStage("alpha", ResolveOptions{
		ProjectRoot:        projectRoot,
		PipelineDir:        pipelineDir,
		AgentPipelinesRoot: agentRoot,
	})
	if err != nil {
		t.Fatalf("ResolveStage: %v", err)
	}

	wantConfig := filepath.Join(projectStageDir, "stage.yaml")
	if def.ConfigPath != wantConfig {
		t.Fatalf("ConfigPath mismatch: got %q want %q", def.ConfigPath, wantConfig)
	}
	wantPrompt := filepath.Join(projectStageDir, "prompt.md")
	if def.PromptPath != wantPrompt {
		t.Fatalf("PromptPath mismatch: got %q want %q", def.PromptPath, wantPrompt)
	}
	if def.Dir != projectStageDir {
		t.Fatalf("Dir mismatch: got %q want %q", def.Dir, projectStageDir)
	}
}

func TestResolveStagePromptField(t *testing.T) {
	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	projectStages := filepath.Join(projectRoot, ".claude", "stages")

	stageDir := writeStage(t, projectStages, "alpha", "prompts/custom.md", "prompts/custom.md")
	writeFile(t, filepath.Join(stageDir, "prompt.md"))

	def, err := ResolveStage("alpha", ResolveOptions{ProjectRoot: projectRoot})
	if err != nil {
		t.Fatalf("ResolveStage: %v", err)
	}

	wantPrompt := filepath.Join(stageDir, "prompts", "custom.md")
	if def.PromptPath != wantPrompt {
		t.Fatalf("PromptPath mismatch: got %q want %q", def.PromptPath, wantPrompt)
	}
}

func TestResolveStageMissingPrompt(t *testing.T) {
	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	projectStages := filepath.Join(projectRoot, ".claude", "stages")

	writeStage(t, projectStages, "alpha", "", "")

	_, err := ResolveStage("alpha", ResolveOptions{ProjectRoot: projectRoot})
	if err == nil {
		t.Fatal("expected error for missing prompt")
	}
	if !strings.Contains(err.Error(), "stage alpha has no prompt.md or prompt: field") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestResolveStageNotFoundListsPaths(t *testing.T) {
	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	pipelineDir := filepath.Join(tempDir, "pipeline")
	agentRoot := filepath.Join(tempDir, "agent")

	_, err := ResolveStage("missing", ResolveOptions{
		ProjectRoot:        projectRoot,
		PipelineDir:        pipelineDir,
		AgentPipelinesRoot: agentRoot,
	})
	if err == nil {
		t.Fatal("expected error for missing stage")
	}

	expectedPaths := []string{
		filepath.Join(projectRoot, ".claude", "stages", "missing", "stage.yaml"),
		filepath.Join(pipelineDir, "stages", "missing", "stage.yaml"),
		filepath.Join(agentRoot, "scripts", "stages", "missing", "stage.yaml"),
	}
	for _, path := range expectedPaths {
		if !strings.Contains(err.Error(), path) {
			t.Fatalf("error missing path %q: %v", path, err)
		}
	}
}

func writeStage(t *testing.T, stagesRoot, name, promptField, promptFile string) string {
	t.Helper()

	stageDir := filepath.Join(stagesRoot, name)
	if err := os.MkdirAll(stageDir, 0o755); err != nil {
		t.Fatalf("mkdir stage dir: %v", err)
	}

	var builder strings.Builder
	builder.WriteString("name: ")
	builder.WriteString(name)
	builder.WriteString("\n")
	if promptField != "" {
		builder.WriteString("prompt: ")
		builder.WriteString(promptField)
		builder.WriteString("\n")
	}
	if err := os.WriteFile(filepath.Join(stageDir, "stage.yaml"), []byte(builder.String()), 0o644); err != nil {
		t.Fatalf("write stage.yaml: %v", err)
	}

	if promptFile != "" {
		writeFile(t, filepath.Join(stageDir, promptFile))
	}

	return stageDir
}

func writeFile(t *testing.T, path string) {
	t.Helper()

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir prompt dir: %v", err)
	}
	if err := os.WriteFile(path, []byte("prompt"), 0o644); err != nil {
		t.Fatalf("write prompt file: %v", err)
	}
}
