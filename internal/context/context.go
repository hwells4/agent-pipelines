// Package context handles context.json generation and input resolution.
package context

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	defaultMaxIterations = 50
	stageDirFormat       = "stage-%02d-%s"
	iterationDirFormat   = "%03d"
)

// StageConfig represents the subset of stage config used for context generation.
type StageConfig struct {
	ID                string                   `json:"id"`
	Name              string                   `json:"name"`
	Index             *int                     `json:"index"`
	Template          string                   `json:"template"`
	Loop              string                   `json:"loop"`
	MaxIterations     *int                     `json:"max_iterations"`
	MaxRuntimeSeconds *int                     `json:"max_runtime_seconds"`
	Guardrails        *GuardrailsConfig        `json:"guardrails"`
	Inputs            *InputsConfig            `json:"inputs"`
	Commands          map[string]any           `json:"commands"`
	ParallelScope     *ParallelScope           `json:"parallel_scope"`
	ParallelBlocks    map[string]ParallelBlock `json:"parallel_blocks"`
}

// GuardrailsConfig represents guardrails settings from stage config.
type GuardrailsConfig struct {
	MaxRuntimeSeconds *int `json:"max_runtime_seconds"`
}

// InputsConfig holds stage input configuration.
type InputsConfig struct {
	From         string          `json:"from"`
	Select       string          `json:"select"`
	FromParallel json.RawMessage `json:"from_parallel"`
}

// ParallelScope defines scope roots for parallel blocks.
type ParallelScope struct {
	ScopeRoot    string `json:"scope_root"`
	PipelineRoot string `json:"pipeline_root"`
}

// ParallelBlock describes a parallel block manifest location.
type ParallelBlock struct {
	ManifestPath string `json:"manifest_path"`
}

// ContextManifest is the structure written to context.json.
type ContextManifest struct {
	Session   string         `json:"session"`
	Pipeline  string         `json:"pipeline"`
	Stage     StageRef       `json:"stage"`
	Iteration int            `json:"iteration"`
	Paths     ContextPaths   `json:"paths"`
	Inputs    Inputs         `json:"inputs"`
	Limits    Limits         `json:"limits"`
	Commands  map[string]any `json:"commands"`
}

// StageRef describes the stage metadata in context.json.
type StageRef struct {
	ID       string `json:"id"`
	Index    int    `json:"index"`
	Template string `json:"template"`
}

// ContextPaths enumerates paths for iteration files.
type ContextPaths struct {
	SessionDir string `json:"session_dir"`
	StageDir   string `json:"stage_dir"`
	Progress   string `json:"progress"`
	Output     string `json:"output"`
	Status     string `json:"status"`
	Result     string `json:"result"`
}

// Inputs contains inputs for the current iteration.
type Inputs struct {
	FromStage              map[string][]string `json:"from_stage"`
	FromPreviousIterations []string            `json:"from_previous_iterations"`
	FromInitial            []string            `json:"from_initial"`
	FromParallel           []map[string]any    `json:"from_parallel,omitempty"`
}

// Limits contains iteration limits.
type Limits struct {
	MaxIterations    int `json:"max_iterations"`
	RemainingSeconds int `json:"remaining_seconds"`
}

// GenerateContext creates context.json for an iteration and returns its path.
func GenerateContext(session string, iteration int, stageConfig StageConfig, runDir string) (string, error) {
	stageID := stageIdentifier(stageConfig)
	stageIdx := stageIndex(stageConfig)
	stageTemplate := stageTemplate(stageConfig)

	stageDir := filepath.Join(runDir, fmt.Sprintf(stageDirFormat, stageIdx, stageID))
	iterDir := filepath.Join(stageDir, "iterations", fmt.Sprintf(iterationDirFormat, iteration))

	if err := os.MkdirAll(iterDir, 0o755); err != nil {
		return "", fmt.Errorf("create iteration dir: %w", err)
	}

	progressFile := filepath.Join(stageDir, "progress.md")
	if !fileExists(progressFile) {
		sessionProgress := filepath.Join(runDir, fmt.Sprintf("progress-%s.md", session))
		if fileExists(sessionProgress) {
			progressFile = sessionProgress
		}
	}

	outputFile := filepath.Join(stageDir, "output.md")
	statusFile := filepath.Join(iterDir, "status.json")
	resultFile := filepath.Join(iterDir, "result.json")

	inputs, err := BuildInputs(runDir, stageConfig, iteration)
	if err != nil {
		return "", err
	}

	maxIterations := defaultMaxIterations
	if stageConfig.MaxIterations != nil {
		maxIterations = *stageConfig.MaxIterations
	}

	remaining, err := CalculateRemainingSeconds(runDir, stageConfig)
	if err != nil {
		return "", err
	}

	pipeline := readPipelineName(filepath.Join(runDir, "state.json"))

	commands := stageConfig.Commands
	if commands == nil {
		commands = map[string]any{}
	}

	manifest := ContextManifest{
		Session:   session,
		Pipeline:  pipeline,
		Stage:     StageRef{ID: stageID, Index: stageIdx, Template: stageTemplate},
		Iteration: iteration,
		Paths: ContextPaths{
			SessionDir: runDir,
			StageDir:   stageDir,
			Progress:   progressFile,
			Output:     outputFile,
			Status:     statusFile,
			Result:     resultFile,
		},
		Inputs: inputs,
		Limits: Limits{
			MaxIterations:    maxIterations,
			RemainingSeconds: remaining,
		},
		Commands: commands,
	}

	manifestPath := filepath.Join(iterDir, "context.json")
	payload, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal context: %w", err)
	}
	if err := os.WriteFile(manifestPath, append(payload, '\n'), 0o644); err != nil {
		return "", fmt.Errorf("write context: %w", err)
	}
	return manifestPath, nil
}

// CalculateRemainingSeconds computes remaining runtime from stage config and state.json.
func CalculateRemainingSeconds(runDir string, stageConfig StageConfig) (int, error) {
	maxRuntime := -1
	if stageConfig.Guardrails != nil && stageConfig.Guardrails.MaxRuntimeSeconds != nil {
		maxRuntime = *stageConfig.Guardrails.MaxRuntimeSeconds
	} else if stageConfig.MaxRuntimeSeconds != nil {
		maxRuntime = *stageConfig.MaxRuntimeSeconds
	}

	if maxRuntime < 0 {
		return -1, nil
	}

	statePath := filepath.Join(runDir, "state.json")
	if !fileExists(statePath) {
		return maxRuntime, nil
	}

	data, err := os.ReadFile(statePath)
	if err != nil {
		return maxRuntime, nil
	}

	var state struct {
		StartedAt string `json:"started_at"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return maxRuntime, nil
	}
	if strings.TrimSpace(state.StartedAt) == "" || state.StartedAt == "null" {
		return maxRuntime, nil
	}

	startedAt, err := time.Parse(time.RFC3339, state.StartedAt)
	if err != nil {
		return maxRuntime, nil
	}

	elapsed := int(time.Since(startedAt).Seconds())
	remaining := maxRuntime - elapsed
	if remaining < 0 {
		return 0, nil
	}
	return remaining, nil
}

// BuildInputs resolves inputs for the current iteration.
func BuildInputs(runDir string, stageConfig StageConfig, iteration int) (Inputs, error) {
	inputs := Inputs{
		FromStage:              map[string][]string{},
		FromPreviousIterations: []string{},
		FromInitial:            []string{},
	}

	if stageConfig.Inputs != nil && stageConfig.Inputs.From != "" {
		sourceDir := resolveStageDir(runDir, stageConfig, stageConfig.Inputs.From)
		if sourceDir != "" {
			selectMode := stageConfig.Inputs.Select
			if selectMode == "" {
				selectMode = "latest"
			}

			switch selectMode {
			case "all":
				outputs := listStageOutputs(sourceDir)
				inputs.FromStage[stageConfig.Inputs.From] = outputs
			default:
				latest := latestStageOutput(sourceDir)
				if latest == "" {
					inputs.FromStage[stageConfig.Inputs.From] = []string{}
				} else {
					inputs.FromStage[stageConfig.Inputs.From] = []string{latest}
				}
			}
		}
	}

	if iteration > 1 {
		stageDir := filepath.Join(runDir, fmt.Sprintf(stageDirFormat, stageIndex(stageConfig), stageIdentifier(stageConfig)))
		for i := 1; i < iteration; i++ {
			output := filepath.Join(stageDir, "iterations", fmt.Sprintf(iterationDirFormat, i), "output.md")
			if fileExists(output) {
				inputs.FromPreviousIterations = append(inputs.FromPreviousIterations, output)
			}
		}
	}

	planFile := filepath.Join(runDir, "plan.json")
	if stageConfig.ParallelScope != nil && stageConfig.ParallelScope.PipelineRoot != "" {
		pipelinePlan := filepath.Join(stageConfig.ParallelScope.PipelineRoot, "plan.json")
		if fileExists(pipelinePlan) {
			planFile = pipelinePlan
		}
	}
	inputs.FromInitial = loadPlanInputs(planFile)

	if stageConfig.Inputs != nil && len(stageConfig.Inputs.FromParallel) > 0 {
		fromParallel, include, err := buildFromParallelInputs(stageConfig, runDir)
		if err != nil {
			return Inputs{}, err
		}
		if include {
			inputs.FromParallel = fromParallel
		}
	}

	return inputs, nil
}

func stageIdentifier(stageConfig StageConfig) string {
	if strings.TrimSpace(stageConfig.ID) != "" {
		return stageConfig.ID
	}
	if strings.TrimSpace(stageConfig.Name) != "" {
		return stageConfig.Name
	}
	return "default"
}

func stageIndex(stageConfig StageConfig) int {
	if stageConfig.Index != nil {
		return *stageConfig.Index
	}
	return 0
}

func stageTemplate(stageConfig StageConfig) string {
	if stageConfig.Template != "" {
		return stageConfig.Template
	}
	return stageConfig.Loop
}

func resolveStageDir(runDir string, stageConfig StageConfig, stageName string) string {
	if stageConfig.ParallelScope != nil && stageConfig.ParallelScope.ScopeRoot != "" {
		if dir := findStageDir(stageConfig.ParallelScope.ScopeRoot, stageName); dir != "" {
			return dir
		}
		if stageConfig.ParallelScope.PipelineRoot != "" {
			return findStageDir(stageConfig.ParallelScope.PipelineRoot, stageName)
		}
		return ""
	}
	return findStageDir(runDir, stageName)
}

func findStageDir(root, stageName string) string {
	pattern := filepath.Join(root, "stage-*-"+stageName)
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return ""
	}
	sort.Strings(matches)
	for _, match := range matches {
		info, err := os.Stat(match)
		if err == nil && info.IsDir() {
			return match
		}
	}
	return ""
}

func listStageOutputs(stageDir string) []string {
	iterDir := filepath.Join(stageDir, "iterations")
	entries, err := os.ReadDir(iterDir)
	if err != nil {
		return []string{}
	}
	var names []string
	for _, entry := range entries {
		if entry.IsDir() {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)

	var outputs []string
	for _, name := range names {
		output := filepath.Join(iterDir, name, "output.md")
		if fileExists(output) {
			outputs = append(outputs, output)
		}
	}
	return outputs
}

func latestStageOutput(stageDir string) string {
	iterDir := filepath.Join(stageDir, "iterations")
	entries, err := os.ReadDir(iterDir)
	if err != nil {
		return ""
	}
	var names []string
	for _, entry := range entries {
		if entry.IsDir() {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)
	if len(names) == 0 {
		return ""
	}
	latest := names[len(names)-1]
	output := filepath.Join(iterDir, latest, "output.md")
	if fileExists(output) {
		return output
	}
	return ""
}

func loadPlanInputs(planFile string) []string {
	if !fileExists(planFile) {
		return []string{}
	}
	data, err := os.ReadFile(planFile)
	if err != nil {
		return []string{}
	}

	var plan struct {
		Session struct {
			Inputs json.RawMessage `json:"inputs"`
		} `json:"session"`
	}
	if err := json.Unmarshal(data, &plan); err != nil {
		return []string{}
	}
	if len(plan.Session.Inputs) == 0 {
		return []string{}
	}

	var inputs []string
	if err := json.Unmarshal(plan.Session.Inputs, &inputs); err != nil {
		return []string{}
	}
	if inputs == nil {
		return []string{}
	}
	return inputs
}

func buildFromParallelInputs(stageConfig StageConfig, runDir string) ([]map[string]any, bool, error) {
	raw := bytes.TrimSpace(stageConfig.Inputs.FromParallel)
	if len(raw) == 0 || string(raw) == "null" {
		return nil, false, nil
	}

	var decoded any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		return nil, false, fmt.Errorf("parse from_parallel: %w", err)
	}

	switch decoded.(type) {
	case []any:
		var entries []map[string]any
		var rawEntries []json.RawMessage
		if err := json.Unmarshal(raw, &rawEntries); err != nil {
			return nil, false, fmt.Errorf("parse from_parallel array: %w", err)
		}
		for _, entry := range rawEntries {
			resolved, found, err := buildFromParallelInputsSingle(entry, stageConfig, runDir)
			if err != nil {
				return nil, false, err
			}
			if found {
				entries = append(entries, resolved)
			}
		}
		if len(entries) == 0 {
			return nil, false, nil
		}
		return entries, true, nil
	default:
		resolved, found, err := buildFromParallelInputsSingle(raw, stageConfig, runDir)
		if err != nil {
			return nil, false, err
		}
		if !found {
			resolved = map[string]any{}
		}
		return []map[string]any{resolved}, true, nil
	}
}

type fromParallelConfig struct {
	Stage     string          `json:"stage"`
	Block     string          `json:"block"`
	Select    string          `json:"select"`
	Providers json.RawMessage `json:"providers"`
}

func buildFromParallelInputsSingle(raw json.RawMessage, stageConfig StageConfig, runDir string) (map[string]any, bool, error) {
	stageName := ""
	blockName := ""
	selectMode := "latest"
	providersFilter := []string{}
	providersFilterAll := true

	var asString string
	if err := json.Unmarshal(raw, &asString); err == nil {
		stageName = asString
	} else {
		var cfg fromParallelConfig
		if err := json.Unmarshal(raw, &cfg); err != nil {
			return nil, false, fmt.Errorf("parse from_parallel entry: %w", err)
		}
		stageName = cfg.Stage
		blockName = cfg.Block
		if cfg.Select != "" {
			selectMode = cfg.Select
		}
		if len(cfg.Providers) > 0 {
			var providersRaw any
			if err := json.Unmarshal(cfg.Providers, &providersRaw); err == nil {
				switch providers := providersRaw.(type) {
				case []any:
					for _, p := range providers {
						if name, ok := p.(string); ok {
							providersFilter = append(providersFilter, name)
						}
					}
					if len(providersFilter) > 0 {
						providersFilterAll = false
					}
				case string:
					if providers == "all" {
						providersFilterAll = true
					}
				}
			}
		}
	}

	manifestPath := resolveManifestPath(stageConfig, runDir, stageName, blockName)
	if manifestPath == "" {
		return map[string]any{}, false, nil
	}

	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		return map[string]any{}, false, nil
	}

	var manifest struct {
		Block struct {
			Name string `json:"name"`
		} `json:"block"`
		Providers map[string]map[string]json.RawMessage `json:"providers"`
	}
	if err := json.Unmarshal(manifestData, &manifest); err != nil {
		return map[string]any{}, false, nil
	}

	blockNameFromManifest := manifest.Block.Name
	if strings.TrimSpace(blockNameFromManifest) == "" {
		blockNameFromManifest = "unknown"
	}

	providerKeys := make([]string, 0, len(manifest.Providers))
	for key := range manifest.Providers {
		providerKeys = append(providerKeys, key)
	}
	sort.Strings(providerKeys)

	providersJSON := map[string]any{}
	for _, provider := range providerKeys {
		if !providersFilterAll && !containsString(providersFilter, provider) {
			continue
		}
		stageEntries := manifest.Providers[provider]
		stageRaw, ok := stageEntries[stageName]
		if !ok || len(bytes.TrimSpace(stageRaw)) == 0 || bytes.Equal(bytes.TrimSpace(stageRaw), []byte("{}")) {
			continue
		}

		var stageData struct {
			LatestOutput      string   `json:"latest_output"`
			Status            string   `json:"status"`
			Iterations        int      `json:"iterations"`
			TerminationReason string   `json:"termination_reason"`
			History           []string `json:"history"`
		}
		if err := json.Unmarshal(stageRaw, &stageData); err != nil {
			continue
		}

		entry := map[string]any{
			"output":             stageData.LatestOutput,
			"status":             stageData.Status,
			"iterations":         stageData.Iterations,
			"termination_reason": stageData.TerminationReason,
		}
		if selectMode == "history" {
			entry["history"] = stageData.History
		}
		providersJSON[provider] = entry
	}

	return map[string]any{
		"stage":     stageName,
		"block":     blockNameFromManifest,
		"select":    selectMode,
		"manifest":  manifestPath,
		"providers": providersJSON,
	}, true, nil
}

func resolveManifestPath(stageConfig StageConfig, runDir, stageName, blockName string) string {
	manifestPath := ""

	if blockName != "" && stageConfig.ParallelBlocks != nil {
		if block, ok := stageConfig.ParallelBlocks[blockName]; ok {
			manifestPath = block.ManifestPath
		}
	} else if len(stageConfig.ParallelBlocks) > 0 {
		keys := make([]string, 0, len(stageConfig.ParallelBlocks))
		for key := range stageConfig.ParallelBlocks {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		manifestPath = stageConfig.ParallelBlocks[keys[0]].ManifestPath
	}

	if manifestPath != "" && fileExists(manifestPath) {
		return manifestPath
	}

	pipelineRoot := ""
	if stageConfig.ParallelScope != nil {
		pipelineRoot = stageConfig.ParallelScope.PipelineRoot
	}
	if pipelineRoot != "" {
		if path := findManifestForStage(pipelineRoot, stageName); path != "" {
			return path
		}
	}

	return findManifestForStage(runDir, stageName)
}

func findManifestForStage(root, stageName string) string {
	pattern := filepath.Join(root, "parallel-*")
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return ""
	}
	sort.Strings(matches)
	for _, dir := range matches {
		manifestPath := filepath.Join(dir, "manifest.json")
		if !fileExists(manifestPath) {
			continue
		}
		if manifestHasStage(manifestPath, stageName) {
			return manifestPath
		}
	}
	return ""
}

func manifestHasStage(manifestPath, stageName string) bool {
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return false
	}
	var manifest struct {
		Providers map[string]map[string]json.RawMessage `json:"providers"`
	}
	if err := json.Unmarshal(data, &manifest); err != nil {
		return false
	}
	for _, stages := range manifest.Providers {
		if _, ok := stages[stageName]; ok {
			return true
		}
	}
	return false
}

func readPipelineName(statePath string) string {
	if !fileExists(statePath) {
		return ""
	}
	data, err := os.ReadFile(statePath)
	if err != nil {
		return ""
	}
	var state struct {
		Pipeline string `json:"pipeline"`
		Type     string `json:"type"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return ""
	}
	if strings.TrimSpace(state.Pipeline) != "" {
		return state.Pipeline
	}
	return state.Type
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func containsString(values []string, value string) bool {
	for _, v := range values {
		if v == value {
			return true
		}
	}
	return false
}
