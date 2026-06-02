# Dev Pipeline Hand-off Improvements

## Summary

Three targeted fixes to the dev pipeline that close the contract gap between concurrent agents, remove dead code, and add a bounded retry loop after Reviewer failures — without breaking parallelism or adding pipeline interruptions.

## Scope

Dev pipeline only: Planner → PM Agent → Backend + Frontend (concurrent) → Reviewer.
Venture, Init, and Refactor workflows are out of scope.

## Gaps addressed

### Gap 1: Frontend←Backend contract gap in concurrent execution

**Problem:** Backend and Frontend run concurrently. Both read `Backend changes needed:` and `Frontend changes needed:` from `[PM-AGENT OUTPUT]` and independently interpret API contracts. When a spec is ambiguous or backend deviates from the prose description, Frontend implements against stale inferred contracts. Reviewer catches mismatches post-hoc but cannot fix them.

**Fix:** PM Agent adds a formal `API contracts:` block to its output in Requirements Extraction Mode. Both Backend and Frontend treat this as the canonical interface — method, path, and shapes are non-negotiable. Reviewer's contract check validates all three agents against PM's contract spec, not just cross-agent.

### Gap 2 (dropped)

PM Agent blocking ambiguities were considered as a pause point but dropped — Planner already catches most ambiguities before PM runs, impl agents document assumptions in `Items not implemented`, and the retry mechanism in Gap 4 is the correct correction point. Adding a warning print provides no behavioral value.

### Gap 3: QA Agent is dead code

**Problem:** `qa-agent/SKILL.md` exists and is fully maintained but was removed from the pipeline in a recent refactor. Backend and Frontend agents already write and run tests in Step 5.5 using the same implementation context — which produces better tests than a fresh-context QA agent reading finished files.

**Fix:** Delete `qa-agent/SKILL.md`.

### Gap 4: No feedback loop after Reviewer failure

**Problem:** When Reviewer returns FAIL or NEEDS REVIEW, the pipeline stops and the user must manually identify failing agents, fix issues, and re-run. There is no targeted re-dispatch.

**Fix:** After Reviewer completes, if status is FAIL or NEEDS REVIEW, hub inspects the output to determine which agents caused failures, prints failing items to the user, and asks "Attempt to fix N items? (yes / no)". If yes, only the affected agents are re-dispatched with Reviewer findings attached as additional context. A second Reviewer run is the final verdict — no further retries.

---

## Architecture

Pipeline shape is unchanged:

```
Planner → PM Agent → Backend + Frontend (concurrent) → Reviewer → [offer retry if FAIL/NEEDS REVIEW]
```

### File changes

| File | Change |
|---|---|
| `skills/pm-agent/SKILL.md` | Add `API contracts:` section to Requirements Extraction Mode output |
| `skills/nob/backend-agent/SKILL.md` | Step 3: extract and treat `API contracts:` from PM output as authoritative endpoint spec |
| `skills/nob/frontend-agent/SKILL.md` | Step 3: extract and treat `API contracts:` from PM output as authoritative endpoint spec |
| `skills/nob/reviewer/SKILL.md` | Step 3.5: three-way contract check against PM spec, not just cross-agent |
| `skills/nob/SKILL.md` | Phase 3: user-gated targeted retry after Reviewer FAIL/NEEDS REVIEW |
| `skills/nob/qa-agent/SKILL.md` | Delete |

---

## Detailed design

### PM Agent — `API contracts:` block

**Where:** Requirements Extraction Mode, Step 2. New extraction item added after `Frontend changes needed:`.

**How to populate:**
- Derive from `Backend changes needed:` — exact HTTP method, path, and request/response shapes
- If spec does not specify a field type, write `any` and flag as a `[non-blocking]` ambiguity
- If no backend API changes are involved, write `none`

**Output format addition** (inserted between `Frontend changes needed:` and `Edge cases to handle:`):

```
API contracts:
- [METHOD] [/exact/path]: request: { field: type, ... } → response: { field: type, ... }
- [METHOD] [/exact/path]: request: none → response: { field: type, ... }
(or: none — no HTTP API changes in this feature)
```

---

### Backend Agent — Step 3 addition

After extracting `Backend changes needed:` from `[PM-AGENT OUTPUT]`, also extract `API contracts:`. Store as PM_API_CONTRACTS.

During Step 5 (Implement): implement the endpoints specified in PM_API_CONTRACTS exactly — method, path, and shapes are non-negotiable. Any necessary deviation must be listed under `Items not implemented (needs human)` with the reason and what was implemented instead.

In the output block, `New API contracts:` must reflect what was actually built. If it matches PM_API_CONTRACTS exactly, no special note is needed. If it deviates, note the deviation inline.

---

### Frontend Agent — Step 3 addition

After extracting `Frontend changes needed:` from `[PM-AGENT OUTPUT]`, also extract `API contracts:`. Store as PM_API_CONTRACTS.

During Step 5 (Implement): consume the endpoints specified in PM_API_CONTRACTS exactly — do not infer or adjust paths or shapes. If `[BACKEND-AGENT OUTPUT]` is available in context (retry pass only), use its `New API contracts:` as the authoritative source instead of PM_API_CONTRACTS.

---

### Reviewer — Step 3.5 three-way contract check

Replace the existing two-way cross-agent check with a three-way check:

1. **PM → Backend**: for each contract in PM `API contracts:`, find the matching entry in `[BACKEND-AGENT OUTPUT]` `New API contracts:`. Flag as CONTRACT VIOLATION if method, path, or response shape differs.
2. **PM → Frontend**: for each contract in PM `API contracts:`, find the matching entry in `[FRONTEND-AGENT OUTPUT]` `API endpoints consumed:`. Flag as CONTRACT VIOLATION if method or path differs.
3. **Backend → Frontend** (existing): for each endpoint Frontend consumes, verify it matches Backend's actual output. Flag as CONTRACT VIOLATION if method, path, or response shape differs.

Skip the PM checks if `API contracts: none` in PM output. Skip Backend→Frontend if either output block is absent (existing skip conditions unchanged).

Add to output format:

```
Contract check:
  PM → Backend:   [PASS | VIOLATIONS: list | SKIPPED — reason]
  PM → Frontend:  [PASS | VIOLATIONS: list | SKIPPED — reason]
  Backend → Frontend: [PASS | VIOLATIONS: list | SKIPPED — reason]
```

---

### Hub — Phase 3 retry logic

After extracting `[REVIEWER OUTPUT]` and writing the final checkpoint:

**If `Overall status: PASS`:** proceed to terminal summary as normal.

**If `Overall status: NEEDS REVIEW` or `Overall status: FAIL`:**

Step 1 — Determine affected agents:
- Backend test FAIL in `Test results:` → flag Backend for retry
- Frontend test FAIL in `Test results:` → flag Frontend for retry
- `✗` or `⚠` criterion: cross-reference the criterion text against PM output's `Backend changes needed:` and `Frontend changes needed:` sections to determine which agent owns it. If it appears in `Backend changes needed:` → flag Backend. If in `Frontend changes needed:` → flag Frontend. If in both → flag both.
- Any CONTRACT VIOLATION in contract check → flag Frontend for retry; if Frontend is retrying, pass `BACKEND_OUTPUT` in the retry prompt (this is the one case where Frontend receives Backend's actual output)

Step 2 — Present and ask:
```
Reviewer found N items to address:
  [list of failing/partial criteria and contract violations]

Attempt to auto-fix? (yes / no)
```

Step 3 — If no: proceed to terminal summary using current REVIEWER_OUTPUT.

Step 4 — If yes: re-dispatch only flagged agents concurrently in the same assistant turn. Each retry prompt includes:
  - Original inputs (PM_OUTPUT, .nob.yml, CLAUDE.md)
  - `[REVIEWER OUTPUT]` block appended with header: "Reviewer found these failures — fix only these items: [list]"
  - Frontend retry only: if CONTRACT VIOLATION caused the retry, also include BACKEND_OUTPUT

Step 5 — Run Reviewer once more on the new output blocks. This is the FINAL review. No further retry is offered regardless of status. Proceed to terminal summary.

**Terminal summary addition** — add retry result line when a retry occurred:

```
Retry:     [ran | skipped]  →  Final review: [PASS | NEEDS REVIEW | FAIL]
```

---

## Constraints

- Parallelism is fully preserved: Backend and Frontend always dispatch concurrently
- No pipeline interruptions added: PM ambiguity surfacing dropped from scope
- Retry is bounded to exactly one pass — no loops
- Planner and PM Agent never re-run in the retry pass
- Fan-out mode: Reviewer receives a merged block of all slice outputs and produces one combined verdict. When retry is triggered, the hub re-dispatches all slices that had any failing criteria or test failures — not individual criterion-level targeting. Slices with PASS status are not re-dispatched.

## Acceptance criteria

- [ ] `[PM-AGENT OUTPUT]` includes `API contracts:` section in Requirements Extraction Mode
- [ ] Backend Agent documents deviations from PM contracts in `Items not implemented`
- [ ] Frontend Agent uses PM `API contracts:` as endpoint source of truth when running concurrently
- [ ] Frontend Agent uses `[BACKEND-AGENT OUTPUT]` contracts when available (retry pass)
- [ ] Reviewer performs three-way contract check and reports per-pair results
- [ ] Hub offers retry prompt after FAIL or NEEDS REVIEW with targeted agent selection
- [ ] Retry dispatches only affected agents concurrently
- [ ] Second Reviewer run is final — no further retry offered
- [ ] `qa-agent/SKILL.md` is deleted
- [ ] `agents.enabled` default in hub does not list `qa-agent`
- [ ] Fan-out path retry re-dispatches all slices with any failures; passing slices are not re-run
