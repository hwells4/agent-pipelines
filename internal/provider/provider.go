// Package provider defines the interfaces and types for execution backends.
package provider

import (
	"context"
	"time"
)

// Provider is the execution interface for agent backends.
type Provider interface {
	// Name returns the provider identifier (e.g., "claude", "codex").
	Name() string
	// Init performs one-time setup before Execute calls.
	Init(ctx context.Context) error
	// Execute runs the prompt and returns the result.
	Execute(ctx context.Context, req ExecuteRequest) (*ExecuteResult, error)
	// Shutdown releases provider resources.
	Shutdown(ctx context.Context) error
	// Capabilities returns supported provider features.
	Capabilities() Capabilities
	// Validate checks whether the provider is properly configured.
	Validate() error
}

// ExecuteRequest defines the data required to execute a provider.
type ExecuteRequest struct {
	Prompt      string
	Model       string
	Config      map[string]any
	WorkDir     string
	Environment map[string]string
	StatusPath  string
	ResultPath  string
}

// ExecuteResult captures provider execution output and metadata.
type ExecuteResult struct {
	Output     string
	ExitCode   int
	Duration   time.Duration
	TokensUsed *TokenUsage
}

// TokenUsage captures optional token metrics.
type TokenUsage struct {
	Prompt     int
	Completion int
	Total      int
}

// Capabilities describes what a provider can do.
type Capabilities struct {
	SupportsTools         bool
	SupportsReasoningCtrl bool
	SupportedModels       []string
	RequiresSandbox       bool
}
