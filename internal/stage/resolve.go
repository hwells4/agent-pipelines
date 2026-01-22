// Package stage resolves stage configuration and prompt locations.
package stage

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Definition describes a resolved stage configuration.
type Definition struct {
	Name       string
	Dir        string
	ConfigPath string
	PromptPath string
}

// ResolveOptions defines search roots for stage resolution.
type ResolveOptions struct {
	ProjectRoot        string
	PipelineDir        string
	AgentPipelinesRoot string
	BuiltinDefinitions map[string]Definition
}

// ResolveStage locates a stage definition by name using precedence rules.
func ResolveStage(name string, opts ResolveOptions) (Definition, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return Definition{}, fmt.Errorf("stage name is empty")
	}

	if strings.TrimSpace(opts.AgentPipelinesRoot) == "" {
		opts.AgentPipelinesRoot = os.Getenv("AGENT_PIPELINES_ROOT")
	}

	var candidates []string
	addCandidate := func(path string) {
		if strings.TrimSpace(path) != "" {
			candidates = append(candidates, path)
		}
	}

	if strings.TrimSpace(opts.ProjectRoot) != "" {
		addCandidate(filepath.Join(opts.ProjectRoot, ".claude", "stages", name, "stage.yaml"))
	}
	if strings.TrimSpace(opts.PipelineDir) != "" {
		addCandidate(filepath.Join(opts.PipelineDir, "stages", name, "stage.yaml"))
	}
	if strings.TrimSpace(opts.AgentPipelinesRoot) != "" {
		addCandidate(filepath.Join(opts.AgentPipelinesRoot, "scripts", "stages", name, "stage.yaml"))
	}

	for _, candidate := range candidates {
		if fileExists(candidate) {
			return definitionFromPath(name, candidate)
		}
	}

	if opts.BuiltinDefinitions != nil {
		if def, ok := opts.BuiltinDefinitions[name]; ok {
			return def, nil
		}
	}

	if len(candidates) == 0 {
		return Definition{}, fmt.Errorf("stage %q not found; no search paths configured", name)
	}

	return Definition{}, fmt.Errorf("stage %q not found; searched: %s", name, strings.Join(candidates, ", "))
}

func definitionFromPath(name, configPath string) (Definition, error) {
	stageDir := filepath.Dir(configPath)
	promptPath, err := resolvePromptPath(stageDir, configPath, name)
	if err != nil {
		return Definition{}, err
	}
	return Definition{
		Name:       name,
		Dir:        stageDir,
		ConfigPath: configPath,
		PromptPath: promptPath,
	}, nil
}

func resolvePromptPath(stageDir, configPath, stageName string) (string, error) {
	promptField, err := readPromptField(configPath)
	if err != nil {
		return "", fmt.Errorf("read prompt field: %w", err)
	}

	var candidates []string
	if promptField != "" && promptField != "null" {
		candidate := promptField
		if !filepath.IsAbs(candidate) {
			candidate = filepath.Join(stageDir, candidate)
		}
		candidates = append(candidates, filepath.Clean(candidate))
	}
	candidates = append(candidates, filepath.Join(stageDir, "prompt.md"))

	for _, candidate := range candidates {
		if fileExists(candidate) {
			return candidate, nil
		}
	}

	return "", fmt.Errorf("stage %s has no prompt.md or prompt: field", stageName)
}

func readPromptField(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.TrimLeft(line, " \t") != line {
			continue
		}
		if !strings.HasPrefix(trimmed, "prompt:") {
			continue
		}

		raw := strings.TrimSpace(strings.TrimPrefix(trimmed, "prompt:"))
		if raw == "" || raw == "null" || raw == "~" {
			return "", nil
		}
		if strings.HasPrefix(raw, "|") || strings.HasPrefix(raw, ">") {
			return "", nil
		}

		raw = strings.TrimSpace(stripInlineComment(raw))
		if raw == "" || raw == "null" || raw == "~" {
			return "", nil
		}

		if strings.HasPrefix(raw, "\"") {
			if unquoted, err := strconv.Unquote(raw); err == nil {
				return unquoted, nil
			}
		}
		if strings.HasPrefix(raw, "'") {
			return unquoteSingle(raw), nil
		}
		return raw, nil
	}

	if err := scanner.Err(); err != nil {
		return "", err
	}
	return "", nil
}

func stripInlineComment(value string) string {
	if value == "" {
		return value
	}
	if strings.HasPrefix(value, "\"") || strings.HasPrefix(value, "'") {
		return value
	}
	if idx := strings.Index(value, " #"); idx != -1 {
		return strings.TrimSpace(value[:idx])
	}
	return value
}

func unquoteSingle(value string) string {
	if len(value) < 2 || value[0] != '\'' || value[len(value)-1] != '\'' {
		return value
	}
	inner := value[1 : len(value)-1]
	return strings.ReplaceAll(inner, "''", "'")
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}
