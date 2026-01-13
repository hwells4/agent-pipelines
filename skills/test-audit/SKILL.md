---
name: test-audit
description: Audit test suite for quality issues, anti-patterns, and AI-generated test smells. Use when reviewing tests, after AI generates tests, or when test suite feels unreliable.
---

## What This Skill Does

Analyzes existing tests to find:
1. **AI hardcoding** - Tests that assert exact outputs without understanding why
2. **Mock/reality mismatch** - Mocks that don't match actual implementations
3. **Test anti-patterns** - The Liar, The Giant, The Mockery, etc.
4. **Fixture problems** - Unrealistic data, magic values, missing edge cases
5. **Flaky test indicators** - Time-dependent, order-dependent, race conditions

This is NOT about coverage. It's about whether your existing tests are actually trustworthy.

## When to Use

- After AI generates tests (validate they're not just "making it pass")
- When tests feel unreliable or flaky
- Before major refactoring (ensure tests will catch real bugs)
- Code review of test files
- Periodic test suite health check

## Red Flags to Detect

### 1. AI Hardcoding (Most Critical)

AI often writes tests that just assert whatever the code returns, without understanding intent.

**Symptoms:**
```javascript
// RED FLAG: Magic values with no explanation
expect(result).toBe("a]d8f2k9");
expect(hash).toBe("e3b0c44298fc1c149afbf4c8996fb924");

// RED FLAG: Exact object matching on generated data
expect(user).toEqual({
  id: "usr_1705123456789",
  createdAt: "2024-01-13T10:30:45.123Z"
});

// RED FLAG: Suspiciously specific numbers
expect(calculateScore(data)).toBe(847.3291);
```

**What good tests look like:**
```javascript
// GOOD: Tests the property, not the value
expect(result).toMatch(/^[a-z0-9]{10}$/);
expect(hash).toHaveLength(64);

// GOOD: Tests structure and relationships
expect(user.id).toMatch(/^usr_/);
expect(new Date(user.createdAt)).toBeInstanceOf(Date);

// GOOD: Tests behavior with known inputs
expect(calculateScore({ items: [], bonus: 0 })).toBe(0);
expect(calculateScore({ items: [10], bonus: 5 })).toBe(15);
```

### 2. Mock/Reality Mismatch

Mocks that return data the real implementation would never return.

**Symptoms:**
```javascript
// RED FLAG: Mock returns structure that doesn't match real API
mockApi.getUser.mockResolvedValue({ name: "Test" });
// But real API returns: { data: { user: { name: "...", email: "..." } } }

// RED FLAG: Mock never rejects
mockDb.query.mockResolvedValue([]);
// But real DB can throw connection errors

// RED FLAG: Mock has different error format
mockService.call.mockRejectedValue(new Error("fail"));
// But real service returns: { error: { code: "E001", message: "..." } }
```

**What to check:**
- Compare mock return values against actual API responses
- Ensure error mocks match real error formats
- Verify mock method signatures match real implementations

### 3. The Liar (Tests That Don't Test)

Tests that pass but don't actually verify anything meaningful.

**Symptoms:**
```javascript
// RED FLAG: No assertions
it("processes data", async () => {
  await processData(input);
});

// RED FLAG: Only checks it doesn't throw
it("handles user", () => {
  expect(() => handleUser(user)).not.toThrow();
});

// RED FLAG: Asserts on the mock, not the result
it("calls the API", () => {
  service.fetchUser("123");
  expect(mockApi.get).toHaveBeenCalled();
  // But never checks what was DONE with the response!
});
```

### 4. The Giant (Too Many Assertions)

Tests that verify multiple unrelated behaviors.

**Symptoms:**
```javascript
// RED FLAG: Testing everything in one test
it("user service works", () => {
  const user = service.create({ name: "Test" });
  expect(user.id).toBeDefined();
  expect(user.name).toBe("Test");
  expect(user.createdAt).toBeDefined();
  expect(service.count()).toBe(1);
  expect(service.findById(user.id)).toEqual(user);
  expect(service.findByName("Test")).toContain(user);
  service.delete(user.id);
  expect(service.count()).toBe(0);
});
```

**Should be split into:**
- `it("creates user with generated id")`
- `it("sets createdAt timestamp")`
- `it("can find user by id")`
- etc.

### 5. The Mockery (Over-Mocking)

Tests that mock so much they're not testing real behavior.

**Symptoms:**
```javascript
// RED FLAG: Mocking the thing you're testing
jest.mock("./calculator");
it("calculates", () => {
  Calculator.add.mockReturnValue(5);
  expect(Calculator.add(2, 3)).toBe(5); // What are we testing?!
});

// RED FLAG: Mocking internal implementation
jest.spyOn(service, "_privateHelper");
jest.spyOn(service, "_validateInput");
jest.spyOn(service, "_formatOutput");
```

### 6. Fixture Problems

**Symptoms:**
```javascript
// RED FLAG: Minimal fixtures that skip edge cases
const testUser = { name: "Test" };
// Missing: email, id, roles, edge cases

// RED FLAG: Magic values without explanation
const config = { threshold: 42, factor: 3.14159 };

// RED FLAG: Copy-pasted fixtures with no variation
const user1 = { id: "1", name: "Test", email: "test@test.com" };
const user2 = { id: "2", name: "Test", email: "test@test.com" };
const user3 = { id: "3", name: "Test", email: "test@test.com" };
```

### 7. Flaky Test Indicators

**Symptoms:**
```javascript
// RED FLAG: Time-dependent
expect(result.timestamp).toBe(Date.now());

// RED FLAG: Random without seeding
const id = generateId();
expect(id).toBe("abc123"); // Will fail randomly

// RED FLAG: Order-dependent
let counter = 0;
it("first test", () => { counter++; expect(counter).toBe(1); });
it("second test", () => { expect(counter).toBe(1); }); // Depends on first!

// RED FLAG: Async without proper waiting
setTimeout(() => { result = "done"; }, 100);
expect(result).toBe("done"); // Race condition
```

### 8. Green Units, Dead System (Test Layer Gaps)

All unit tests pass but the system doesn't work. This happens when units are tested in isolation but never verified to work together.

**Pattern A: Orphan Functions**
```javascript
// Unit test passes:
describe("validateEmail", () => {
  it("returns true for valid email", () => {
    expect(validateEmail("test@example.com")).toBe(true);
  });
});

// BUT: validateEmail is never actually called anywhere!
// The registration form uses a different validator.
```

**Pattern B: Missing Wiring Tests**
```javascript
// Unit tests pass for each piece:
// ✅ UserService.create() works
// ✅ EmailService.send() works
// ✅ AuditLogger.log() works

// BUT: No test verifies they're wired together:
// When a user is created, does it actually send the email?
// Does it actually log the audit event?
```

**Pattern C: Interface Drift**
```javascript
// Unit test mocks the dependency:
it("processes order", () => {
  mockPaymentService.charge.mockResolvedValue({ success: true });
  const result = await orderService.process(order);
  expect(result.status).toBe("completed");
});

// BUT: PaymentService.charge() signature changed!
// It now returns { charged: true, transactionId: "..." }
// Unit test passes, real system fails
```

**Pattern D: Call Path Gaps**
```javascript
// You have tests for:
// - Controller.handleRequest() ✅
// - Service.processData() ✅
// - Repository.save() ✅

// But no test verifies:
// Controller → Service → Repository actually chains correctly
// Maybe Controller calls wrong Service method
// Maybe Service doesn't call Repository at all
```

**How to detect:**

1. **Find untested call paths:**
```bash
# Find all function definitions
grep -r "function\|const.*=.*=>" src/

# Find all function calls in tests
grep -r "expect\|spy\|mock" tests/

# Compare: which functions are defined but never appear in test call chains?
```

2. **Check for integration test coverage:**
```bash
# If you only have unit tests and no integration tests, you likely have this problem
ls tests/unit/      # Many files
ls tests/integration/  # Empty or few files? RED FLAG
```

3. **Trace entry points:**
   - Find your API endpoints / CLI commands / event handlers
   - For each, verify there's a test that exercises the full path
   - Not mocked, actually calling through the layers

4. **Mock audit:**
   - List every mock in your test suite
   - For each mock, ask: "Is there an integration test that uses the real implementation?"
   - If answer is "no" for critical paths, you have this problem

**What good coverage looks like:**
```
Entry Point (API/CLI/Event)
    ↓
  [Integration Test] ← Verifies full path works
    ↓
Controller/Handler
    ↓
  [Unit Test] ← Verifies logic in isolation
    ↓
Service Layer
    ↓
  [Unit Test] ← Verifies logic in isolation
    ↓
Repository/External
    ↓
  [Contract Test] ← Verifies interface matches reality
```

**Minimum viable integration coverage:**
- Every public API endpoint has at least one integration test
- Every CLI command has at least one end-to-end test
- Every event handler has at least one test with real (or realistic fake) dependencies

### 9. The Inverse: Integration Without Units

Having integration tests but no unit tests creates different problems.

**Symptoms:**
```javascript
// Only integration tests exist:
it("user registration flow", async () => {
  const response = await request(app)
    .post("/register")
    .send({ email: "test@example.com", password: "password123" });

  expect(response.status).toBe(201);
});

// But no unit tests for:
// - Email validation logic
// - Password hashing
// - User model constraints
// - Edge cases (duplicate email, weak password, etc.)
```

**Problems:**
- Tests are slow (full stack for every scenario)
- Hard to test edge cases
- Failures are hard to diagnose (which layer broke?)
- Can't run tests in parallel easily

**Detection:**
```bash
# Check test execution time
time npm test

# If basic test suite takes > 30 seconds, likely over-relying on integration tests

# Check test type ratio
find tests -name "*.test.*" | wc -l  # Total tests
find tests/integration -name "*.test.*" | wc -l  # Integration tests
# If integration > 50% of total, investigate
```

## Process

### 1. Identify Scope

Ask what to audit:
- Specific test file(s)?
- All tests in a directory?
- Tests for a specific feature?
- Recently AI-generated tests?

### 2. Read Tests and Source

For each test file:
1. Read the test file completely
2. Read the corresponding source file
3. Identify what's being mocked vs real

### 3. Check Each Test Against Red Flags

For each test, evaluate:
- [ ] Are assertions meaningful or just "whatever it returned"?
- [ ] Do mocks match real implementation signatures/responses?
- [ ] Is there at least one meaningful assertion?
- [ ] Is it testing one behavior or many?
- [ ] Are fixtures realistic and varied?
- [ ] Any time/random dependencies without controls?

### 4. Cross-Reference Mocks

For any mocked dependency:
1. Find the real implementation
2. Compare mock return values to real return values
3. Flag mismatches

### 5. Report Findings

Group findings by severity:

**Critical (Tests are lying):**
- AI hardcoded values that will break on any change
- Mocks that return impossible data
- Tests with no assertions

**High (Tests are fragile):**
- Flaky test indicators
- Over-mocking real behavior
- Giant tests that hide failures

**Medium (Tests could be better):**
- Minimal fixtures
- Testing implementation vs behavior
- Missing edge cases

**Low (Style issues):**
- Inconsistent naming
- Duplicated setup
- Poor organization

### 6. Suggest Fixes

For each issue, provide:
- What's wrong
- Why it matters
- How to fix it (with example)

## Output Format

```markdown
# Test Audit Report

## Summary
- Files audited: X
- Tests reviewed: Y
- Critical issues: N
- High issues: N
- Medium issues: N

## Critical Issues

### [filename:line] AI Hardcoded Assertion
**Test:** `it("generates token")`
**Problem:** Asserts exact token value `"abc123xyz"` which appears to be hardcoded from a single run
**Impact:** Test will fail when token generation changes, but won't catch actual bugs
**Fix:**
```javascript
// Instead of:
expect(token).toBe("abc123xyz");

// Use:
expect(token).toMatch(/^[a-z0-9]{9}$/);
expect(token).toHaveLength(9);
```

### [filename:line] Mock Returns Impossible Data
**Test:** `it("fetches user")`
**Problem:** Mock returns `{ name: "Test" }` but real API returns `{ data: { user: {...} } }`
**Impact:** Test passes but real code would fail on `response.data.user`
**Fix:** Update mock to match real API response structure

## High Issues
...

## Recommendations
1. ...
2. ...
```

## Success Criteria

- [ ] Identified AI hardcoding patterns
- [ ] Cross-referenced mocks against real implementations
- [ ] Flagged tests without meaningful assertions
- [ ] Noted fixture quality issues
- [ ] **Analyzed test layer balance (unit vs integration vs e2e)**
- [ ] **Identified orphan functions (tested but never called)**
- [ ] **Verified critical paths have integration coverage**
- [ ] Provided actionable fix suggestions
- [ ] Report organized by severity

## References

- `references/anti-patterns.md` - Detailed anti-pattern detection heuristics
- `references/quick-checklist.md` - Rapid audit checklist
- `references/layer-analysis.md` - Test layer gap detection
