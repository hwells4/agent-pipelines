# Quick Audit Checklist

Use this for rapid test file review.

## Per-Test Quick Check (30 seconds each)

### 1. Does it assert something meaningful?
- ❌ No `expect()` calls
- ❌ Only `.not.toThrow()`
- ❌ Only checks mock was called
- ✅ Verifies return value or state change

### 2. Are values explained or arbitrary?
- ❌ `expect(x).toBe("a7f2d9e1")` - magic value
- ❌ `expect(x).toBe(847.329)` - suspiciously specific
- ✅ `expect(x).toMatch(/pattern/)` - tests property
- ✅ Comment explains why this value

### 3. Is it testing one thing?
- ❌ Multiple act-assert cycles
- ❌ >5 assertions on unrelated properties
- ❌ Test name is vague ("works", "handles data")
- ✅ Single behavior with focused assertions

### 4. Are mocks realistic?
- ❌ Mock returns simpler structure than real API
- ❌ Mock never throws/rejects
- ❌ Mock method signature doesn't match real
- ✅ Mock structure matches real response

### 5. Any flakiness risks?
- ❌ `Date.now()` in assertion
- ❌ `Math.random()` without seed
- ❌ Hard-coded port numbers
- ❌ Assertion in setTimeout callback
- ✅ Deterministic or properly mocked

## Per-File Quick Check (2 minutes)

### Setup/Fixtures
- [ ] Fixtures have realistic, varied data?
- [ ] Shared setup in beforeEach, not copy-pasted?
- [ ] Mocks reset between tests?

### Coverage Shape
- [ ] Happy path tested?
- [ ] Error cases tested?
- [ ] Edge cases (null, empty, boundary) tested?

### Mock Audit
- [ ] List all mocks - do return values match real implementations?
- [ ] Are we mocking what we're testing? (The Mockery)
- [ ] Are we mocking internal methods?

## Red Flag Grep Patterns

```bash
# Find potential AI hardcoding
grep -E "toBe\(['\"][a-f0-9]{8,}['\"]" tests/
grep -E "toBe\([0-9]+\.[0-9]{4,}\)" tests/
grep -E "toEqual\(\{.*createdAt.*\}\)" tests/

# Find tests without assertions
grep -L "expect\|assert" tests/**/*.test.*

# Find time-dependent tests
grep -E "Date\.now\(\)|new Date\(\)" tests/

# Find random without mocking
grep -E "Math\.random\(\)" tests/ | grep -v "spyOn.*random"

# Find hardcoded ports
grep -E ":\d{4}" tests/ | grep -v mock
```

## Severity Classification

### Critical (Fix Immediately)
- Tests with zero assertions
- AI hardcoded values that will break on any change
- Mocks returning impossible data structures
- Tests that always pass regardless of implementation

### High (Fix Soon)
- Flaky test indicators
- Giant tests hiding failures
- Mock/reality mismatches
- Testing implementation not behavior

### Medium (Improve When Touching)
- Minimal fixtures
- Vague test names
- Over-mocking
- Missing edge cases

### Low (Nice to Have)
- Style inconsistencies
- Duplicated setup that could be shared
- Suboptimal organization

## Quick Decision Tree

```
Does the test have assertions?
├─ No → CRITICAL: The Liar
└─ Yes → Are assertions on deterministic values?
         ├─ No (timestamps, hashes, etc.) → Check if mocked
         │  ├─ Not mocked → CRITICAL: AI Hardcoding
         │  └─ Mocked → OK
         └─ Yes → Is it testing one behavior?
                  ├─ No (>5 assertions, multiple acts) → HIGH: The Giant
                  └─ Yes → Are mocks realistic?
                           ├─ No → HIGH: Mock Mismatch
                           └─ Yes → Probably OK ✅
```
