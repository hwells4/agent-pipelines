// Package exec provides robust process execution with bounded output,
// proper signal handling, and process group management.
package exec

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"syscall"
	"time"
)

// Default values for execution options.
const (
	// DefaultMaxOutput is the maximum output size (1 MiB).
	DefaultMaxOutput = 1 * 1024 * 1024

	// DefaultGracePeriod is the time between SIGTERM and SIGKILL.
	DefaultGracePeriod = 30 * time.Second

	// DefaultMinTime is the minimum remaining context time to start execution.
	DefaultMinTime = 30 * time.Second
)

var (
	// ErrOutputTruncated indicates output was truncated due to size limits.
	ErrOutputTruncated = errors.New("output truncated")

	// ErrInsufficientTime indicates not enough time remains in context.
	ErrInsufficientTime = errors.New("insufficient time remaining")

	// ErrKilled indicates the process was killed after grace period.
	ErrKilled = errors.New("process killed after grace period")
)

// Options configures execution behavior.
type Options struct {
	// MaxOutput limits combined stdout+stderr size. Default: 1 MiB.
	MaxOutput int64

	// GracePeriod is time between SIGTERM and SIGKILL. Default: 30s.
	GracePeriod time.Duration

	// MinTime is minimum context time needed to start. Default: 30s.
	// Set to 0 to disable the check.
	MinTime time.Duration
}

// DefaultOptions returns options with default values.
func DefaultOptions() Options {
	return Options{
		MaxOutput:   DefaultMaxOutput,
		GracePeriod: DefaultGracePeriod,
		MinTime:     DefaultMinTime,
	}
}

// Result contains the execution output and metadata.
type Result struct {
	Stdout    []byte
	Stderr    []byte
	ExitCode  int
	Truncated bool
	Duration  time.Duration
}

// Run executes a command with bounded output and proper signal handling.
// It uses process groups for reliable cleanup and a graceful shutdown sequence.
func Run(ctx context.Context, cmd *exec.Cmd, opts Options) (*Result, error) {
	// Apply defaults
	if opts.MaxOutput <= 0 {
		opts.MaxOutput = DefaultMaxOutput
	}
	if opts.GracePeriod <= 0 {
		opts.GracePeriod = DefaultGracePeriod
	}

	// Check remaining context time (fail fast - BUG-050)
	if opts.MinTime > 0 {
		if deadline, ok := ctx.Deadline(); ok {
			remaining := time.Until(deadline)
			if remaining < opts.MinTime {
				return nil, fmt.Errorf("%w: %v remaining, need %v", ErrInsufficientTime, remaining.Round(time.Second), opts.MinTime)
			}
		}
	}

	// Set up process group for reliable cleanup (BUG-006)
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.Setpgid = true

	// Set up bounded output capture (BUG-003, BUG-033)
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("stdout pipe: %w", err)
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("stderr pipe: %w", err)
	}

	// Start the command (no pre-check, let it fail naturally - BUG-044)
	started := time.Now()
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start: %w", err)
	}

	// Read output with size limit
	var stdout, stderr bytes.Buffer
	truncated := false

	// Use LimitedReader to bound output
	stdoutLimited := io.LimitReader(stdoutPipe, opts.MaxOutput)
	stderrLimited := io.LimitReader(stderrPipe, opts.MaxOutput)

	// Read stdout and stderr concurrently
	errCh := make(chan error, 2)
	go func() {
		_, err := io.Copy(&stdout, stdoutLimited)
		errCh <- err
	}()
	go func() {
		_, err := io.Copy(&stderr, stderrLimited)
		errCh <- err
	}()

	// Wait for both readers
	for i := 0; i < 2; i++ {
		if err := <-errCh; err != nil && !errors.Is(err, io.EOF) {
			// Non-fatal, continue
		}
	}

	// Check if we hit the limit
	if int64(stdout.Len()+stderr.Len()) >= opts.MaxOutput {
		truncated = true
	}

	// Wait for process with signal cascade (BUG-059)
	waitDone := make(chan error, 1)
	go func() {
		waitDone <- cmd.Wait()
	}()

	var waitErr error
	select {
	case waitErr = <-waitDone:
		// Process completed normally
	case <-ctx.Done():
		// Context cancelled - initiate graceful shutdown
		waitErr = gracefulShutdown(cmd, opts.GracePeriod, waitDone)
	}

	duration := time.Since(started)
	exitCode := exitCodeFromError(waitErr)

	result := &Result{
		Stdout:    stdout.Bytes(),
		Stderr:    stderr.Bytes(),
		ExitCode:  exitCode,
		Truncated: truncated,
		Duration:  duration,
	}

	// Return appropriate error
	if truncated && waitErr == nil {
		return result, ErrOutputTruncated
	}
	return result, waitErr
}

// gracefulShutdown sends SIGTERM, waits for grace period, then SIGKILL.
func gracefulShutdown(cmd *exec.Cmd, gracePeriod time.Duration, waitDone <-chan error) error {
	// Get process group ID (negative PID signals the entire group)
	pgid, err := syscall.Getpgid(cmd.Process.Pid)
	if err != nil {
		pgid = cmd.Process.Pid
	}

	// Send SIGTERM to process group
	_ = syscall.Kill(-pgid, syscall.SIGTERM)

	// Wait for graceful termination
	select {
	case err := <-waitDone:
		return err
	case <-time.After(gracePeriod):
		// Grace period expired, force kill
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
		err := <-waitDone
		if err != nil {
			return fmt.Errorf("%w: %v", ErrKilled, err)
		}
		return ErrKilled
	}
}

// exitCodeFromError extracts exit code from an error.
func exitCodeFromError(err error) int {
	if err == nil {
		return 0
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode()
	}
	return -1
}

// Command creates a new exec.Cmd with the given arguments.
// This is a convenience wrapper around exec.CommandContext.
func Command(ctx context.Context, name string, args ...string) *exec.Cmd {
	return exec.CommandContext(ctx, name, args...)
}
