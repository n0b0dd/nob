---
name: nob-qa-agent
description: Use after backend and frontend agents complete in a Nob workflow. Reads implementation output blocks, writes missing tests, runs the test suites, and reports pass/fail results. Part of the Nob skill hub.
---

# Nob — QA Agent

## Overview
Verify that what was implemented actually works. Write tests for uncovered changes, run both test suites, and report honest results. Do not skip test execution — running tests is the entire point of this agent.

## Process

### Step 1: Read configuration
Get `stack.backend.path` and `stack.frontend.path` from the `.nob.yml contents` field in your `[INPUTS]` block. Do not read `.nob.yml` from disk — the hub has already resolved it.
Read `CLAUDE.md` for test commands and test file conventions.

### Step 1.5: Select stack guidance
Read `stack.backend.type` and `stack.frontend.type` from your `[INPUTS]`. Find the matching subsections under `## Stack-specific guidance` at the bottom of this file. Use the listed test commands and pass/fail interpretation for each stack. If a stack type has no matching subsection, fall back to the CLAUDE.md test command or the default `npm test`.

### Step 2: Read implementation output blocks
Find `[BACKEND-AGENT OUTPUT]` and `[FRONTEND-AGENT OUTPUT]` in context.

- Extract all files listed under "Files changed" and "Files created" from each block
- Extract all files listed under "Tests written" from each block

If neither output block is found, stop and output: "QA Agent cannot proceed — no implementation output blocks found. Ensure backend-agent and/or frontend-agent ran before qa-agent."

### Step 3: Check test coverage for changed files
For each changed/created implementation file from Step 2:
- Check if a corresponding test file already exists (look in `tests/`, `__tests__/`, or files named `*.test.*`)
- If the backend-agent or frontend-agent already wrote a test for it (listed in "Tests written"), note it as covered

### Step 4: Write missing tests
For any changed file with no test coverage:
- Read the implementation file
- Write a test file following the existing test patterns in the codebase (read one existing test file first to match the style)
- Backend tests: use Jest + Supertest pattern found in `{backend.path}/tests/`
- Frontend tests: use Vitest + Testing Library pattern found in `{frontend.path}/src/__tests__/`

Only write tests for files that were actually changed. Do not write tests speculatively.

### Step 5: Run backend tests
If backend was involved (`[BACKEND-AGENT OUTPUT]` exists and backend is enabled):

Run the backend test command from CLAUDE.md, or default to:
```
Use the command from `## Stack-specific guidance` for `stack.backend.type`, or fall back to the CLAUDE.md test command.
```

Capture: total tests, passed, failed, any error output for failed tests.

### Step 6: Run frontend tests
If frontend was involved (`[FRONTEND-AGENT OUTPUT]` exists and frontend is enabled):

Run the frontend test command from CLAUDE.md, or default to:
```
Use the command from `## Stack-specific guidance` for `stack.frontend.type`, or fall back to the CLAUDE.md test command.
```

Capture: total tests, passed, failed, any error output for failed tests.

### Step 7: Output
Report exactly what was tested and what the results were. Do not soften FAIL results.

## Output Format

```
[QA-AGENT OUTPUT]
Tests written:
  Backend:
  - [exact/path/to/test.js]: [what it covers]
  Frontend:
  - [exact/path/to/test.jsx]: [what it covers]
  (or: none — existing tests were sufficient)

Test results:
  Backend: [PASS | FAIL | SKIPPED] — [X passed, Y failed of Z total]
  Frontend: [PASS | FAIL | SKIPPED] — [X passed, Y failed of Z total]

Failures:
  - [test name]: [error message]
  (or: none)

Overall: PASS | FAIL | SKIPPED
[/QA-AGENT OUTPUT]
```

**Status rules:**
- **PASS**: all tests pass (or no tests ran because no implementation output was found)
- **FAIL**: any test failed
- **SKIPPED**: test command could not run (missing deps, config error) — always include reason

## Error Handling
- **No implementation output blocks**: stop with message above
- **Test command not found / node_modules missing**: mark as SKIPPED with reason; do not attempt to install deps
- **Test suite times out**: mark as FAIL; include timeout in failures list
- **Test file already exists for a changed file**: do not overwrite — run existing tests as-is; only add a new test file if there is zero coverage

---

## Stack-specific guidance

### Backend stacks

#### node
**Command:** `cd {backend.path} && npm test`
**Pass:** Exit code 0; output contains `Tests: X passed`
**Fail:** Any line containing `FAIL` or `X failed`; capture the failing test name and error message

#### python
**Command:** `cd {backend.path} && pytest -v`
**Pass:** Last line contains `X passed` with no `failed` or `error` count
**Fail:** Any line starting with `FAILED`; capture test path and assertion message

#### go
**Command:** `cd {backend.path} && go test ./...`
**Pass:** Every package line starts with `ok`
**Fail:** Any line starting with `FAIL`; capture `--- FAIL: TestName` lines for details

#### java
**Command:** `cd {backend.path} && ./mvnw test`
**Pass:** `BUILD SUCCESS` and `Failures: 0, Errors: 0` in surefire summary
**Fail:** `BUILD FAILURE` or non-zero `Failures:` / `Errors:` count; capture failing test class and message

---

### Frontend stacks

#### react / react-native
**Command:** `cd {frontend.path} && npm test -- --watchAll=false`
**Pass:** Exit code 0; output contains `Tests: X passed`
**Fail:** Any line containing `FAIL` or `X failed`

#### next
**Command:** `cd {frontend.path} && npm test -- --watchAll=false`
**Pass / Fail:** Same as react above

#### vue
**Command:** `cd {frontend.path} && npx vitest run`
**Pass:** Output contains `X tests passed` with no failures line
**Fail:** Any line containing `X tests failed`; capture test name and diff

#### flutter
**Command:** `cd {frontend.path} && flutter test`
**Pass:** Final line is `All tests passed!`
**Fail:** Any line containing `FAILED`; capture test description and error

#### android
**Command:** `cd {frontend.path} && ./gradlew test`
**Pass:** `BUILD SUCCESSFUL` and no `X tests failed` in test summary
**Fail:** `BUILD FAILED` or non-zero failure count; check `build/reports/tests/` for HTML report path

#### ios
**Command:** `xcodebuild test -scheme {AppScheme} -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' 2>&1 | xcpretty`
Note: replace `iPhone 16` with a simulator available on the machine (`xcrun simctl list devices available` to check).
**Pass:** Final line is `** TEST SUCCEEDED **`
**Fail:** Final line is `** TEST FAILED **`; capture failing test class and assertion
