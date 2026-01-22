package engine

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/dodo-digital/agent-pipelines/internal/provider"
	"github.com/dodo-digital/agent-pipelines/internal/validate"
)

type testProvider struct {
	name        string
	initErr     error
	validateErr error
}

func (t *testProvider) Name() string { return t.name }
func (t *testProvider) Init(ctx context.Context) error {
	return t.initErr
}
func (t *testProvider) Execute(ctx context.Context, req provider.ExecuteRequest) (*provider.ExecuteResult, error) {
	return &provider.ExecuteResult{}, nil
}
func (t *testProvider) Shutdown(ctx context.Context) error { return nil }
func (t *testProvider) Capabilities() provider.Capabilities {
	return provider.Capabilities{}
}
func (t *testProvider) Validate() error {
	return t.validateErr
}

func TestRegisterProviderInitError(t *testing.T) {
	engine := New()
	err := engine.RegisterProvider("codex", &testProvider{name: "codex", initErr: errors.New("boom")})
	if err == nil || !strings.Contains(err.Error(), "init provider") {
		t.Fatalf("RegisterProvider() error = %v, want init provider failure", err)
	}
}

func TestRegisterProviderValidateError(t *testing.T) {
	engine := New()
	err := engine.RegisterProvider("codex", &testProvider{name: "codex", validateErr: errors.New("bad")})
	if err == nil || !strings.Contains(err.Error(), "validate provider") {
		t.Fatalf("RegisterProvider() error = %v, want validate provider failure", err)
	}
}

func TestRegisterProviderDuplicate(t *testing.T) {
	engine := New()
	if err := engine.RegisterProvider("codex", &testProvider{name: "codex"}); err != nil {
		t.Fatalf("RegisterProvider() error = %v", err)
	}
	err := engine.RegisterProvider("codex", &testProvider{name: "codex"})
	if !errors.Is(err, provider.ErrProviderExists) {
		t.Fatalf("RegisterProvider() error = %v, want %v", err, provider.ErrProviderExists)
	}
}

func TestRegisterProviderInvalidName(t *testing.T) {
	engine := New()
	err := engine.RegisterProvider("Bad_Name", &testProvider{name: "Bad_Name"})
	if !errors.Is(err, validate.ErrProviderNameInvalid) {
		t.Fatalf("RegisterProvider() error = %v, want %v", err, validate.ErrProviderNameInvalid)
	}
}

func TestProviderLookupUsesRegistry(t *testing.T) {
	engine := New()
	if err := engine.RegisterProvider("claude", &testProvider{name: "claude"}); err != nil {
		t.Fatalf("RegisterProvider() error = %v", err)
	}
	got, err := engine.Provider("claude")
	if err != nil {
		t.Fatalf("Provider() error = %v", err)
	}
	if got == nil {
		t.Fatalf("Provider() returned nil provider")
	}
	_, err = engine.Provider("missing")
	if !errors.Is(err, provider.ErrProviderNotFound) {
		t.Fatalf("Provider() error = %v, want %v", err, provider.ErrProviderNotFound)
	}
}
