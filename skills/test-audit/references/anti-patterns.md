# Test Anti-Patterns Detection Guide

Detailed heuristics for identifying problematic tests.

## AI Hardcoding Detection

### Heuristic 1: Suspicious Exact Values

Look for assertions on values that seem arbitrary:

```javascript
// SUSPICIOUS: Hash/UUID/token exact matches
expect(hash).toBe("e3b0c44298fc1c149afbf4c8996fb92");
expect(id).toBe("550e8400-e29b-41d4-a716-446655440000");
expect(token).toBe("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");

// SUSPICIOUS: Timestamps
expect(createdAt).toBe("2024-01-13T10:30:45.123Z");
expect(timestamp).toBe(1705142445123);

// SUSPICIOUS: Computed numbers with many decimals
expect(result).toBe(3.141592653589793);
expect(score).toBe(847.3291028374);

// SUSPICIOUS: Long strings that look generated
expect(output).toBe("The user John with ID 123 was created at...");
```

### Heuristic 2: Snapshot of Non-Deterministic Output

```javascript
// SUSPICIOUS: Snapshot of something that shouldn't be stable
expect(generateReport()).toMatchSnapshot();
expect(hashPassword("test")).toMatchSnapshot();
expect(createOrder()).toMatchSnapshot(); // Has timestamps, IDs
```

### Heuristic 3: Copy-Paste from Console

Tests where the expected value looks like it was copied from running the code once:

```javascript
// SUSPICIOUS: Error message exact match
expect(error.message).toBe(
  "ValidationError: \"email\" must be a valid email. \"name\" is required. \"age\" must be greater than 0."
);
// This was probably copied from console output
```

### How to Verify

1. Run the function multiple times - does the value change?
2. Is the value deterministic given the inputs?
3. Would changing implementation details change this value?
4. Does the test document WHY this value is expected?

## Mock/Reality Mismatch Detection

### Heuristic 1: Structure Mismatch

```javascript
// Source code expects:
const response = await api.getUser(id);
const name = response.data.user.name;

// But mock returns:
mockApi.getUser.mockResolvedValue({ name: "Test" });
// Missing: data.user wrapper!
```

**Detection:** Search for mock definitions, then trace how the return value is used in source code.

### Heuristic 2: Missing Error Cases

```javascript
// Mock only handles success:
mockDb.query.mockResolvedValue([{ id: 1 }]);

// But source code has error handling:
try {
  const result = await db.query(sql);
} catch (error) {
  if (error.code === "ECONNREFUSED") { ... }
  if (error.code === "ETIMEOUT") { ... }
}
```

**Detection:** Check if source has try/catch or .catch() but mocks never reject.

### Heuristic 3: Method Signature Mismatch

```javascript
// Real implementation:
class UserService {
  async findById(id: string, options?: { includeDeleted: boolean }): Promise<User | null>
}

// Mock:
mockUserService.findById.mockResolvedValue({ id: "1", name: "Test" });
// Never returns null! Never tests options parameter!
```

**Detection:** Compare mock calls to actual method signatures in source.

### Heuristic 4: Outdated Mocks

After refactoring, mocks may return old data structures:

```javascript
// API v1 returned:
{ user: { name: "Test" } }

// API v2 returns:
{ user: { firstName: "Test", lastName: "" } }

// Mock still uses v1 format - tests pass but real code fails
```

**Detection:** Check if mocks were updated when source was last modified.

## The Liar Detection

### Heuristic 1: No Assertions

```javascript
// Zero expect() calls
it("processes payment", async () => {
  await paymentService.process(order);
});
```

**Detection:** Count `expect()` or `assert` calls. Zero = The Liar.

### Heuristic 2: Only Negative Assertions

```javascript
it("handles data", () => {
  expect(() => handleData(input)).not.toThrow();
});
// Doesn't verify what handleData actually DID
```

**Detection:** Check if all assertions are `.not.toThrow()` without positive assertions.

### Heuristic 3: Asserting on Mock, Not Result

```javascript
it("fetches user", async () => {
  await userService.getUser("123");
  expect(mockApi.get).toHaveBeenCalledWith("/users/123");
  // Never checks what getUser RETURNED or DID with the data
});
```

**Detection:** Test has `toHaveBeenCalled` but no assertions on return value or side effects.

### Heuristic 4: Tautological Assertions

```javascript
it("returns data", () => {
  const data = { foo: "bar" };
  const result = identity(data);
  expect(result).toEqual(data); // Testing that identity returns identity?
});

it("creates instance", () => {
  const obj = new MyClass();
  expect(obj).toBeInstanceOf(MyClass); // Tautology
});
```

## The Giant Detection

### Heuristic 1: High Assertion Count

More than 5-7 assertions in a single test is a smell.

```javascript
it("user workflow", () => {
  expect(user.id).toBeDefined();
  expect(user.name).toBe("Test");
  expect(user.email).toMatch(/@/);
  expect(user.role).toBe("member");
  expect(user.createdAt).toBeDefined();
  expect(user.updatedAt).toBeNull();
  expect(service.count()).toBe(1);
  expect(service.findById(user.id)).toBeTruthy();
  // ... more assertions
});
```

### Heuristic 2: Multiple Act Phases

```javascript
it("user lifecycle", () => {
  // ACT 1
  const user = service.create({ name: "Test" });
  expect(user.id).toBeDefined();

  // ACT 2
  service.update(user.id, { name: "Updated" });
  expect(service.findById(user.id).name).toBe("Updated");

  // ACT 3
  service.delete(user.id);
  expect(service.findById(user.id)).toBeNull();
});
```

**Detection:** Multiple distinct operations being tested. Should be separate tests.

### Heuristic 3: Test Name is Vague

```javascript
it("works")
it("user service")
it("handles everything correctly")
it("full flow")
```

**Detection:** Test name doesn't describe a specific behavior.

## The Mockery Detection

### Heuristic 1: Mocking the Subject

```javascript
jest.mock("./calculator");
import { Calculator } from "./calculator";

it("adds numbers", () => {
  Calculator.add.mockReturnValue(5);
  expect(Calculator.add(2, 3)).toBe(5);
});
// We're testing our mock, not Calculator!
```

**Detection:** `jest.mock()` path matches the import being tested.

### Heuristic 2: Mocking Internals

```javascript
it("processes order", () => {
  jest.spyOn(orderService, "_validateItems").mockReturnValue(true);
  jest.spyOn(orderService, "_calculateTotal").mockReturnValue(100);
  jest.spyOn(orderService, "_applyDiscount").mockReturnValue(90);

  const result = orderService.process(order);
  expect(result.total).toBe(90);
});
// We're not testing process(), we're testing that it calls helpers
```

**Detection:** Mocking private methods (underscore prefix) or multiple internal methods.

### Heuristic 3: Mock Count > Assertion Count

```javascript
it("does something", () => {
  mockA.mockReturnValue(1);
  mockB.mockReturnValue(2);
  mockC.mockReturnValue(3);
  mockD.mockReturnValue(4);
  mockE.mockReturnValue(5);

  const result = doSomething();
  expect(result).toBe(15);
});
// 5 mocks, 1 assertion = suspicious
```

## Fixture Problems Detection

### Heuristic 1: Minimal Objects

```javascript
const user = { name: "Test" };
// Real User has: id, email, role, createdAt, updatedAt, ...
```

**Detection:** Compare fixture properties to actual type/interface definition.

### Heuristic 2: No Variation

```javascript
const users = [
  { id: "1", name: "Test", role: "user" },
  { id: "2", name: "Test", role: "user" },
  { id: "3", name: "Test", role: "user" },
];
// All identical except ID - no edge cases
```

**Detection:** Fixtures with same values in all records.

### Heuristic 3: Magic Numbers Without Context

```javascript
const config = {
  maxRetries: 3,
  timeout: 5000,
  threshold: 0.75,
  factor: 2.5,
};
// Why these values? What do they test?
```

**Detection:** Numeric literals without comments or semantic variable names.

## Flaky Test Detection

### Heuristic 1: Date.now() or new Date()

```javascript
expect(result.timestamp).toBe(Date.now());
expect(record.createdAt).toEqual(new Date());
```

**Detection:** Grep for `Date.now()`, `new Date()`, `moment()` in assertions.

### Heuristic 2: Random Without Seed

```javascript
const id = Math.random().toString(36);
expect(generateId()).toBe(id);
```

**Detection:** `Math.random()` in test without `jest.spyOn(Math, 'random')`.

### Heuristic 3: setTimeout/setInterval in Tests

```javascript
it("updates after delay", () => {
  triggerUpdate();
  setTimeout(() => {
    expect(state.updated).toBe(true);
  }, 100);
});
// Assertion is in callback - may not run before test ends!
```

**Detection:** Assertions inside `setTimeout` without `done` callback or `await`.

### Heuristic 4: Shared Mutable State

```javascript
let counter = 0;

beforeEach(() => { counter = 0; });

it("increments", () => {
  counter++;
  expect(counter).toBe(1);
});

it("is still one", () => {
  expect(counter).toBe(1); // FAILS if tests run in wrong order
});
```

**Detection:** Variables declared outside tests but mutated inside them.

### Heuristic 5: Port/File System Dependencies

```javascript
it("starts server", async () => {
  const server = await startServer(3000);
  // Fails if port 3000 is in use
});

it("reads config", () => {
  const config = readFileSync("./config.json");
  // Fails if file doesn't exist in CI
});
```

**Detection:** Hard-coded ports, file paths without mocking.

## Checklist for Audit

For each test file, check:

- [ ] Any exact value assertions on non-deterministic data?
- [ ] Do mocks match real implementation signatures?
- [ ] Does every test have at least one meaningful assertion?
- [ ] Are tests focused on single behaviors?
- [ ] Are fixtures representative and varied?
- [ ] Any time, random, or external dependencies?
- [ ] Are we testing behavior or implementation?
- [ ] Would this test catch a real bug?
