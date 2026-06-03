# Reviewer Quality Checks — Design Spec

**Date:** 2026-06-03
**Branch:** nob/2026-06-02-ideation-agent-design
**Approach:** Inline extension of existing Reviewer agent (zero new dispatches)

## Overview

Nob's Reviewer currently checks three things: spec compliance (criteria ✓/✗/⚠), API contracts (PM→Backend→Frontend), and test results. It never asks "is this code well-written?" A spec-passing implementation can still contain `any` types, missing UI states, untested API endpoints, or hardcoded magic values — all of which create future debt.

This spec adds a `Code quality:` step and output section to the existing Reviewer agent. No new agent is dispatched. The Reviewer already runs at haiku and already reads changed files — the quality checks reuse those reads at near-zero additional token cost.

---

## What Changes

| File | Change |
|---|---|
| `skills/nob/reviewer/SKILL.md` | Add Step 3.7 (code quality scan) |
| `skills/nob/reviewer/SKILL.md` | Add `Code quality:` section to output block format |
| `skills/nob/reviewer/SKILL.md` | Update Step 5 (overall status) to factor in quality findings |
| `skills/nob/reviewer/SKILL.md` | Update output block validation fields list |
| `skills/nob/SKILL.md` | Update Output Block Validation Procedure table for Reviewer |

No new agents. No new phases. No new config keys.

---

## Step 3.7: Code Quality Scan (new step, inserted after Step 3.6)

Insert after the existing Step 3.6 (security findings) and before Step 4 (criteria check):

```
### Step 3.7: Code quality scan

Collect QUALITY_FILES = all file paths from `Files changed:` and `Files created:` in
[BACKEND-AGENT OUTPUT] and [FRONTEND-AGENT OUTPUT]. If fan-out mode, collect from all
slice outputs.

If QUALITY_FILES is empty: set QUALITY_FINDINGS = [] and skip the rest of this step.

Read each file in QUALITY_FILES. For each file, check only the applicable categories below.
Do NOT scan files not in QUALITY_FILES.

**Category 1 — Type safety (TypeScript files only: .ts, .tsx)**
- Check for `any` type annotations: parameter types, return types, variable declarations,
  type casts (`as any`). Each occurrence is one finding.
- Severity: IMPORTANT

**Category 2 — Frontend state completeness (.tsx, .jsx, .vue, .dart files only)**
- For each component/screen file in QUALITY_FILES that calls an API endpoint
  (contains `fetch(`, `axios.`, `apiClient.`, `dio.`, `http.get`, `http.post`,
  `URLSession`, `Retrofit`, or similar API call patterns):
  - Check for a loading state (spinner, skeleton, `isLoading`, `loading`, `isFetching`)
  - Check for an error state (error message render, catch block that sets display state,
    `isError`, `error &&`, `catch`)
  - If either is absent: one finding per missing state per file.
- Severity: IMPORTANT

**Category 3 — Untested endpoints (backend files only)**
- For each new API endpoint listed in `New API contracts:` in [BACKEND-AGENT OUTPUT]:
  - Check whether a test file in QUALITY_FILES (path contains `test`, `spec`, or `__tests__`)
    contains the endpoint path string.
  - If no test file contains the path: one finding.
- Severity: IMPORTANT

**Category 4 — Magic values (all source files)**
- Check for string or number literals used directly in logic (not in test files, not in
  config files, not in a named constant). Flag patterns like:
  - Status codes as raw numbers in conditions: `=== 404`, `=== 500` (except in test files)
  - Hardcoded timeout values: `setTimeout(..., 3000)`, `sleep(5000)`
  - Repeated string literals appearing more than once in the same file
- Severity: MINOR

Store all findings as QUALITY_FINDINGS = list of { severity, category, file, line, description }.
Set QUALITY_IMPORTANT_COUNT = count of IMPORTANT findings.
Set QUALITY_MINOR_COUNT = count of MINOR findings.
```

---

## Step 5: Overall Status (updated rule)

Add one rule to the existing status determination:

```
Additional rule: if QUALITY_IMPORTANT_COUNT > 0, the overall status is at minimum
NEEDS REVIEW — even if all spec criteria are ✓ and tests pass. Quality IMPORTANT
findings require human attention before the feature ships.

MINOR findings do not affect overall status.
```

---

## Step 6: Human Review Items (updated)

Add to the existing Step 6:

```
For each IMPORTANT quality finding, add one specific actionable item to
"Items for human review". Format: "Quality: {description} in {file}:{line}"

MINOR findings are listed in the Code quality section of the output block but
are NOT added to "Items for human review".
```

---

## Output Block Format (updated)

Add `Code quality:` section between Security and Criteria check:

```
[REVIEWER OUTPUT]
Source: [spec file path]
Workflow: [Spec→Code | Bug→Fix | API→Sync]

Test results:
  Backend: [PASS | FAIL — N failed | SKIPPED — reason]
  Frontend: [PASS | FAIL — N failed | SKIPPED — reason]

Contract check:
  PM → Backend:       [PASS | VIOLATIONS: list | SKIPPED — reason]
  PM → Frontend:      [PASS | VIOLATIONS: list | SKIPPED — reason]
  Backend → Frontend: [PASS | VIOLATIONS: list | SKIPPED — reason]

Security:
  Status: [PASS | FINDINGS: N medium, M low | SKIPPED (user) | SKIPPED (disabled) | NOT RUN]
  [findings if any]

Code quality:
  Status: PASS | FINDINGS: N important, M minor | SKIPPED — no changed files
  [if FINDINGS:]
  - [IMPORTANT] {category} | {file}:{line} | {description}
  - [MINOR] {category} | {file}:{line} | {description}

Criteria check:
  - [criterion]: ✓ / ✗ / ⚠

Overall status: PASS | NEEDS REVIEW | FAIL

Items for human review:
  - [or: none, all criteria met]
[/REVIEWER OUTPUT]
```

---

## Output Block Validation (updated)

The Reviewer's required fields list in the hub's Output Block Validation Procedure table gains one entry:

```
| Reviewer | `Overall status:`, `Test results:`, `Criteria check:`,
           `Items for human review:`, `Code quality:` |
```

---

## Token cost

The Reviewer already reads changed files for the criteria check (Step 4). Step 3.7 runs on the same already-read file content — no additional Read tool calls are needed for files already read in Step 4. For files not yet read in Step 4, Step 3.7 reads them once; Step 4 may re-read some of those same files, but haiku's context window retains the content.

Estimated additional tokens per run: **< 500 output tokens** (quality findings section is compact). The only added cost is the haiku reasoning over already-read content.

---

## Behavior Summary

| Scenario | Quality status | Overall status impact |
|---|---|---|
| No TypeScript, all states present, all endpoints tested | PASS | None |
| `any` in one changed .ts file | FINDINGS: 1 important | At minimum NEEDS REVIEW |
| Frontend component missing error state | FINDINGS: 1 important | At minimum NEEDS REVIEW |
| New endpoint has no test coverage | FINDINGS: 1 important | At minimum NEEDS REVIEW |
| Magic timeout value only | FINDINGS: 1 minor | None (informational) |
| No changed files | SKIPPED — no changed files | None |

---

## Acceptance Criteria

- Step 3.7 runs after Step 3.6 and before Step 4 on every Reviewer dispatch
- `any` type annotations in changed TypeScript files produce IMPORTANT findings
- Frontend component files that call APIs but lack loading or error state render produce IMPORTANT findings (one per missing state per file)
- New API endpoints in `New API contracts:` without matching test coverage produce IMPORTANT findings
- Magic timeout/status-code literals produce MINOR findings
- MINOR findings appear in the output block but do not affect overall status and are not added to Items for human review
- 1+ IMPORTANT finding forces overall status to at minimum NEEDS REVIEW
- The output block includes a `Code quality:` section between Security and Criteria check
- The output block validation procedure requires `Code quality:` as a required field for Reviewer
- Files not in `Files changed:` / `Files created:` are never scanned
- If QUALITY_FILES is empty, `Code quality: SKIPPED — no changed files` is emitted
- No new agent is dispatched — all checks run within the existing Reviewer agent session
