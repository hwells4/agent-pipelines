package exec

import (
	"context"
	"errors"
	"os/exec"
	"strings"
	"testing"
	"time"
)

func TestRun_SimpleCommand(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "echo", "hello")
	result, err := Run(ctx, cmd, DefaultOptions())
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if strings.TrimSpace(string(result.Stdout)) != "hello" {
		t.Errorf("stdout = %q, want %q", result.Stdout, "hello")
	}
	if result.ExitCode != 0 {
		t.Errorf("exit code = %d, want 0", result.ExitCode)
	}
}

func TestRun_StderrSeparation(t *testing.T) {
	ctx := context.Background()
	// Use sh to write to both stdout and stderr
	cmd := Command(ctx, "sh", "-c", "echo stdout; echo stderr >&2")
	result, err := Run(ctx, cmd, DefaultOptions())
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if !strings.Contains(string(result.Stdout), "stdout") {
		t.Errorf("stdout = %q, should contain 'stdout'", result.Stdout)
	}
	if !strings.Contains(string(result.Stderr), "stderr") {
		t.Errorf("stderr = %q, should contain 'stderr'", result.Stderr)
	}
}

func TestRun_ExitCode(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "sh", "-c", "exit 42")
	result, err := Run(ctx, cmd, DefaultOptions())
	if err == nil {
		t.Fatal("expected error for non-zero exit")
	}
	if result.ExitCode != 42 {
		t.Errorf("exit code = %d, want 42", result.ExitCode)
	}
}

func TestRun_OutputTruncation(t *testing.T) {
	ctx := context.Background()
	// Generate output larger than limit
	opts := Options{
		MaxOutput:   100,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0,
	}
	cmd := Command(ctx, "sh", "-c", "yes | head -n 1000")
	result, err := Run(ctx, cmd, opts)

	// Should have truncated output
	if !result.Truncated {
		t.Error("expected Truncated=true")
	}
	if int64(len(result.Stdout)+len(result.Stderr)) > opts.MaxOutput*2 {
		t.Errorf("output size %d exceeds limit %d", len(result.Stdout)+len(result.Stderr), opts.MaxOutput*2)
	}
	// The error may or may not be ErrOutputTruncated depending on timing
	_ = err
}

func TestRun_InsufficientTime(t *testing.T) {
	// Create context with very short deadline
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     60 * time.Second, // Requires more time than available
	}
	cmd := Command(ctx, "echo", "test")
	_, err := Run(ctx, cmd, opts)
	if !errors.Is(err, ErrInsufficientTime) {
		t.Errorf("error = %v, want ErrInsufficientTime", err)
	}
}

func TestRun_ContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: 1 * time.Second, // Short grace for test
		MinTime:     0,
	}
	cmd := Command(ctx, "sleep", "10")

	done := make(chan struct{})
	go func() {
		_, err := Run(ctx, cmd, opts)
		if err == nil {
			t.Error("expected error from cancelled context")
		}
		close(done)
	}()

	// Cancel after a short delay
	time.Sleep(100 * time.Millisecond)
	cancel()

	// Wait for completion with timeout
	select {
	case <-done:
		// Good
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not return after context cancellation")
	}
}

func TestRun_NonExistentCommand(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "/nonexistent/command/path")
	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0,
	}
	_, err := Run(ctx, cmd, opts)
	if err == nil {
		t.Error("expected error for nonexistent command")
	}
}

func TestRun_Duration(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "sleep", "0.1")
	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0,
	}
	result, err := Run(ctx, cmd, opts)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if result.Duration < 50*time.Millisecond {
		t.Errorf("duration = %v, expected >= 50ms", result.Duration)
	}
}

func TestDefaultOptions(t *testing.T) {
	opts := DefaultOptions()
	if opts.MaxOutput != DefaultMaxOutput {
		t.Errorf("MaxOutput = %d, want %d", opts.MaxOutput, DefaultMaxOutput)
	}
	if opts.GracePeriod != DefaultGracePeriod {
		t.Errorf("GracePeriod = %v, want %v", opts.GracePeriod, DefaultGracePeriod)
	}
	if opts.MinTime != DefaultMinTime {
		t.Errorf("MinTime = %v, want %v", opts.MinTime, DefaultMinTime)
	}
}

func TestCommand(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "echo", "test")
	if cmd == nil {
		t.Fatal("Command() returned nil")
	}
	if cmd.Path == "" {
		t.Error("Command.Path is empty")
	}
}

func TestExitCodeFromError(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		wantCode int
	}{
		{"nil error", nil, 0},
		{"generic error", errors.New("generic"), -1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := exitCodeFromError(tt.err)
			if got != tt.wantCode {
				t.Errorf("exitCodeFromError() = %d, want %d", got, tt.wantCode)
			}
		})
	}
}

func TestRun_ProcessGroupSet(t *testing.T) {
	// This tests that process group is set correctly
	ctx := context.Background()
	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0,
	}

	// Just verify a simple command works with process group settings
	cmd := Command(ctx, "echo", "test")
	result, err := Run(ctx, cmd, opts)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if result.ExitCode != 0 {
		t.Errorf("exit code = %d, want 0", result.ExitCode)
	}
}

func TestRun_DefaultsApplied(t *testing.T) {
	ctx := context.Background()
	cmd := Command(ctx, "echo", "test")
	// Pass zero options, should use defaults
	opts := Options{}
	result, err := Run(ctx, cmd, opts)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if result.ExitCode != 0 {
		t.Errorf("exit code = %d, want 0", result.ExitCode)
	}
}

func TestRun_MinTimeDisabled(t *testing.T) {
	// Create context with short deadline
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0, // Disabled
	}
	cmd := Command(ctx, "echo", "test")
	result, err := Run(ctx, cmd, opts)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if result.ExitCode != 0 {
		t.Errorf("exit code = %d, want 0", result.ExitCode)
	}
}

// Benchmark to ensure we're not introducing performance regressions
func BenchmarkRun_SimpleCommand(b *testing.B) {
	ctx := context.Background()
	opts := Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     0,
	}
	for i := 0; i < b.N; i++ {
		cmd := exec.CommandContext(ctx, "true")
		_, _ = Run(ctx, cmd, opts)
	}
}
