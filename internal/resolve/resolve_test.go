package resolve

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestResolveTemplateFromContext(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	contextPath := filepath.Join(tempDir, "context.json")
	progressPath := filepath.Join(tempDir, "progress.md")
	outputPath := filepath.Join(tempDir, "output.md")
	statusPath := filepath.Join(tempDir, "status.json")
	resultPath := filepath.Join(tempDir, "result.json")

	payload := map[string]any{
		"session":   "alpha-session",
		"iteration": 2,
		"paths": map[string]string{
			"progress": progressPath,
			"output":   outputPath,
			"status":   statusPath,
			"result":   resultPath,
		},
	}
	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal context: %v", err)
	}
	if err := os.WriteFile(contextPath, data, 0o644); err != nil {
		t.Fatalf("write context: %v", err)
	}

	template := "CTX:${CTX} STATUS:${STATUS} RESULT:${RESULT} PROGRESS:${PROGRESS} OUTPUT:${OUTPUT} " +
		"SESSION:${SESSION_NAME} ITER:${ITERATION} PROGRESS_FILE:${PROGRESS_FILE}"
	resolved, err := ResolveTemplateFromContext(template, contextPath)
	if err != nil {
		t.Fatalf("ResolveTemplateFromContext: %v", err)
	}

	expected := "CTX:" + contextPath + " STATUS:" + statusPath + " RESULT:" + resultPath +
		" PROGRESS:" + progressPath + " OUTPUT:" + outputPath +
		" SESSION:alpha-session ITER:2 PROGRESS_FILE:" + progressPath
	if resolved != expected {
		t.Fatalf("resolved mismatch:\nexpected: %q\ngot:      %q", expected, resolved)
	}
}

func TestResolveTemplateFromLegacyJSON(t *testing.T) {
	t.Parallel()

	varsJSON := []byte(`{"session":"legacy","iteration":5,"progress":"/tmp/progress.md","context":"Focus"}`)
	template := "Session:${SESSION} Iter:${ITERATION} Progress:${PROGRESS} Context:${CONTEXT} Missing:${PERSPECTIVE}"

	resolved, err := ResolveTemplateFromLegacyJSON(template, varsJSON)
	if err != nil {
		t.Fatalf("ResolveTemplateFromLegacyJSON: %v", err)
	}

	expected := "Session:legacy Iter:5 Progress:/tmp/progress.md Context:Focus Missing:"
	if resolved != expected {
		t.Fatalf("resolved mismatch:\nexpected: %q\ngot:      %q", expected, resolved)
	}
}

func TestResolveTemplateUnknownPlaceholder(t *testing.T) {
	t.Parallel()

	template := "Hello ${UNKNOWN} world"
	resolved := ResolveTemplate(template, Vars{SESSION: "session"})

	if resolved != template {
		t.Fatalf("unknown placeholder should remain unchanged: %q", resolved)
	}
}

func TestResolveTemplatePreservesWhitespace(t *testing.T) {
	t.Parallel()

	template := "Line1\r\n  ${CONTEXT}\r\nLine3"
	resolved := ResolveTemplate(template, Vars{CONTEXT: "value"})

	expected := "Line1\r\n  value\r\nLine3"
	if resolved != expected {
		t.Fatalf("whitespace mismatch:\nexpected: %q\ngot:      %q", expected, resolved)
	}
}
