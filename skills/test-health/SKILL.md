---
name: test-health
description: Monitor ongoing test suite health, track metrics, identify degradation, and make maintenance decisions. Use for periodic health checks, before releases, when CI is slow, or when deciding which tests to fix/delete/quarantine.
---

## What This Skill Does

Provides ongoing monitoring and maintenance guidance for test suites:

1. **Health Metrics** - Track key indicators of suite health over time
2. **Flakiness Management** - Detect, quarantine, and fix flaky tests
3. **Performance Monitoring** - Identify slow tests and optimization opportunities
4. **Maintenance Decisions** - When to fix, delete, or quarantine tests
5. **Trend Analysis** - Spot degradation before it becomes critical
6. **Coverage Quality** - Beyond line coverage to mutation score

This is NOT a one-time audit. It's ongoing health monitoring.

## When to Use

- **Weekly/Sprint health check** - Regular monitoring
- **Before major releases** - Ensure suite is trustworthy
- **When CI is slow** - Find performance bottlenecks
- **When flakiness increases** - Diagnose and address
- **Deciding test fate** - Fix it, delete it, or quarantine it?
- **After refactoring** - Verify tests still provide value

## Key Health Metrics

### The Vital Signs Dashboard

Track these metrics over time:

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| **Pass Rate** | >99% | 95-99% | <95% |
| **Flakiness Rate** | <1% | 1-5% | >5% |
| **Unit Test Time** | <5 min | 5-15 min | >15 min |
| **Full Suite Time** | <30 min | 30-60 min | >60 min |
| **Coverage** | >80% | 60-80% | <60% |
| **Mutation Score** | >75% | 50-75% | <50% |
| **Skipped Tests** | <1% | 1-5% | >5% |
| **Test-to-Code Ratio** | 0.8-1.4:1 | 0.5-0.8:1 | <0.5:1 |

### Metric Collection Commands

```bash
# Pass rate (from CI logs or test output)
# Track: passed / total over last N runs

# Flakiness rate
# Track: (tests that passed on retry) / total failures

# Execution time
time npm test
time npm run test:unit
time npm run test:integration

# Coverage
npm test -- --coverage
pytest --cov=src --cov-report=term

# Test counts
find tests -name "*.test.*" | wc -l
grep -rc "\.skip\|xit\|xdescribe\|@Disabled" tests/ | awk -F: '{sum+=$2} END {print sum}'

# Test-to-code ratio
echo "Test lines: $(find tests -name '*.test.*' -exec cat {} + | wc -l)"
echo "Source lines: $(find src -name '*.ts' -o -name '*.js' | xargs cat | wc -l)"
```

## Flakiness Management

### Detection Strategies

**1. Retry Analysis**
```bash
# If your CI retries failures, track:
# - Tests that fail then pass on retry = flaky
# - Calculate: flaky_runs / total_runs
```

**2. Historical Pattern Matching**
```bash
# Find tests with inconsistent results
# Look for: PASS, FAIL, PASS, PASS, FAIL pattern
# These are flaky even if they pass most of the time
```

**3. Multiple Execution**
```bash
# Run suspicious tests multiple times
jest --testNamePattern="flaky test name" --repeat=10
pytest tests/suspect_test.py --count=10
```

### Flakiness Root Causes

| Cause | Symptoms | Fix |
|-------|----------|-----|
| **Timing/Race** | Passes locally, fails in CI | Proper async waits |
| **Shared State** | Fails when run with other tests | Isolation, cleanup |
| **Time-Dependent** | Fails at certain times | Mock time |
| **Random Data** | Intermittent failures | Seed random |
| **Network** | Fails sporadically | Mock external calls |
| **Resource** | Fails under load | Resource limits |

### Quarantine Process

When a test is identified as flaky:

```
1. TAG it as flaky
   // @flaky - JIRA-123
   it.skip("flaky test", ...)

2. REMOVE from blocking CI
   - Move to separate job that doesn't block merge
   - Or exclude with tag: jest --testPathIgnorePatterns="flaky"

3. TRACK in issue system
   - Create ticket with reproduction steps
   - Link to CI failure logs
   - Set SLA for fix (e.g., 2 weeks)

4. FIX or DELETE
   - If not fixed within SLA, delete
   - Flaky tests providing zero value are worse than no test

5. RESTORE after validation
   - Run fixed test 10+ times
   - Monitor for 1 week
   - Then restore to blocking CI
```

### Quarantine Tracking Template

```markdown
## Quarantined Tests

| Test | Quarantined | Reason | Ticket | SLA |
|------|-------------|--------|--------|-----|
| test_user_flow | 2025-01-10 | Race condition | JIRA-123 | 2025-01-24 |
| test_payment | 2025-01-08 | External API | JIRA-120 | 2025-01-22 |

## Rules
- Max 2 weeks in quarantine
- If not fixed by SLA: DELETE
- Track total quarantine count (should decrease over time)
```

## Performance Monitoring

### Identifying Slow Tests

```bash
# Jest: Show slowest tests
jest --verbose 2>&1 | grep -E "^\s+✓|✕" | sort -t'(' -k2 -rn | head -20

# pytest: Show durations
pytest --durations=20

# RSpec: Profile mode
rspec --profile 20
```

### Performance Targets

| Test Type | Target | Investigate If |
|-----------|--------|----------------|
| Single unit test | <100ms | >500ms |
| Unit test file | <5s | >15s |
| All unit tests | <5 min | >10 min |
| Integration test | <30s | >2 min |
| All integration | <15 min | >30 min |
| E2E test | <5 min | >10 min |
| Full suite | <30 min | >1 hour |

### Common Performance Issues

**1. Database Setup/Teardown**
```javascript
// SLOW: Creating database per test
beforeEach(async () => {
  await createDatabase();
  await runMigrations();
});

// FAST: Use transactions
beforeEach(async () => {
  await db.beginTransaction();
});
afterEach(async () => {
  await db.rollback();
});
```

**2. Unnecessary Mocking Overhead**
```javascript
// SLOW: Re-mocking in every test
it("test 1", () => {
  jest.mock("heavy-module");
  // ...
});

// FAST: Mock once at file level
jest.mock("heavy-module");
```

**3. Serial When Could Be Parallel**
```bash
# SLOW: Sequential
npm test

# FAST: Parallel
npm test -- --maxWorkers=4
pytest -n auto
```

**4. Integration Tests Doing Unit Test Work**
```javascript
// SLOW: Full stack for simple logic
it("validates email", async () => {
  const response = await request(app).post("/validate-email");
  // ...
});

// FAST: Unit test the function
it("validates email", () => {
  expect(validateEmail("test@example.com")).toBe(true);
});
```

## Maintenance Decisions

### Decision Tree: Fix, Delete, or Quarantine?

```
Test is failing or flaky
          │
          ▼
    Is it catching real bugs?
          │
    ┌─────┴─────┐
    │ Yes       │ No
    │           │
    ▼           ▼
  FIX IT    Is the feature still needed?
              │
        ┌─────┴─────┐
        │ Yes       │ No
        │           │
        ▼           ▼
    REWRITE     DELETE IT
    (test is testing
    wrong thing)
```

### When to DELETE Tests

Delete without guilt when:

1. **Feature removed** - Test validates behavior that no longer exists
2. **Chronic flakiness** - Test has been flaky for >2 weeks with no fix
3. **Nobody understands it** - Test intent is unclear and undocumented
4. **Duplicate coverage** - Same behavior tested elsewhere
5. **Implementation-coupled** - Test breaks on every refactor without catching bugs
6. **Always passes** - Test cannot fail regardless of code changes

**Before deleting, verify:**
```bash
# Check if test ever fails meaningfully
git log --oneline -p -- path/to/test.js | grep -A5 "expect\|assert"

# Check last modification date
git log -1 --format="%ai" -- path/to/test.js

# Check if deleting breaks coverage significantly
npm test -- --coverage --collectCoverageFrom="src/related-file.js"
```

### When to REWRITE Tests

Rewrite (not just fix) when:

1. **Tests implementation not behavior** - Mocks internal methods extensively
2. **Too tightly coupled** - Breaks on unrelated changes
3. **Wrong abstraction level** - Unit test doing integration work or vice versa
4. **Unreadable** - Intent unclear, complex setup

### When to QUARANTINE Tests

Quarantine (temporarily disable) when:

1. **Blocking releases** - Flaky test preventing deploy
2. **Needs investigation** - Root cause unclear
3. **External dependency issue** - Third-party service problem

**Rules:**
- Set explicit SLA (max 2 weeks)
- Track in issue system
- Delete if not fixed by SLA

## Coverage Quality

### Beyond Line Coverage

**Line coverage tells you:** What code was executed
**Line coverage doesn't tell you:** If tests actually verify behavior

### Mutation Testing

Mutation testing introduces bugs and checks if tests catch them:

```bash
# JavaScript (Stryker)
npx stryker run

# Python (mutmut)
mutmut run

# Java (PIT)
mvn org.pitest:pitest-maven:mutationCoverage
```

**Interpreting mutation scores:**
- **Killed mutant:** Test caught the bug (good)
- **Survived mutant:** Test missed the bug (bad)
- **No coverage:** Code not tested at all

**Target scores:**
| Score | Quality |
|-------|---------|
| >80% | Excellent |
| 60-80% | Good |
| 40-60% | Needs work |
| <40% | Poor |

### Coverage vs Mutation Example

```javascript
// Source code
function isAdult(age) {
  return age >= 18;
}

// Test with 100% line coverage
it("returns true for adult", () => {
  expect(isAdult(25)).toBe(true);
});

// Mutation: age >= 18 → age > 18
// Test still passes! (25 > 18 is true)
// Mutation SURVIVES = weak test

// Better test (catches mutation)
it("returns true for exactly 18", () => {
  expect(isAdult(18)).toBe(true);
});
it("returns false for 17", () => {
  expect(isAdult(17)).toBe(false);
});
```

## Health Check Process

### Quick Check (5 minutes)

```bash
# 1. Run tests, note time
time npm test

# 2. Check for failures/skips
npm test 2>&1 | grep -E "fail|skip|pending"

# 3. Quick coverage
npm test -- --coverage --coverageReporters=text-summary

# 4. Count skipped tests
grep -rc "\.skip\|xit" tests/ | awk -F: '{sum+=$2} END {print "Skipped:", sum}'
```

### Weekly Health Report

Generate and review:

```markdown
# Test Health Report - Week of YYYY-MM-DD

## Summary
- Pass Rate: XX% (target: >99%)
- Flakiness: X% (target: <1%)
- Execution Time: Xm Xs (target: <30m)
- Coverage: XX% (target: >80%)
- Skipped Tests: X (target: 0)

## Trends
- Pass rate: ↑/↓/→ vs last week
- Execution time: ↑/↓/→ vs last week
- Coverage: ↑/↓/→ vs last week

## Action Items
1. [ ] Fix flaky test: test_xxx (flaky 3x this week)
2. [ ] Investigate slow test: test_yyy (>30s)
3. [ ] Delete or fix skipped: test_zzz (skipped 4 weeks)

## Quarantine Status
- In quarantine: X tests
- Fixed this week: X tests
- Deleted this week: X tests
```

### Monthly Deep Dive

Once per month:
1. Run mutation testing on critical paths
2. Review all quarantined tests (delete if stale)
3. Analyze test-to-code ratio trends
4. Review CI execution time trends
5. Identify candidates for deletion

## Success Criteria

- [ ] Key metrics collected and baselined
- [ ] Flakiness rate calculated and tracked
- [ ] Slow tests identified and prioritized
- [ ] Quarantine process established
- [ ] Delete/fix/rewrite decisions documented
- [ ] Coverage quality assessed (not just line coverage)
- [ ] Health report generated
- [ ] Action items prioritized

## References

- `references/metrics.md` - Detailed metric collection and interpretation
- `references/flakiness.md` - Flaky test diagnosis and fixes
- `references/performance.md` - Test performance optimization
