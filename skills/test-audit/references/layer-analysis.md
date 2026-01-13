# Test Layer Gap Analysis

How to detect and fix mismatches between unit tests, integration tests, and system tests.

## The Core Problem

```
Unit Tests: ✅ All pass
Integration Tests: ❌ Missing or insufficient
System: 💥 Broken in production

How? Each piece works alone, but they're never verified to work together.
```

## Test Layer Responsibilities

| Layer | What It Tests | What It Catches |
|-------|--------------|-----------------|
| **Unit** | Individual functions/classes | Logic errors, edge cases |
| **Integration** | Components working together | Wiring errors, interface mismatches |
| **Contract** | API boundaries | Schema changes, response format changes |
| **E2E** | Complete user flows | Full-stack regressions |

## Healthy Layer Distribution

### The Testing Pyramid (Traditional)

```
        /\
       /  \      E2E: 5% (critical paths only)
      /----\
     /      \    Integration: 15% (key integrations)
    /--------\
   /          \  Unit: 80% (comprehensive)
  /____________\
```

### Warning Signs

**Too Unit-Heavy (>95% unit):**
- Fast tests, false confidence
- "Works on my machine" syndrome
- Integration bugs found in production

**Too Integration-Heavy (>50% integration):**
- Slow test suite
- Hard to diagnose failures
- Edge cases untested

**No Integration Tests:**
- CRITICAL gap
- Units may never be wired together
- Interface drift goes unnoticed

## Detection Techniques

### 1. Test File Inventory

```bash
# Count tests by type
echo "Unit tests:"
find tests/unit -name "*.test.*" 2>/dev/null | wc -l

echo "Integration tests:"
find tests/integration -name "*.test.*" 2>/dev/null | wc -l

echo "E2E tests:"
find tests/e2e -name "*.test.*" 2>/dev/null | wc -l

# Or by naming convention
echo "*.unit.test.* files:"
find tests -name "*.unit.test.*" | wc -l

echo "*.integration.test.* files:"
find tests -name "*.integration.test.*" | wc -l
```

### 2. Entry Point Coverage Check

List all entry points, verify each has integration coverage:

```bash
# API endpoints (Express/Fastify)
grep -r "app\.\(get\|post\|put\|delete\|patch\)" src/routes/

# CLI commands
grep -r "\.command(" src/cli/

# Event handlers
grep -r "\.on(" src/handlers/

# For each: does a corresponding integration test exist?
```

### 3. Mock Dependency Analysis

```bash
# Find all mocks in unit tests
grep -rh "jest\.mock\|vi\.mock\|Mock\|stub\|fake" tests/unit/ | sort | uniq

# For each mocked dependency:
# 1. Is it a critical path? (auth, payment, data persistence)
# 2. Is there an integration test using the real implementation?
```

### 4. Call Graph Analysis

Trace from entry points to verify test coverage:

```
POST /api/users (entry point)
    → UsersController.create()      [integration test?]
        → UserService.createUser()  [unit test?]
            → UserRepository.save() [unit test?]
            → EmailService.send()   [unit test?]
        → AuditLog.record()         [unit test?]
```

Questions to ask:
- Is Controller → Service call tested? (not just mocked)
- Is Service → Repository call tested?
- Are side effects (email, audit) verified to trigger?

### 5. Execution Time Analysis

```bash
# If unit tests take longer than expected, might be doing integration work
time npm run test:unit   # Should be < 30 seconds

# If integration tests are fast, might not be testing real integrations
time npm run test:integration  # Should take 1-5 minutes
```

## Common Gap Patterns

### Gap 1: Orphan Functions

Function is tested in isolation but never actually used.

**Detection:**
```bash
# Find function definitions
grep -rn "export function\|export const.*=" src/

# Find function usage in source (not tests)
grep -rn "functionName" src/ | grep -v test

# If function appears in tests but not in source usage → orphan
```

**Example:**
```javascript
// src/utils/validate.ts
export function validateEmail(email: string): boolean { ... }

// tests/utils/validate.test.ts
it("validates email", () => {
  expect(validateEmail("test@example.com")).toBe(true);
});

// BUT: search reveals validateEmail is never imported/called anywhere else!
// The actual code uses a different validator.
```

### Gap 2: Mock-Reality Drift

Mock returns data that real implementation no longer returns.

**Detection:**
1. Find mock definitions
2. Compare to actual implementation or API documentation
3. Check git history for changes to real implementation after mock was created

**Example:**
```javascript
// Mock (written 6 months ago):
mockUserApi.getUser.mockResolvedValue({
  id: "123",
  name: "Test User"
});

// Real API (updated 2 months ago):
// GET /users/123 returns:
{
  data: {
    user: {
      id: "123",
      displayName: "Test User",  // field renamed!
      email: "test@example.com"  // new field!
    }
  }
}
```

### Gap 3: Partial Path Testing

Only part of the call chain is tested.

**Detection:**
```javascript
// Test for Service exists:
describe("UserService", () => {
  it("creates user", () => {
    mockRepo.save.mockResolvedValue({ id: "1" });
    const user = await userService.create(data);
    expect(user.id).toBe("1");
  });
});

// Test for Repository exists:
describe("UserRepository", () => {
  it("saves to database", async () => {
    const result = await repo.save({ name: "Test" });
    expect(result.id).toBeDefined();
  });
});

// BUT: No test verifies Service actually calls Repository correctly!
// Service test mocks Repository, Repository test is isolated.
// Real integration could fail at the boundary.
```

### Gap 4: Happy Path Only Integration

Integration tests exist but only cover the success case.

**Detection:**
```javascript
// Integration test:
it("creates user successfully", async () => {
  const response = await request(app)
    .post("/users")
    .send({ email: "test@example.com" });
  expect(response.status).toBe(201);
});

// Missing:
// - What if email already exists?
// - What if database is down?
// - What if validation fails?
// - What if email service fails?
```

## Remediation Strategies

### For "Green Units, Dead System"

1. **Identify critical paths:**
   - User registration → confirmation email
   - Order placement → payment → inventory update
   - Login → session creation → auth middleware

2. **Add integration tests for each critical path:**
   ```javascript
   describe("User Registration Flow", () => {
     it("creates user and sends confirmation email", async () => {
       // Use real services, mock only external APIs
       const emailSpy = jest.spyOn(realEmailService, "send");

       const response = await request(app)
         .post("/register")
         .send({ email: "new@example.com", password: "secure123" });

       expect(response.status).toBe(201);
       expect(emailSpy).toHaveBeenCalledWith(
         expect.objectContaining({ to: "new@example.com" })
       );
     });
   });
   ```

3. **Verify wiring with contract tests:**
   ```javascript
   describe("UserService → UserRepository Contract", () => {
     it("calls repository with correct shape", async () => {
       const repoSpy = jest.spyOn(realRepository, "save");

       await userService.create({ email: "test@example.com" });

       expect(repoSpy).toHaveBeenCalledWith(
         expect.objectContaining({
           email: "test@example.com",
           createdAt: expect.any(Date)
         })
       );
     });
   });
   ```

### For "Integration Without Units"

1. **Extract testable units:**
   - If a function is only tested via integration, add unit tests
   - Focus on edge cases that are hard to trigger end-to-end

2. **Add unit tests for:**
   - Validation logic
   - Transformation logic
   - Business rules
   - Error handling branches

### For "Orphan Functions"

1. **Decide: delete or integrate**
   - If function isn't used, delete it and its tests
   - If function should be used, find where and wire it in

2. **Add tracing to confirm usage:**
   ```javascript
   // Temporarily add logging to verify function is called
   export function validateEmail(email: string): boolean {
     console.log("validateEmail called with:", email);  // Remove after verification
     return EMAIL_REGEX.test(email);
   }
   ```

## Audit Checklist

### Layer Coverage

- [ ] Unit tests exist for business logic?
- [ ] Integration tests exist for critical paths?
- [ ] E2E tests exist for key user flows?
- [ ] Contract tests exist for external API boundaries?

### Path Coverage

- [ ] Every API endpoint has at least one integration test?
- [ ] Every CLI command has at least one E2E test?
- [ ] Every event handler has at least one integration test?

### Mock Audit

- [ ] List all mocked dependencies
- [ ] For each mock: real integration test exists?
- [ ] For critical mocks: return values match reality?

### Orphan Detection

- [ ] All tested functions are actually used in production code?
- [ ] No dead code being maintained via tests?
