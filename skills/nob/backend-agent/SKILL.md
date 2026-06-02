---
name: nob-backend-agent
description: Use when implementing backend/API changes in a Nob workflow. Reads [PM-AGENT OUTPUT] or [QA-AGENT OUTPUT] to understand what to build, explores existing backend codebase, implements following existing patterns, and outputs a structured [BACKEND-AGENT OUTPUT] block. Part of the Nob skill hub.
---

# Nob — Backend Agent

## Overview
Implement backend changes by reading requirements from the [PM-AGENT OUTPUT] block and the existing codebase. Never invent patterns — always read and follow what already exists.

## Process

### Step 1: Read configuration
Get `stack.backend.type` and `stack.backend.path` from the `.nob.yml contents` field in your `[INPUTS]` block. Do not read `.nob.yml` from disk — the hub has already resolved it.

### Step 1.5: Select stack guidance
Read `stack.backend.type` from your `[INPUTS]`. Find the matching subsection under `## Stack-specific guidance` at the bottom of this file and use it as your default implementation pattern. If your stack type has no matching subsection, skip this step and rely on codebase exploration alone. Once you read the codebase in Step 4, prefer whatever patterns already exist there — the guidance is a starting point, not a rule.

### Step 2: Read CLAUDE.md
Read `CLAUDE.md` for backend conventions: route patterns, auth middleware, error format, test commands.

### Step 3: Read context blocks
From the current session context:
1. Find and read `[PM-AGENT OUTPUT]` — extract "Backend changes needed" (includes specific file paths). If not found, stop: "Backend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context. Ensure pm-agent ran before backend-agent."
   Also extract `API contracts:` from `[PM-AGENT OUTPUT]`. Store as PM_API_CONTRACTS. If the field reads `none`, set PM_API_CONTRACTS to null.
2. Find and read `[PLAN OUTPUT]` if present — extract "Affected files: Backend", "Affected files: Schema", and "Risks:". Store as PLAN_RISKS. If not found, set PLAN_RISKS to empty.

### Step 3.5: Select execution path

From `[PLAN OUTPUT]`, read `Complexity: Backend:`.

- If `simple` or `n/a` (or if `[PLAN OUTPUT]` is not present): proceed with the **in-session path** — continue to Step 4 as normal.
- If `complex`: enter **coordinator mode** — skip Steps 4, 5, and 5.5 entirely. Continue to the **Coordinator Mode** section below.

---

## Coordinator Mode (complex path only)

Enter this section only when `Complexity: Backend: complex` from Step 3.5. This replaces Steps 4, 5, and 5.5. After completing Step 7-C, the coordinator is done — do not continue to Steps 4, 5, or 5.5.

### Step 4-C: Dispatch Exploration Agent

Dispatch a sub-agent with `model: haiku` and this prompt:

```
You are a backend codebase exploration agent. Read the relevant files and emit a compact summary. Do NOT implement anything.

Read every file in this list:
{every path from "Affected files: Backend" and "Affected files: Schema" in [PLAN OUTPUT]}

Also read one representative example of each:
- A route/handler file (to capture route structure, middleware usage, error response format)
- A service or business-logic file
- A test file (to capture test style, assertion patterns, setup approach)
{if [AUTH] in PLAN_RISKS: - The auth middleware file}
{if [MIGRATION] in PLAN_RISKS: - An existing schema file and an existing migration file}

Emit this block:

[BACKEND-EXPLORATION CONTEXT]
Affected files:
  - [path]: [one-sentence role]

Patterns observed:
  Route structure: [handler signature, how router is mounted]
  Error format: [exact error response shape]
  Test style: [file structure, assertion style, setup pattern]
  Auth wiring: [how middleware is applied to routes, or: none detected]
  Migration pattern: [how migrations are created and run, or: none detected]

Relevant snippets:
  [Function signatures, type shapes, and key lines only. No full file dumps. Keep this section under 1500 tokens.]
[/BACKEND-EXPLORATION CONTEXT]
```

Extract `[BACKEND-EXPLORATION CONTEXT]...[/BACKEND-EXPLORATION CONTEXT]`. Store as EXPLORATION_CONTEXT.

If EXPLORATION_CONTEXT is empty or the block was not found, stop with: "Backend coordinator cannot proceed — exploration agent returned no [BACKEND-EXPLORATION CONTEXT] block. Re-run or switch to in-session path."

### Step 5-C: Determine Task List (in-session, no dispatch)

Based on EXPLORATION_CONTEXT and the "Backend changes needed" section from [PM-AGENT OUTPUT], decide which tasks are needed. Only include tasks that have actual work to do.

Evaluate in this order:

1. **schema** — create/update schema and migration file. Include if `[MIGRATION]` in PLAN_RISKS or PM_OUTPUT requires new or changed model fields.
2. **service** — implement business logic and data access. Include if new service methods or data layer changes are needed.
3. **routes** — implement HTTP handlers and register routes. Include if new or changed endpoints are required.
4. **tests** — write tests for all new or changed endpoints and service methods. Always include. For `target_files`, use the test file paths that correspond to the routes and service files implemented in previous tasks (e.g. if routes task creates `src/routes/users.ts`, target `tests/routes/users.test.ts`).

Store as TASK_LIST = ordered array of objects: `{ name: string, description: string, target_files: string[] }`.

If TASK_LIST is empty after this evaluation, stop with: "Backend coordinator: no tasks identified — verify [PM-AGENT OUTPUT] contains 'Backend changes needed' content."

### Step 6-C: Dispatch Sequential Task Sub-Agents

For each task in TASK_LIST **in order** (do not dispatch the next until the previous returns):

Dispatch a sub-agent with the `backend-agent` model from `.nob.yml` (default: `sonnet`) and this prompt:

```
You are a focused backend implementation agent. Implement exactly one task. Do not read additional files — all context you need is provided below.

Task: {task.name}
Description: {task.description}
Target files (implement only these): {task.target_files}

[BACKEND-EXPLORATION CONTEXT]
{EXPLORATION_CONTEXT}
[/BACKEND-EXPLORATION CONTEXT]

Backend changes needed (from PM Agent):
{the "Backend changes needed" section from [PM-AGENT OUTPUT]}

{if this is not the first task:
Previous task output:
{previous task's [TASK OUTPUT] block}
}

{if PM_API_CONTRACTS is non-null:
API contracts (implement exactly — method, path, and shapes are non-negotiable):
{PM_API_CONTRACTS}
}

Follow the patterns in [BACKEND-EXPLORATION CONTEXT] exactly. Emit:

[TASK OUTPUT: {task.name}]
Files changed:
  - [path]: [reason]
Files created:
  - [path]: [reason]
New API contracts (routes task only):
  - [METHOD] [/path]: request: [shape] → response: [shape]
Updated API contracts (routes task only):
  - [METHOD] [/path]: [what changed]
Test results (tests task only):
  Command: [exact command run]
  New tests: [PASS | FAIL — N failed]
  Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]
Items not implemented (needs human):
  - [item and reason, or: none]
[/TASK OUTPUT: {task.name}]
```

Store each result as TASK_OUTPUT_{task.name}. Pass it as "Previous task output" to the next sub-agent.

### Step 7-C: Assemble Final Output

Merge all TASK_OUTPUT blocks into the standard `[BACKEND-AGENT OUTPUT]` format. Combine across all tasks:
- All `Files changed` entries
- All `Files created` entries
- All `New API contracts` and `Updated API contracts` entries (from routes task)
- Test results from the tests task (if not present, write: `SKIPPED — run by coordinator task sub-agent`)
- All `Items not implemented` entries (deduplicated)

Then emit the `[BACKEND-AGENT OUTPUT]` block as defined in **## Output Format** below and stop. Do not continue to Steps 4, 5, or 5.5.

---

### Step 4: Explore existing backend codebase
Before writing any code:

**1. Start from identified files** — read the files named in "Backend changes needed" from [PM-AGENT OUTPUT] and "Affected files:" from [PLAN OUTPUT] directly. These are your primary targets.

**2. Fill gaps via exploration** — for any context not already covered, also read:
- The main routes file or router index at `{backend.path}/src/routes/` (or equivalent)
- One existing route file to understand the pattern (handler structure, middleware usage, response format)
- The existing model or data layer for the resource being modified
- One existing test file for a similar route (to understand test patterns)

**3. Act on PLAN_RISKS**:
- `[AUTH]` — read the existing auth middleware; note exactly how it is applied to routes (argument position, decorator, etc.)
- `[MIGRATION]` — read existing schema/migration files to understand the migration pattern; you will create one in Step 5
- `[BREAKING]` — read the existing endpoint being changed; grep for its callers across the codebase
- `[SHARED]` — read shared utilities being touched; understand all callers before modifying

Do NOT skip this step. Implementing without reading leads to pattern violations.

### Step 5: Implement
Write the minimum code to satisfy the "Backend changes needed" requirements from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:

**API contract enforcement**: when PM_API_CONTRACTS is non-null, implement each listed endpoint exactly — HTTP method, path, and request/response shapes are non-negotiable. Any necessary deviation (e.g. the path conflicts with an existing route, or a field name clashes with the schema) must be documented in `Items not implemented (needs human)` with: the PM-specified contract, what was implemented instead, and the reason.
- Same middleware usage as existing routes
- Same error response format
- Same file organization
- Same import style

Write or update tests for every new or changed endpoint.

**If `[MIGRATION]` in PLAN_RISKS**: after updating the schema/model, create a migration file following the existing migration pattern. If no migration tooling is detected, note it under "Items not implemented (needs human)".

**If `[AUTH]` in PLAN_RISKS**: verify every new/changed endpoint applies auth middleware the same way comparable existing routes do. If no comparable routes use auth, do not add it — flag it instead.

**If `[BREAKING]` in PLAN_RISKS**: list any callers of the old contract found in Step 4 under "Items not implemented (needs human)" — do not silently break them.

### Step 5.5: Run tests and verify

Run the full backend test suite using the command for your stack (see Stack-specific guidance). Then run the type-checker/compiler if applicable:
- TS: `npx tsc --noEmit`
- Go: `go build ./...`
- Python: `mypy .` (if mypy is installed)

Capture stdout + stderr combined. If output exceeds 80 lines, keep the last 80 lines and prepend `[truncated — showing last 80 lines]`.

Record:
- **New tests**: PASS / FAIL (number failed)
- **Existing tests (regression)**: PASS / FAIL (number failed, list file names)

Include the verbatim captured output in `Test output:` in your output block. If no test command is detected, write `SKIPPED — no test command found`.

If tests fail: attempt to fix. If the fix requires more than ~5 lines of non-obvious changes, stop and flag it in "Items not implemented (needs human)" — do not spiral.

### Step 6: Output
List every file changed or created with a one-sentence reason. List every new or changed API contract.

## Output Format Requirement

Your output block must:
- Begin with `[BACKEND-AGENT OUTPUT]` on its own line (no leading spaces or characters)
- End with `[/BACKEND-AGENT OUTPUT]` on its own line
- Include every required field: `Files changed:`, `New API contracts:`, `Items not implemented:`, `Test results:`, `Test output:`
- Use the exact field names listed — no synonyms, no omissions

Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

## Output Format

```
[BACKEND-AGENT OUTPUT]
Stack: [type from .nob.yml]
Backend path: [path from .nob.yml]

Files changed:
- [exact/path/to/file.js]: [one-sentence reason]

Files created:
- [exact/path/to/file.js]: [one-sentence reason]

New API contracts:
- [METHOD] [/path]: request: [shape] → response: [shape]

Updated API contracts:
- [METHOD] [/path]: [what changed]

Tests written:
- [exact/path/to/test.js]: [what is tested]

Test results:
  Command: [exact command run]
  New tests: [PASS | FAIL — N failed]
  Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]

Test output:
  [verbatim last 80 lines of test runner + compiler stdout/stderr]
  (or: SKIPPED — no test command found)
  (or: SKIPPED — compile-only project, no test suite)

Deferred items:
- [item not implemented due to scope limit, or: none]

Items not implemented (needs human):
- [specific item and reason, or: none]
[/BACKEND-AGENT OUTPUT]
```

## Error Handling
- **No [PM-AGENT OUTPUT] in context**: stop with message above
- **.nob.yml backend.enabled is false**: output "Backend Agent skipped — backend disabled in .nob.yml"
- **Existing codebase uses a different pattern than CLAUDE.md describes**: follow the actual codebase, not CLAUDE.md, and note the discrepancy
- **Requirement is too vague to implement**: implement a reasonable interpretation, flag it in "Items not implemented" section

---

## Stack-specific guidance

### node

**File structure:**
- Route handlers: `src/routes/<resource>.js` (or `.ts`)
- Middleware: `src/middleware/`
- Models / data layer: `src/models/`

**Validation:**
Use `express-validator`. Declare `check()` chains in the route file, then call `validationResult(req)` at the top of the handler and return 422 if errors exist:
```js
const errors = validationResult(req);
if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });
```

**Error format:**
```js
res.status(400).json({ error: 'Human-readable message' });
```
Never throw — always return with `res`.

**Test pattern:**
`jest` + `supertest`. One `describe` block per route file. Use `beforeEach` to get a fresh app instance; use `afterAll` to close the server.
Run: `cd {backend.path} && npm test`

**Auth pattern:**
Middleware passed as the second argument to the router method:
```js
router.post('/resource', authMiddleware, handler);
```

---

### python

**File structure:**
- Route modules: `app/routers/<resource>.py`
- Pydantic request/response models: `app/schemas/<resource>.py`
- Business logic: `app/services/<resource>.py`
- FastAPI dependencies: `app/dependencies.py`

**Validation:**
Declare a Pydantic model as the function parameter type. FastAPI validates automatically and returns 422 on failure:
```python
class CreateItemRequest(BaseModel):
    name: str
    price: float

@router.post("/items")
async def create_item(body: CreateItemRequest):
    ...
```

**Error format:**
```python
raise HTTPException(status_code=400, detail="Human-readable message")
```

**Test pattern:**
`pytest` + `httpx.AsyncClient`. Use a `@pytest.fixture` that yields the async client:
```python
@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as c:
        yield c
```
Run: `cd {backend.path} && pytest -v`

**Auth pattern:**
FastAPI `Depends` injected as a function parameter:
```python
@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    ...
```

---

### go

**File structure:**
- HTTP handlers: `internal/handler/<resource>.go`
- Business logic: `internal/service/<resource>.go`
- Structs / types: `internal/model/<resource>.go`

**Validation:**
Manual validation in the handler, or struct tags with `github.com/go-playground/validator`:
```go
if req.Name == "" {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusBadRequest)
    json.NewEncoder(w).Encode(map[string]string{"error": "name is required"})
    return
}
```

**Error format:**
```go
w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusBadRequest)
json.NewEncoder(w).Encode(map[string]string{"error": "Human-readable message"})
```

**Test pattern:**
Standard `testing` package with `net/http/httptest`:
```go
func TestCreateItem(t *testing.T) {
    req := httptest.NewRequest(http.MethodPost, "/items", body)
    rr := httptest.NewRecorder()
    handler(rr, req)
    if rr.Code != http.StatusCreated { t.Errorf(...) }
}
```
Run: `cd {backend.path} && go test ./...`

**Auth pattern:**
Middleware wraps the handler function:
```go
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // validate token, then:
        next(w, r)
    }
}
```

---

### java

**File structure:**
- Controllers: `src/main/java/{pkg}/controller/<Resource>Controller.java`
- Services: `src/main/java/{pkg}/service/<Resource>Service.java`
- Request/response DTOs: `src/main/java/{pkg}/dto/`
- JPA entities: `src/main/java/{pkg}/model/`

**Validation:**
`jakarta.validation` annotations on DTO fields, `@Valid` on the controller parameter:
```java
public record CreateItemRequest(@NotBlank String name, @Positive double price) {}

@PostMapping("/items")
public ResponseEntity<ItemResponse> create(@Valid @RequestBody CreateItemRequest req) { ... }
```

**Error format:**
`@ControllerAdvice` class with `@ExceptionHandler`:
```java
@ExceptionHandler(MethodArgumentNotValidException.class)
public ResponseEntity<Map<String,String>> handleValidation(MethodArgumentNotValidException ex) {
    String msg = ex.getBindingResult().getFieldErrors().stream()
        .map(e -> e.getField() + ": " + e.getDefaultMessage())
        .collect(Collectors.joining("; "));
    return ResponseEntity.badRequest().body(Map.of("error", msg));
}
```

**Test pattern:**
`@WebMvcTest` + `MockMvc`:
```java
@WebMvcTest(ItemController.class)
class ItemControllerTest {
    @Autowired MockMvc mvc;

    @Test void shouldCreateItem() throws Exception {
        mvc.perform(post("/items").content(...).contentType(APPLICATION_JSON))
           .andExpect(status().isCreated());
    }
}
```
Run: If `./mvnw` exists: `cd {backend.path} && ./mvnw test`. If `./gradlew` exists: `cd {backend.path} && ./gradlew test`.

**Auth pattern:**
`@PreAuthorize` on the controller method, or `SecurityFilterChain` bean in a `@Configuration` class:
```java
@PreAuthorize("isAuthenticated()")
@GetMapping("/me")
public UserResponse getMe(...) { ... }
```
