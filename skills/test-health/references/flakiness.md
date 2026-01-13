# Flaky Test Management

Comprehensive guide to detecting, diagnosing, and eliminating flaky tests.

## What Makes a Test Flaky

A flaky test is one that passes and fails intermittently without code changes.

**The cost of flakiness:**
- Engineers lose trust in CI → ignore real failures
- Merge velocity drops → rerun until green
- Debugging time wasted → chasing ghosts
- Technical debt accumulates → flakiness breeds flakiness

## Root Causes

### 1. Timing and Race Conditions

**Symptoms:**
- Passes locally, fails in CI
- Fails more under load
- Works with `--runInBand` but fails in parallel

**Example:**
```javascript
// FLAKY: Race condition
it("shows success message", async () => {
  clickButton("submit");
  expect(screen.getByText("Success")).toBeVisible();  // Not there yet!
});

// FIXED: Proper wait
it("shows success message", async () => {
  clickButton("submit");
  await waitFor(() => {
    expect(screen.getByText("Success")).toBeVisible();
  });
});
```

**Patterns to avoid:**
```javascript
// BAD: Arbitrary sleeps
await sleep(100);
expect(result).toBe("done");

// BAD: Assuming order of async operations
Promise.all([opA(), opB()]);
expect(results).toEqual([resultA, resultB]);  // Order not guaranteed!

// BAD: setTimeout for "enough time"
setTimeout(() => expect(done).toBe(true), 500);
```

**Fixes:**
```javascript
// GOOD: Wait for condition
await waitFor(() => expect(result).toBe("done"));

// GOOD: Explicit ordering
const resultA = await opA();
const resultB = await opB();
expect(results).toEqual([resultA, resultB]);

// GOOD: Promise-based waiting
await expect(eventually(done)).resolves.toBe(true);
```

### 2. Shared State

**Symptoms:**
- Passes in isolation, fails with other tests
- Order-dependent failures
- Random failures in parallel runs

**Example:**
```javascript
// FLAKY: Shared mutable state
let counter = 0;

it("increments counter", () => {
  counter++;
  expect(counter).toBe(1);  // Fails if another test modified counter
});

// FIXED: Isolated state
beforeEach(() => {
  counter = 0;
});
```

**Common sources:**
- Global variables
- Singletons
- Module-level state
- Database records
- File system
- Environment variables

**Fixes:**
```javascript
// Reset globals
beforeEach(() => {
  jest.resetModules();
  jest.clearAllMocks();
});

// Fresh objects per test
const createUser = () => ({ name: "Test", roles: [] });

// Database transactions
beforeEach(async () => {
  await db.beginTransaction();
});
afterEach(async () => {
  await db.rollback();
});

// Isolated temp directories
let tempDir;
beforeEach(() => {
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-'));
});
afterEach(() => {
  fs.rmSync(tempDir, { recursive: true });
});
```

### 3. Time Dependencies

**Symptoms:**
- Fails at certain times (midnight, month end)
- Fails in different timezones
- Intermittent failures near boundaries

**Example:**
```javascript
// FLAKY: Time-dependent
it("shows greeting", () => {
  const greeting = getGreeting();
  expect(greeting).toBe("Good morning");  // Fails after noon!
});

// FIXED: Mocked time
it("shows morning greeting", () => {
  jest.useFakeTimers();
  jest.setSystemTime(new Date("2025-01-15T09:00:00"));

  expect(getGreeting()).toBe("Good morning");

  jest.useRealTimers();
});
```

**Patterns to watch:**
```javascript
// BAD: Assumes current time
const isExpired = date < new Date();

// BAD: Assumes timezone
expect(formatDate(date)).toBe("1/15/2025");

// BAD: Tight timing window
const token = createToken();  // Expires in 1 second
await slowOperation();
validateToken(token);  // Might be expired!
```

**Fixes:**
```javascript
// GOOD: Inject time
const isExpired = (date, now = new Date()) => date < now;

// GOOD: Explicit timezone
expect(formatDate(date, { timezone: "UTC" })).toBe("2025-01-15");

// GOOD: Generous expiration for tests
const token = createToken({ expiresIn: "1 hour" });
```

### 4. Random Data

**Symptoms:**
- Inconsistent test names in reports
- Occasional assertion failures
- Hard to reproduce locally

**Example:**
```javascript
// FLAKY: Random data might not match assertion
it("creates valid user", () => {
  const user = createUser({ name: faker.person.fullName() });
  expect(user.name).toBe("John Doe");  // Only true sometimes!
});

// FIXED: Seeded random or explicit value
it("creates valid user", () => {
  faker.seed(12345);  // Reproducible
  const user = createUser({ name: faker.person.fullName() });
  expect(user.name).toBeDefined();  // Or check the actual generated value
});
```

**Better patterns:**
```javascript
// Seed at suite level for reproducibility
beforeAll(() => {
  faker.seed(parseInt(process.env.TEST_SEED || "12345"));
});

// Or use explicit values in tests
it("creates user with long name", () => {
  const user = createUser({ name: "A".repeat(100) });
  expect(user.name.length).toBe(100);
});
```

### 5. Network Dependencies

**Symptoms:**
- Fails when network is slow
- Fails in certain environments
- Intermittent timeout failures

**Example:**
```javascript
// FLAKY: Real network call
it("fetches user data", async () => {
  const user = await fetch("https://api.example.com/users/1");
  expect(user.name).toBe("Test User");
});

// FIXED: Mocked network
it("fetches user data", async () => {
  nock("https://api.example.com")
    .get("/users/1")
    .reply(200, { name: "Test User" });

  const user = await fetchUser(1);
  expect(user.name).toBe("Test User");
});
```

### 6. Resource Contention

**Symptoms:**
- Fails under CI load
- Works locally, fails in shared environments
- Port conflicts, file locks

**Example:**
```javascript
// FLAKY: Fixed port
const server = app.listen(3000);

// FIXED: Dynamic port
const server = app.listen(0);  // OS assigns available port
const { port } = server.address();
```

**Common resources:**
- Ports
- Files (locks, temp files)
- Database connections
- Memory limits
- CPU under load

## Detection Strategies

### 1. Multiple Runs

```bash
# Run same test multiple times
jest --testNamePattern="suspicious test" --repeat=10
pytest tests/suspect.py --count=10
rspec spec/suspect_spec.rb --repeat=10
```

### 2. Random Order

```bash
# Expose order dependencies
jest --randomize
pytest --random-order
rspec --order random
```

### 3. Parallel Execution

```bash
# Expose shared state issues
jest --maxWorkers=8
pytest -n 8
rspec --parallel
```

### 4. CI History Analysis

```bash
# Find tests that have both passed and failed on same commit
# (Requires CI log analysis)

# Track retry success rate
# Tests that pass on retry = flaky
```

### 5. Stress Testing

```bash
# Run tests under load to expose timing issues
stress --cpu 4 &
npm test
killall stress
```

## Quarantine Process

### Step 1: Identify

When a test fails intermittently:

```javascript
// Mark as flaky immediately
describe.skip("flaky: JIRA-123 - user flow", () => {
  // Original test
});
```

### Step 2: Document

Create tracking issue:
```markdown
## Flaky Test: user flow

**Test file:** tests/user.test.js:45
**First detected:** 2025-01-15
**Failure rate:** ~20% (4 failures in 20 runs)
**CI failures:** [link1], [link2], [link3]

### Symptoms
- Passes locally
- Fails in CI with "element not found"
- Seems to fail more on slow runners

### Suspected cause
Race condition - not waiting for async render

### Reproduction
Run 10 times: `jest --testNamePattern="user flow" --repeat=10`
```

### Step 3: Isolate

Move to quarantine suite:

```javascript
// jest.config.js
module.exports = {
  projects: [
    {
      displayName: "main",
      testPathIgnorePatterns: ["quarantine"]
    },
    {
      displayName: "quarantine",
      testMatch: ["**/quarantine/**/*.test.js"]
    }
  ]
};
```

Run quarantine separately (non-blocking):
```yaml
# CI config
- name: Run main tests
  run: npm test -- --selectProjects=main

- name: Run quarantine tests (non-blocking)
  run: npm test -- --selectProjects=quarantine || true
```

### Step 4: Fix or Delete

**SLA: 2 weeks maximum in quarantine**

If not fixed by deadline:
1. Evaluate if test provides value
2. If yes: rewrite from scratch
3. If no: delete permanently

### Step 5: Validate Fix

Before restoring:
```bash
# Run at least 10 times
jest --testNamePattern="fixed test" --repeat=10

# Run in CI-like conditions
docker run -it --rm node:20 npm test

# Monitor for 1 week after restoration
```

## Prevention Strategies

### 1. Design for Determinism

```javascript
// Inject dependencies
function fetchUser(id, httpClient = defaultClient) {
  return httpClient.get(`/users/${id}`);
}

// Use factories with explicit values
const user = createUser({
  id: "test-123",
  createdAt: new Date("2025-01-15T00:00:00Z")
});
```

### 2. Proper Async Handling

```javascript
// Always await or return promises
it("async test", async () => {
  await expect(asyncOp()).resolves.toBe("done");
});

// Use proper wait utilities
await waitFor(() => {
  expect(element).toBeVisible();
}, { timeout: 5000 });
```

### 3. Test Isolation

```javascript
// Fresh state per test
beforeEach(() => {
  jest.resetModules();
  jest.clearAllMocks();
  jest.restoreAllMocks();
});

// Isolated containers
const container = await new PostgreSqlContainer().start();
```

### 4. CI-Aware Tests

```javascript
// Generous timeouts in CI
const TIMEOUT = process.env.CI ? 30000 : 5000;

// Skip flaky external dependencies in CI
const shouldMockExternal = process.env.CI === "true";
```

## Quarantine Tracking Template

```markdown
## Quarantined Tests - Updated YYYY-MM-DD

| Test | File | Quarantined | Ticket | SLA | Status |
|------|------|-------------|--------|-----|--------|
| user signup flow | tests/user.test.js:45 | 2025-01-10 | JIRA-123 | 2025-01-24 | In progress |
| payment processing | tests/payment.test.js:120 | 2025-01-08 | JIRA-120 | 2025-01-22 | Needs investigation |
| email notifications | tests/email.test.js:67 | 2025-01-05 | JIRA-118 | 2025-01-19 | ⚠️ OVERDUE |

### Rules
- Maximum 2 weeks in quarantine
- If not fixed by SLA → DELETE
- Track total count trend (should decrease)
- Review weekly

### Metrics
- Currently quarantined: 3
- Fixed this month: 5
- Deleted this month: 2
- Average quarantine duration: 8 days
```

## Tools and Libraries

### Flaky Test Detection

- **Jest**: `--detectOpenHandles`, `--forceExit`
- **pytest-rerunfailures**: Auto-retry failed tests
- **RSpec retry**: `rspec-retry` gem
- **Flaky test plugins**: CI-specific tools

### Test Isolation

- **testcontainers**: Isolated database/service containers
- **jest-environment-jsdom-isolated**: Fresh DOM per test
- **database_cleaner**: Ruby database isolation

### Time Mocking

- **Jest**: `jest.useFakeTimers()`
- **Sinon**: `sinon.useFakeTimers()`
- **pytest**: `freezegun`
- **timecop**: Ruby time mocking
