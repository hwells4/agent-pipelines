# Test Health Metrics Guide

Detailed guidance on collecting, interpreting, and acting on test health metrics.

## Core Metrics

### 1. Pass Rate

**What it measures:** Percentage of tests passing on each run.

**Collection:**
```bash
# Jest
jest --json 2>/dev/null | jq '.numPassedTests / .numTotalTests * 100'

# pytest
pytest --tb=no -q 2>&1 | tail -1  # Shows "X passed, Y failed"

# RSpec
rspec --format progress 2>&1 | grep -E "^\d+ examples"
```

**Interpretation:**
| Rate | Status | Action |
|------|--------|--------|
| >99% | Healthy | Maintain |
| 95-99% | Warning | Investigate failures |
| <95% | Critical | Stop and fix |

**Red flags:**
- Sudden drops (>5% change) = likely infrastructure issue or breaking change
- Gradual decline = accumulating test debt
- Inconsistent rate = flaky tests masking real failures

### 2. Flakiness Rate

**What it measures:** Percentage of tests that fail intermittently.

**Collection:**
```bash
# Track over multiple runs
# Flaky = passed on retry OR inconsistent across runs

# With jest-circus (enables retries)
jest --retries=2 --json | jq '.numPassedTestSuites'

# Historical tracking (requires CI logs)
# Count: tests that failed then passed on same commit
```

**Calculation:**
```
Flakiness Rate = (Tests that passed on retry) / (Total test failures) * 100
```

**Interpretation:**
| Rate | Status | Action |
|------|--------|--------|
| <1% | Healthy | Monitor |
| 1-5% | Warning | Quarantine worst offenders |
| >5% | Critical | Dedicated flakiness sprint |

**Impact of flakiness:**
- 5% flaky rate with 1000 tests = 50 false failures per run
- Developers learn to ignore failures = real bugs slip through
- CI becomes untrusted = manual verification replaces automation

### 3. Execution Time

**What it measures:** How long tests take to run.

**Collection:**
```bash
# Total suite time
time npm test

# Per-test breakdown (Jest)
jest --verbose 2>&1 | grep -E "^\s+✓|✕" | \
  sed 's/.*(\([0-9]*\) ms).*/\1/' | sort -rn | head -20

# Per-test breakdown (pytest)
pytest --durations=0

# Per-test breakdown (RSpec)
rspec --profile 50
```

**Interpretation:**
| Suite Type | Target | Investigate |
|------------|--------|-------------|
| Unit tests | <5 min | >10 min |
| Integration | <15 min | >30 min |
| Full suite | <30 min | >60 min |

**Time inflation causes:**
- Real I/O instead of mocks
- Database setup per test
- Network calls
- Sleep statements
- Inefficient test isolation

### 4. Test-to-Code Ratio

**What it measures:** Lines of test code relative to source code.

**Collection:**
```bash
# Lines of test code
TEST_LINES=$(find tests -name "*.test.*" -o -name "*_test.*" | xargs wc -l | tail -1 | awk '{print $1}')

# Lines of source code
SRC_LINES=$(find src -name "*.ts" -o -name "*.js" -o -name "*.py" | xargs wc -l | tail -1 | awk '{print $1}')

echo "Ratio: $(echo "scale=2; $TEST_LINES / $SRC_LINES" | bc):1"
```

**Interpretation:**
| Ratio | Status | Notes |
|-------|--------|-------|
| 0.8-1.4:1 | Healthy | Balanced coverage |
| 0.5-0.8:1 | Low | May lack edge case coverage |
| <0.5:1 | Critical | Significant gaps likely |
| >2:1 | High | Review for over-testing |

**Context matters:**
- Critical paths (auth, payment) should be higher
- Simple CRUD might be lower
- Framework code (routing) needs less testing

### 5. Skip/Disabled Rate

**What it measures:** Percentage of tests not running.

**Collection:**
```bash
# Find skipped tests
grep -rcE "\.skip|xit|xdescribe|@Disabled|@pytest.mark.skip" tests/ | \
  awk -F: '{sum+=$2} END {print "Skipped:", sum}'

# Total test count
grep -rcE "it\(|test\(|def test_|@Test" tests/ | \
  awk -F: '{sum+=$2} END {print "Total:", sum}'
```

**Interpretation:**
| Rate | Status | Action |
|------|--------|--------|
| 0% | Ideal | All tests running |
| <1% | Acceptable | Track and fix |
| 1-5% | Warning | Review each skip |
| >5% | Critical | Audit required |

**Common skip reasons:**
- Flaky (should be quarantined with deadline)
- Feature incomplete (should be in separate branch)
- Environment-specific (should use skip conditions)
- Unknown (DELETE IT)

### 6. Coverage Metrics

**What it measures:** Code exercised by tests.

**Types:**
| Type | What It Measures | Target |
|------|------------------|--------|
| Line coverage | Lines executed | 80% |
| Branch coverage | Decision paths taken | 70% |
| Function coverage | Functions called | 90% |
| Mutation score | Bugs tests would catch | 75% |

**Collection:**
```bash
# Jest
jest --coverage --coverageReporters=text-summary

# pytest
pytest --cov=src --cov-report=term-missing

# Go
go test -cover ./...

# Mutation score (Stryker for JS)
npx stryker run
```

**Coverage traps:**
- 100% line coverage ≠ bug-free code
- Coverage without assertions = false confidence
- Mutation score is better quality indicator
- Focus on critical paths, not vanity numbers

## Derived Metrics

### Health Score

Combine metrics into single score:

```javascript
function calculateHealthScore(metrics) {
  const weights = {
    passRate: 0.30,
    flakiness: 0.25,
    coverage: 0.20,
    executionTime: 0.15,
    skipRate: 0.10
  };

  const scores = {
    passRate: metrics.passRate / 100,
    flakiness: 1 - (metrics.flakiness / 10),  // Invert, cap at 10%
    coverage: metrics.coverage / 100,
    executionTime: Math.max(0, 1 - (metrics.executionTime / 60)),  // Minutes, target 30
    skipRate: 1 - (metrics.skipRate / 10)  // Invert, cap at 10%
  };

  return Object.keys(weights).reduce(
    (sum, key) => sum + (weights[key] * Math.max(0, scores[key])),
    0
  ) * 100;
}

// Score interpretation:
// 90-100: Excellent
// 75-89: Good
// 60-74: Needs attention
// <60: Critical
```

### Velocity Impact

Track how test health affects development:

```
Time to PR merge (with healthy tests) vs (with flaky tests)
CI runs per PR (should be ~1-2, high = flaky tests)
Developer hours lost to false failures per week
```

## Trend Analysis

### What to Track Over Time

```markdown
## Weekly Metrics Log

| Week | Pass Rate | Flaky % | Time (m) | Coverage | Skipped |
|------|-----------|---------|----------|----------|---------|
| W1   | 99.2%     | 0.8%    | 12       | 82%      | 3       |
| W2   | 98.8%     | 1.2%    | 14       | 81%      | 5       |
| W3   | 97.5%     | 2.1%    | 18       | 80%      | 8       |

Trend: ⚠️ All metrics degrading. Investigation needed.
```

### Detecting Degradation

Early warning signs:
1. **Pass rate drops 2+ points** → Check recent merges
2. **Flakiness increases steadily** → Time for quarantine pass
3. **Execution time jumps 20%+** → Audit new tests for efficiency
4. **Coverage drops without refactoring** → Tests being deleted?
5. **Skip count rising** → Engineers avoiding rather than fixing

### Automated Alerts

Set up CI to alert on thresholds:

```yaml
# GitHub Actions example
- name: Check test health
  run: |
    PASS_RATE=$(npm test -- --json | jq '.numPassedTests / .numTotalTests * 100')
    if (( $(echo "$PASS_RATE < 95" | bc -l) )); then
      echo "::error::Pass rate below 95%: $PASS_RATE%"
      exit 1
    fi
```

## Metric Collection Automation

### Daily Dashboard Script

```bash
#!/bin/bash
# collect-metrics.sh

echo "=== Test Health Dashboard $(date +%Y-%m-%d) ==="

# Run tests and capture output
npm test -- --json > test-results.json 2>/dev/null

# Extract metrics
TOTAL=$(jq '.numTotalTests' test-results.json)
PASSED=$(jq '.numPassedTests' test-results.json)
FAILED=$(jq '.numFailedTests' test-results.json)
TIME=$(jq '.testResults[].perfStats.runtime' test-results.json | awk '{sum+=$1} END {print sum/1000}')

PASS_RATE=$(echo "scale=2; $PASSED / $TOTAL * 100" | bc)
SKIP_COUNT=$(grep -rc "\.skip\|xit" tests/ | awk -F: '{sum+=$2} END {print sum}')

echo "Pass Rate: ${PASS_RATE}%"
echo "Failed: $FAILED"
echo "Skipped: $SKIP_COUNT"
echo "Time: ${TIME}s"

# Append to log
echo "$(date +%Y-%m-%d),$PASS_RATE,$FAILED,$SKIP_COUNT,$TIME" >> metrics-log.csv
```

### Integration with CI

Store metrics as artifacts:

```yaml
- name: Collect test metrics
  run: ./collect-metrics.sh

- name: Upload metrics
  uses: actions/upload-artifact@v4
  with:
    name: test-metrics
    path: metrics-log.csv
```

## Acting on Metrics

### Triage Priority

When metrics are unhealthy, address in order:

1. **Pass rate <95%** → Fix failing tests (blocks everything)
2. **Flakiness >5%** → Quarantine and fix (erodes trust)
3. **Skip rate >5%** → Delete or fix skipped tests (hidden debt)
4. **Time >30min** → Optimize or parallelize (slows development)
5. **Coverage <60%** → Add tests for critical paths (risk)

### Weekly Review Template

```markdown
## Test Health Review - Week of YYYY-MM-DD

### Metrics Summary
- Pass Rate: XX% (target: >99%)
- Flakiness: X% (target: <1%)
- Execution: Xm (target: <30m)
- Coverage: XX% (target: >80%)
- Skipped: X (target: 0)

### Trend
- [ ] Improving
- [ ] Stable
- [ ] Degrading ← ACTION REQUIRED

### This Week's Actions
1. [ ] Action item 1
2. [ ] Action item 2

### Blockers
- None / List issues
```
