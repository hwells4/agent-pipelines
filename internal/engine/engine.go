// Package engine provides the core execution registry for providers.
package engine

import (
	"context"
	"errors"
	"fmt"

	"github.com/dodo-digital/agent-pipelines/internal/provider"
)

// Engine coordinates provider registration and lookup.
type Engine struct {
	registry *provider.Registry
}

// New returns an Engine with an empty provider registry.
func New() *Engine {
	return &Engine{registry: provider.NewRegistry()}
}

// RegisterProvider registers a provider after Init and Validate.
func (e *Engine) RegisterProvider(name string, p provider.Provider) error {
	if e == nil {
		return errors.New("engine is nil")
	}
	if p == nil {
		return errors.New("provider is nil")
	}
	if e.registry == nil {
		e.registry = provider.NewRegistry()
	}

	canonical, err := provider.CanonicalName(name, p)
	if err != nil {
		return err
	}
	if _, ok := e.registry.Get(canonical); ok {
		return provider.ErrProviderExists
	}

	if err := p.Init(context.Background()); err != nil {
		return fmt.Errorf("init provider %q: %w", canonical, err)
	}
	if err := p.Validate(); err != nil {
		return fmt.Errorf("validate provider %q: %w", canonical, err)
	}

	return e.registry.Register(canonical, p)
}

// Provider returns a registered provider or a descriptive error.
func (e *Engine) Provider(name string) (provider.Provider, error) {
	if e == nil {
		return nil, errors.New("engine is nil")
	}
	if e.registry == nil {
		e.registry = provider.NewRegistry()
	}
	return e.registry.Resolve(name)
}
