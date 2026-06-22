# Feature: Test Recovery Agent (`/nob:test-fix`)

## Summary
A standalone skill that reads a failing test suite output, isolates each failing assertion to its root cause, and dispatches a targeted Dev fix — bypassing PM and Tech Lead for speed.

## Users
Developers whose test suite fails after a `/nob implement` run, after a manual code change, or after a CI failure, who want nob to diagnose and fix the failures without a full pipeline re-run.

## User flow
1. Developer runs `/nob:test-fix` (standalone) or `/nob:test-fix --unit api` to scope to one unit.
2. Test recovery agent detects the stack and runs the test suite in the target unit(s).
3. Agent parses test output: groups failures by test file, extracts each failing assertion + stack trace.
4. For each failure group, agent identifies: failing test name, expected vs. actual, file:line of the assertion, and the implementation file most likely responsible (via stack trace or import graph).
5. Agent emits a **recovery plan**: list of failures with root cause hypothesis and proposed fix location per failure.
6. Prompts: `"Found N failing test(s). Attempt auto-fix? (yes / show-plan / cancel)"`.
7. If `yes`: dispatches a targeted Dev agent for each failure group (parallel where independent, sequential where the same file is involved).
8. Dev patches the implementation (never the tests). Re-runs the test suite after each fix.
9. If tests pass: emits `[TEST RECOVERY OUTPUT]` with `Status: PASS`.
10. If tests still fail after one Dev pass: emits `[TEST RECOVERY OUTPUT]` with `Status: NEEDS REVIEW` and the remaining failures listed.
11. `show-plan`: prints the recovery plan without dispatching Dev; developer can act manually.

## Requirements
- Standalone invocable via `/nob:test-fix`. Also invokable from the hub after a failed Reviewer check (hub passes `[REVIEWER OUTPUT]` as context instead of running the suite again).
- Reads `.nob.yml` (if present) to determine units and stack types. Falls back to auto-detection.
- `--unit <name>` flag scopes recovery to one unit's test suite.
- Test runner detection per stack: jest/vitest (node/next/react), pytest (python), `go test ./...` (go), rspec (ruby). Reads `package.json` scripts for overrides.
- Parses test output formats: Jest/Vitest JSON reporter, pytest short/long output, `go test` output, RSpec documentation format.
- Recovery plan output (printed before approval prompt): one line per failure — `[unit] test-name: hypothesis (impl file:line)`.
- Dev agent receives the recovery plan and the failing test output as `[INPUTS]`. It patches implementation files only — test files are read-only during a test-fix run.
- Max one Dev retry per failure group. If still failing after one pass: mark as `NEEDS REVIEW`.
- `[TEST RECOVERY OUTPUT]` required fields: `Units tested:`, `Failures found:`, `Fixes attempted:`, `Fixed:`, `Still failing:`, `Status:`.
- `agents.models.test-recovery` configurable in `.nob.yml`; default: `sonnet`.

## API contracts
not applicable — API contracts are defined by the Tech Lead Agent during implementation

## Data models
not applicable — data schemas are defined by the Tech Lead Agent during implementation

## Acceptance criteria
- [ ] `/nob:test-fix` on a repo with failing tests runs the suite and outputs a recovery plan.
- [ ] `yes` dispatches Dev for each failure group and re-runs the suite afterward.
- [ ] Dev patches only implementation files — no test file is modified.
- [ ] After a successful fix, `[TEST RECOVERY OUTPUT]` reports `Status: PASS` and lists the fixed tests.
- [ ] After a failed fix (tests still failing), `Status: NEEDS REVIEW` and remaining failures are listed.
- [ ] `--unit api` scopes the suite run and Dev dispatch to the `api` unit only.
- [ ] `show-plan` prints the recovery plan and exits without dispatching Dev.
- [ ] `cancel` exits cleanly without running any Dev agents.
- [ ] If no tests fail, prints `"All tests pass — nothing to fix."` and exits.
- [ ] Hub can dispatch test-fix after a FAIL Reviewer check, passing reviewer output as context (no duplicate suite run).

## Builds on
- `skills/dev/SKILL.md` — Dev agent is dispatched for targeted implementation patches
- `skills/dev/stacks/` — per-stack test runner commands and output format parsing
- `skills/nob/SKILL.md` — hub integration: dispatch after Reviewer FAIL as an alternative to the retry loop
- `skills/reviewer/SKILL.md` — `[REVIEWER OUTPUT]` test failure section is the input when hub-dispatched
- `skills/debug/SKILL.md` — root cause methodology (read-only diagnosis before patching) informs the recovery plan step

## Constraints
- Test recovery agent never modifies test files — implementation files only.
- One Dev retry per failure group maximum (does not loop indefinitely).
- Does not replace the Phase 3.5 retry loop — that loop re-runs the full pipeline. Test-fix is a surgical, post-run tool.

## Error states
- Test runner not found: print `"Could not detect a test runner for unit {name}. Add a 'test' script to package.json or specify the runner in .nob.yml."` and exit.
- Test suite times out: report `timed-out` in `[TEST RECOVERY OUTPUT]`, list unit, exit.
- Stack trace in test output does not point to a recognisable implementation file: mark failure as `root-cause-unclear` in recovery plan, skip Dev dispatch for that group, include in `Still failing:`.
- Dev patches a file that is outside the unit boundary: log `boundary-violation — skipped` and mark the failure as `NEEDS REVIEW`.

## Out of scope
- Fixing flaky tests (non-deterministic failures) — only deterministic assertion failures.
- Modifying test expectations or test logic.
- Running the full nob pipeline (PM → TL → Dev) — that is `/nob implement`.
- Integration or end-to-end test recovery (only unit tests in the current scope).

## Open questions
- Should test-fix be automatically offered by the hub when Reviewer reports test failures, or only when the user explicitly invokes it? Defer to Tech Lead.
- When multiple failure groups touch the same file, should they be batched into one Dev dispatch or sequenced? Defer to Tech Lead.
