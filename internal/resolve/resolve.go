// Package resolve handles prompt template variable substitution.
package resolve

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Vars contains supported template variables.
type Vars struct {
	CTX           string
	STATUS        string
	RESULT        string
	PROGRESS      string
	OUTPUT        string
	SESSION       string
	ITERATION     string
	INDEX         string
	PERSPECTIVE   string
	OUTPUT_PATH   string
	PROGRESS_FILE string
	CONTEXT       string
}

// ResolveTemplate replaces known placeholders in template with vars values.
// Unknown placeholders are left unchanged.
func ResolveTemplate(template string, vars Vars) string {
	vars = vars.normalized()
	replacements := []struct {
		key   string
		value string
	}{
		{"CTX", vars.CTX},
		{"STATUS", vars.STATUS},
		{"RESULT", vars.RESULT},
		{"PROGRESS", vars.PROGRESS},
		{"OUTPUT", vars.OUTPUT},
		{"SESSION", vars.SESSION},
		{"SESSION_NAME", vars.SESSION},
		{"ITERATION", vars.ITERATION},
		{"INDEX", vars.INDEX},
		{"PERSPECTIVE", vars.PERSPECTIVE},
		{"OUTPUT_PATH", vars.OUTPUT_PATH},
		{"PROGRESS_FILE", vars.PROGRESS_FILE},
		{"CONTEXT", vars.CONTEXT},
	}

	resolved := template
	for _, replacement := range replacements {
		placeholder := "${" + replacement.key + "}"
		resolved = strings.ReplaceAll(resolved, placeholder, replacement.value)
	}
	return resolved
}

// ResolveTemplateFromContext loads context.json and resolves template variables.
func ResolveTemplateFromContext(template, contextPath string) (string, error) {
	vars, err := VarsFromContext(contextPath)
	if err != nil {
		return "", err
	}
	return ResolveTemplate(template, vars), nil
}

// ResolveTemplateFromLegacyJSON resolves template variables using legacy JSON vars.
func ResolveTemplateFromLegacyJSON(template string, varsJSON []byte) (string, error) {
	vars, err := VarsFromLegacyJSON(varsJSON)
	if err != nil {
		return "", err
	}
	return ResolveTemplate(template, vars), nil
}

// VarsFromContext builds Vars from a context.json file.
func VarsFromContext(path string) (Vars, error) {
	if strings.TrimSpace(path) == "" {
		return Vars{}, fmt.Errorf("context path is empty")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return Vars{}, fmt.Errorf("read context: %w", err)
	}

	var payload struct {
		Session   string `json:"session"`
		Iteration *int   `json:"iteration"`
		Paths     struct {
			Progress string `json:"progress"`
			Output   string `json:"output"`
			Status   string `json:"status"`
			Result   string `json:"result"`
		} `json:"paths"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		return Vars{}, fmt.Errorf("parse context: %w", err)
	}

	iteration := ""
	if payload.Iteration != nil {
		iteration = strconv.Itoa(*payload.Iteration)
	}

	vars := Vars{
		CTX:           path,
		STATUS:        payload.Paths.Status,
		RESULT:        payload.Paths.Result,
		PROGRESS:      payload.Paths.Progress,
		OUTPUT:        payload.Paths.Output,
		SESSION:       payload.Session,
		ITERATION:     iteration,
		PROGRESS_FILE: payload.Paths.Progress,
	}
	return vars.normalized(), nil
}

// VarsFromLegacyJSON builds Vars from legacy JSON inputs (engine.sh vars_json).
func VarsFromLegacyJSON(raw []byte) (Vars, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 {
		return Vars{}, nil
	}

	var payload map[string]json.RawMessage
	if err := json.Unmarshal(raw, &payload); err != nil {
		return Vars{}, fmt.Errorf("parse legacy vars: %w", err)
	}

	get := func(key string) string {
		if value, ok := payload[key]; ok {
			return stringFromRaw(value)
		}
		return ""
	}

	vars := Vars{
		SESSION:       get("session"),
		ITERATION:     get("iteration"),
		INDEX:         get("index"),
		PERSPECTIVE:   get("perspective"),
		OUTPUT:        get("output"),
		OUTPUT_PATH:   get("output_path"),
		PROGRESS:      get("progress"),
		PROGRESS_FILE: get("progress_file"),
		CONTEXT:       get("context"),
		CTX:           get("context_file"),
		STATUS:        get("status_file"),
		RESULT:        get("result_file"),
	}
	return vars.normalized(), nil
}

func (v Vars) normalized() Vars {
	if v.PROGRESS_FILE == "" {
		v.PROGRESS_FILE = v.PROGRESS
	}
	return v
}

func stringFromRaw(raw json.RawMessage) string {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return ""
	}

	var asString string
	if err := json.Unmarshal(raw, &asString); err == nil {
		return asString
	}

	var asNumber json.Number
	if err := json.Unmarshal(raw, &asNumber); err == nil {
		return asNumber.String()
	}

	var asBool bool
	if err := json.Unmarshal(raw, &asBool); err == nil {
		return strconv.FormatBool(asBool)
	}

	return ""
}
