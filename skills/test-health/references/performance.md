# Test Performance Optimization

Guide to identifying and fixing slow tests.

## Why Test Speed Matters

**Developer velocity impact:**
- 30-second suite: Run on every save → fast feedback loop
- 5-minute suite: Run before commit → slower iteration
- 30-minute suite: Run in CI only → bugs found late
- 60+ minute suite: Developers avoid running tests → tests become noise

**Target benchmarks:**
| Test Type | Target | Acceptable | Too Slow |
|-----------|--------|------------|----------|
| Single unit test | <50ms | <200ms | >500ms |
| Unit test file | <2s | <5s | >10s |
| All unit tests | <2min | <5min | >10min |
| Integration test | <10s | <30s | >60s |
| All integration | <10min | <20min | >30min |
| E2E test | <2min | <5min | >10min |
| Full suite | <15min | <30min | >60min |

## Finding Slow Tests

### Jest

```bash
# Show test durations
jest --verbose 2>&1 | grep -E "^\s+✓|✕" | sort -t'(' -k2 -rn | head -20

# JSON output for scripting
jest --json | jq '[.testResults[].testResults[] | {name: .title, duration: .duration}] | sort_by(-.duration) | .[0:20]'

# Run with timing
jest --logHeapUsage
```

### pytest

```bash
# Show N slowest tests
pytest --durations=20

# All durations
pytest --durations=0

# Profile tests
pytest --profile
```

### RSpec

```bash
# Profile mode (top 10)
rspec --profile 10

# All examples
rspec --profile 0
```

### Go

```bash
# Verbose with timing
go test -v ./... 2>&1 | grep -E "--- (PASS|FAIL):" | sort -t'(' -k2 -rn

# Benchmark tests
go test -bench=. -benchmem
```

## Common Performance Problems

### 1. Database Setup Per Test

**Problem:**
```javascript
// SLOW: Full database reset per test
beforeEach(async () => {
  await db.drop();
  await db.create();
  await db.migrate();
  await db.seed();
});
```
Time: 2-5 seconds per test × 500 tests = 17-42 minutes

**Fix: Transaction rollback**
```javascript
// FAST: Wrap each test in transaction
beforeEach(async () => {
  await db.beginTransaction();
});

afterEach(async () => {
  await db.rollback();
});
```
Time: 5-10ms per test × 500 tests = 2.5-5 seconds

**Fix: Database cleaner strategies**
```ruby
# Fastest: transaction (when possible)
DatabaseCleaner.strategy = :transaction

# Medium: deletion (for multi-connection tests)
DatabaseCleaner.strategy = :deletion

# Slowest: truncation (only when needed)
DatabaseCleaner.strategy = :truncation
```

### 2. Unnecessary I/O

**Problem:**
```javascript
// SLOW: Reading files every test
it("processes file", () => {
  const content = fs.readFileSync("large-file.json");
  const result = process(JSON.parse(content));
  expect(result).toBeDefined();
});
```

**Fix: Cache or inline**
```javascript
// FAST: Inline test data
const testData = { key: "value" };

it("processes data", () => {
  const result = process(testData);
  expect(result).toBeDefined();
});

// OR: Load once per suite
let fileContent;
beforeAll(() => {
  fileContent = JSON.parse(fs.readFileSync("large-file.json"));
});
```

### 3. Real Network Calls

**Problem:**
```javascript
// SLOW: Actual HTTP request
it("fetches user", async () => {
  const user = await axios.get("https://api.example.com/users/1");
  expect(user.data.name).toBeDefined();
});
```
Time: 100-2000ms per request

**Fix: Mock HTTP**
```javascript
// FAST: Mocked response
jest.mock("axios");
axios.get.mockResolvedValue({ data: { name: "Test" } });

it("fetches user", async () => {
  const user = await axios.get("https://api.example.com/users/1");
  expect(user.data.name).toBe("Test");
});
```
Time: <1ms

### 4. Heavy Mocking Overhead

**Problem:**
```javascript
// SLOW: Re-mocking heavy modules per test
describe("tests", () => {
  it("test 1", () => {
    jest.mock("./heavy-module");  // Re-mocked
    // ...
  });

  it("test 2", () => {
    jest.mock("./heavy-module");  // Re-mocked again
    // ...
  });
});
```

**Fix: Mock once at file level**
```javascript
// FAST: Single mock setup
jest.mock("./heavy-module");

describe("tests", () => {
  it("test 1", () => { /* ... */ });
  it("test 2", () => { /* ... */ });
});
```

### 5. Synchronous Sleeps

**Problem:**
```javascript
// SLOW: Waiting arbitrary time
it("completes async operation", async () => {
  triggerOperation();
  await sleep(2000);  // Wastes 2 seconds
  expect(result).toBe("done");
});
```

**Fix: Condition-based waiting**
```javascript
// FAST: Wait only as long as needed
it("completes async operation", async () => {
  triggerOperation();
  await waitFor(() => result === "done", { timeout: 2000 });
  expect(result).toBe("done");
});
```

### 6. Serial Test Execution

**Problem:**
```bash
# SLOW: Running tests sequentially
npm test  # Single thread
```

**Fix: Parallel execution**
```bash
# Jest: Parallel by default, configure workers
jest --maxWorkers=4

# pytest: Use pytest-xdist
pytest -n auto

# RSpec: Use parallel_tests
bundle exec parallel_rspec spec/

# Go: Parallel by default
go test ./...
```

**Note:** Parallel tests require proper isolation.

### 7. Integration Tests for Unit Logic

**Problem:**
```javascript
// SLOW: Full HTTP stack for simple validation
it("validates email format", async () => {
  const response = await request(app)
    .post("/validate-email")
    .send({ email: "test@example.com" });
  expect(response.status).toBe(200);
});
```
Time: 50-200ms (server startup, HTTP handling)

**Fix: Unit test the function**
```javascript
// FAST: Direct function call
import { validateEmail } from "./validation";

it("validates email format", () => {
  expect(validateEmail("test@example.com")).toBe(true);
  expect(validateEmail("invalid")).toBe(false);
});
```
Time: <1ms

### 8. Expensive Setup in beforeEach

**Problem:**
```javascript
// SLOW: Heavy setup repeated per test
let app;
beforeEach(async () => {
  app = await createApplication();  // 500ms each time
  await app.warmup();
  await app.loadPlugins();
});
```

**Fix: Move to beforeAll where possible**
```javascript
// FAST: One-time setup
let app;
beforeAll(async () => {
  app = await createApplication();
  await app.warmup();
  await app.loadPlugins();
});

beforeEach(() => {
  // Only reset state that tests modify
  app.resetState();
});
```

## Optimization Strategies

### 1. Test Categorization

Separate fast from slow tests:

```javascript
// jest.config.js
module.exports = {
  projects: [
    {
      displayName: "unit",
      testMatch: ["**/*.unit.test.js"],
      // Fast tests run first
    },
    {
      displayName: "integration",
      testMatch: ["**/*.integration.test.js"],
    }
  ]
};
```

Run unit tests frequently, integration less often:
```bash
npm run test:unit          # Every save
npm run test:integration   # Before commit
npm run test               # In CI
```

### 2. Test Sharding

Split tests across CI workers:

```yaml
# GitHub Actions
jobs:
  test:
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - run: jest --shard=${{ matrix.shard }}/4
```

### 3. Incremental Testing

Only run tests affected by changes:

```bash
# Jest: Watch mode with smart selection
jest --watch

# Jest: Only changed files
jest --onlyChanged

# pytest: Only failures
pytest --lf  # Last failed

# pytest: Only affected
pytest --affected
```

### 4. Test Database Optimization

```yaml
# Use RAM disk for test database
# PostgreSQL
postgresql:
  data_directory: /dev/shm/pgdata

# SQLite
DATABASE_URL=file:/dev/shm/test.db

# Docker tmpfs
docker run -d --tmpfs /var/lib/postgresql/data postgres
```

### 5. Lazy Loading in Tests

```javascript
// SLOW: Import everything at top
import { heavyModule } from "./heavy";
import { hugeLibrary } from "./huge";

// FAST: Dynamic import when needed
it("uses heavy module", async () => {
  const { heavyModule } = await import("./heavy");
  // ...
});
```

### 6. Factory Optimization

```ruby
# SLOW: create builds full object with database
user = create(:user, :with_posts, :with_friends)

# FAST: build creates in-memory only
user = build(:user)

# Use build_stubbed for even faster (mocked persistence)
user = build_stubbed(:user)
```

### 7. Shared Examples/Contexts

```ruby
# SLOW: Duplicate setup in each test
describe "API endpoints" do
  describe "GET /users" do
    let(:auth_token) { create_auth_token }
    before { setup_database }
    # ...
  end

  describe "POST /users" do
    let(:auth_token) { create_auth_token }  # Duplicated
    before { setup_database }  # Duplicated
    # ...
  end
end

# FAST: Shared context
shared_context "authenticated API" do
  let(:auth_token) { create_auth_token }
  before { setup_database }
end

describe "API endpoints" do
  include_context "authenticated API"

  describe "GET /users" do
    # ...
  end

  describe "POST /users" do
    # ...
  end
end
```

## CI Optimization

### Caching

```yaml
# GitHub Actions
- name: Cache node modules
  uses: actions/cache@v4
  with:
    path: node_modules
    key: npm-${{ hashFiles('package-lock.json') }}

- name: Cache Jest
  uses: actions/cache@v4
  with:
    path: .jest-cache
    key: jest-${{ hashFiles('**/*.test.js') }}
```

### Fail Fast

```yaml
# Stop on first failure (for feedback speed)
jest --bail
pytest -x
rspec --fail-fast
```

### Timing Reports

```yaml
- name: Run tests with timing
  run: |
    jest --json --outputFile=results.json
    jq '.testResults[].testResults[] | {name: .title, duration: .duration}' results.json | \
      sort -k2 -rn | head -20

- name: Upload timing report
  uses: actions/upload-artifact@v4
  with:
    name: test-timing
    path: results.json
```

## Performance Monitoring

### Track Over Time

```bash
#!/bin/bash
# track-test-time.sh

START=$(date +%s)
npm test
END=$(date +%s)
DURATION=$((END - START))

echo "$(date +%Y-%m-%d),$DURATION" >> test-times.csv
```

### Alert on Regression

```yaml
- name: Check test time regression
  run: |
    CURRENT=$(time (npm test) 2>&1 | grep real | awk '{print $2}')
    BASELINE=300  # 5 minutes

    if [ "$CURRENT" -gt "$BASELINE" ]; then
      echo "::warning::Test suite is slower than baseline: ${CURRENT}s > ${BASELINE}s"
    fi
```

### Benchmark Script

```bash
#!/bin/bash
# benchmark-tests.sh

echo "Running test performance benchmark..."
echo ""

for i in {1..5}; do
  echo "Run $i:"
  time npm test -- --silent 2>&1 | grep real
done

echo ""
echo "Average across 5 runs:"
npm test -- --silent 2>&1 | grep "Tests:"
```

## Quick Wins Checklist

- [ ] Enable parallel test execution
- [ ] Use transaction rollback instead of database reset
- [ ] Mock external HTTP calls
- [ ] Move heavy setup from beforeEach to beforeAll
- [ ] Replace sleep() with condition-based waits
- [ ] Cache test fixtures
- [ ] Use RAM disk for test database
- [ ] Split unit and integration tests
- [ ] Enable CI test sharding
- [ ] Add timing reports to CI
