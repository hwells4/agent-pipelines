package provider

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/dodo-digital/agent-pipelines/internal/validate"
)

type stubProvider struct {
	name string
}

func (s *stubProvider) Name() string                   { return s.name }
func (s *stubProvider) Init(ctx context.Context) error { return nil }
func (s *stubProvider) Execute(ctx context.Context, req ExecuteRequest) (*ExecuteResult, error) {
	return &ExecuteResult{}, nil
}
func (s *stubProvider) Shutdown(ctx context.Context) error { return nil }
func (s *stubProvider) Capabilities() Capabilities         { return Capabilities{} }
func (s *stubProvider) Validate() error                    { return nil }

func TestRegistryRegisterAndGet(t *testing.T) {
	registry := NewRegistry()
	provider := &stubProvider{name: "codex"}

	if err := registry.Register("", provider); err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if _, ok := registry.Get("codex"); !ok {
		t.Fatalf("Get() missing provider")
	}
	if _, ok := registry.Get("CODEX"); !ok {
		t.Fatalf("Get() should normalize provider names")
	}
}

func TestRegistryDuplicate(t *testing.T) {
	registry := NewRegistry()
	provider := &stubProvider{name: "claude"}

	if err := registry.Register("", provider); err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if err := registry.Register("claude", provider); !errors.Is(err, ErrProviderExists) {
		t.Fatalf("Register() error = %v, want %v", err, ErrProviderExists)
	}
}

func TestRegistryInvalidName(t *testing.T) {
	registry := NewRegistry()
	provider := &stubProvider{name: "bad_name"}

	err := registry.Register("", provider)
	if !errors.Is(err, validate.ErrProviderNameInvalid) {
		t.Fatalf("Register() error = %v, want %v", err, validate.ErrProviderNameInvalid)
	}
}

func TestRegistryResolveErrorIncludesAvailable(t *testing.T) {
	registry := NewRegistry()
	if err := registry.Register("codex", &stubProvider{name: "codex"}); err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if err := registry.Register("claude", &stubProvider{name: "claude"}); err != nil {
		t.Fatalf("Register() error = %v", err)
	}

	_, err := registry.Resolve("missing")
	if !errors.Is(err, ErrProviderNotFound) {
		t.Fatalf("Resolve() error = %v, want %v", err, ErrProviderNotFound)
	}
	if err == nil || !strings.Contains(err.Error(), "available: claude, codex") {
		t.Fatalf("Resolve() error = %v, want available providers list", err)
	}
}

func TestRegistryResolveNoProviders(t *testing.T) {
	registry := NewRegistry()
	_, err := registry.Resolve("missing")
	if !errors.Is(err, ErrProviderNotFound) {
		t.Fatalf("Resolve() error = %v, want %v", err, ErrProviderNotFound)
	}
	if err == nil || !strings.Contains(err.Error(), "no providers registered") {
		t.Fatalf("Resolve() error = %v, want no providers registered message", err)
	}
}
