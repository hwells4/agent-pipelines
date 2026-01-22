package provider

import (
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/dodo-digital/agent-pipelines/internal/validate"
)

var (
	// ErrProviderExists indicates a provider is already registered.
	ErrProviderExists = errors.New("provider already registered")
	// ErrProviderNotFound indicates the provider name is unknown.
	ErrProviderNotFound = errors.New("provider not found")
)

// Registry tracks available providers by canonical name.
type Registry struct {
	mu        sync.RWMutex
	providers map[string]Provider
}

// NewRegistry returns an empty provider registry.
func NewRegistry() *Registry {
	return &Registry{providers: make(map[string]Provider)}
}

// CanonicalName returns the normalized provider name or an error if invalid.
func CanonicalName(name string, p Provider) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" && p != nil {
		name = strings.TrimSpace(p.Name())
	}
	name = strings.ToLower(name)
	if name == "" {
		return "", errors.New("provider name is empty")
	}
	if err := validate.ProviderName(name); err != nil {
		return "", err
	}
	return name, nil
}

// Register adds a provider to the registry under its canonical name.
func (r *Registry) Register(name string, p Provider) error {
	if p == nil {
		return errors.New("provider is nil")
	}
	canonical, err := CanonicalName(name, p)
	if err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.providers[canonical]; ok {
		return ErrProviderExists
	}
	r.providers[canonical] = p
	return nil
}

// Get returns the provider registered for name or false if missing.
func (r *Registry) Get(name string) (Provider, bool) {
	canonical, err := CanonicalName(name, nil)
	if err != nil {
		return nil, false
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	p, ok := r.providers[canonical]
	return p, ok
}

// Resolve returns the provider or a descriptive not-found error.
func (r *Registry) Resolve(name string) (Provider, error) {
	canonical, err := CanonicalName(name, nil)
	if err != nil {
		return nil, err
	}

	r.mu.RLock()
	p, ok := r.providers[canonical]
	r.mu.RUnlock()
	if ok {
		return p, nil
	}

	available := r.Names()
	if len(available) == 0 {
		return nil, fmt.Errorf("%w: %q (no providers registered)", ErrProviderNotFound, canonical)
	}
	return nil, fmt.Errorf("%w: %q (available: %s)", ErrProviderNotFound, canonical, strings.Join(available, ", "))
}

// Names returns all registered provider names in sorted order.
func (r *Registry) Names() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	names := make([]string, 0, len(r.providers))
	for name := range r.providers {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
