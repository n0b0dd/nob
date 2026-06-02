# Critical Production Gaps — Design Spec

**Date:** 2026-06-02
**Branch:** nob/2026-06-02-ideation-agent-design
**Approach:** Hub-centric enforcement (Approach C)

## Overview

Four critical gaps prevent Nob from being production-reliable:

1. **Execution-grounded correctness** — agents claim tests pass; reviewer trusts the claim
2. **Structured inter-agent contracts** — freeform output blocks silently break on model drift
3. **Worktree isolation** — agents write directly to the working tree; mid-run failures leave partial changes
4. **Timeout & hang recovery** — runaway or silent agents block the pipeline with no graceful exit

All four fixes concentrate enforcement in the hub (`skills/nob/SKILL.md`). Sub-agent files change only their output sections and test execution steps.

---

## Architecture

```
Step 0:   Git branch  →  git worktree add .nob/worktrees/<run-id> <branch>
                          WORKTREE_PATH set. All agents use this path as working directory.

Phase 1:  Planner dispatch
          Hub validates output block (required fields check)
          Missing fields → re-dispatch once with repair instruction
          Still missing → status: malformed

Phase 2:  PM → Backend+Frontend dispatch
          Scope cap injected into every agent prompt (15-file soft limit)
          Hub validates each output block after return
          Missing block after re-dispatch → status: timed_out

Phase 2.5: Security Agent (output block validation added, logic unchanged)

Phase 3:  Reviewer
          Reads Test output: verbatim — corroborates Test results: claim
          Treats Deferred items: entries as ⚠ partial automatically

Phase 3.5: Retry (unchanged logic, uses WORKTREE_PATH)

Step 4:   Terminal summary
          timed_out / malformed slots surfaced with resume instructions
          PASS → worktree committed and removed
          FAIL/NEEDS REVIEW → worktree preserved for inspection
          Cancel → worktree removed --force
```

New checkpoint statuses: `timed_out`, `malformed` (alongside `pending`, `in_progress`, `completed`, `failed`).

---

## Gap 1: Execution-Grounded Test Results

### Problem

Backend and frontend agents write prose claiming tests passed. The reviewer reads that prose and propagates the claim. A failing `tsc`, broken assertion, or import error goes undetected.

### Fix

Agents run tests/compile as the final step and include verbatim output. The reviewer reads the raw output, not the summary claim.

### Changes: `backend-agent/SKILL.md` and `frontend-agent/SKILL.md`

Add a mandatory test execution step after all file writes:

```
After all file changes are written:
1. Detect and run the project's test command:
   - JS/TS: check package.json scripts for "test", "test:unit", "vitest", "jest"
   - Python: pytest if present, else python -m unittest
   - Go: go test ./...
   - If no test command found: note "no test command detected"
2. Run the type-checker / compiler if applicable:
   - TS: npx tsc --noEmit
   - Go: go build ./...
   - Python: mypy . (if mypy is installed)
3. Capture stdout + stderr combined.
   If output exceeds 80 lines, keep the last 80 lines only.
   Prepend: "[truncated — showing last 80 lines]"
4. Include verbatim in the output block under Test output:
```

### New required output fields

```
Test results:  PASS | FAIL — N failed | SKIPPED — reason
Test output:
  <verbatim last 80 lines of test runner + compiler stdout/stderr>
  (or: SKIPPED — no test command found)
  (or: SKIPPED — compile-only project, no test suite)

Deferred items:
  - <item not implemented due to scope limit>
  (or: none)
```

### Changes: `reviewer/SKILL.md`

Replace current test-reading logic (Step 3) with:

- Read `Test output:` field verbatim from each agent block.
- If `Test output:` absent → mark that layer `SKIPPED — agent did not provide raw output`.
- If `Test results: PASS` but `Test output:` contains error lines (ERROR, FAILED, panic, tsc error) → downgrade to `FAIL` and flag the discrepancy in "Items for human review".
- If `Test results: FAIL` → copy the first 10 lines of `Test output:` into "Items for human review".
- Never infer PASS from `Test results:` alone — it must be corroborated by `Test output:`.

---

## Gap 2: Strict Text Protocol

### Problem

Output blocks are freeform text. A missing delimiter, wrong field name, or extra whitespace produces an empty extraction. The hub continues with a null value downstream, silently corrupting the pipeline.

### Fix

Define exact required fields per agent. Hub validates presence after every dispatch. Invalid block → one re-dispatch with explicit repair instruction. Still invalid → `malformed` status, treated same as `failed` for pipeline flow.

### Required fields per output block

| Agent | Required fields |
|---|---|
| Planner | `Workflow:`, `Mode:`, `Affected layers:`, `Risks:`, `Ambiguities:` |
| PM Agent | `Requirements:`, `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:` |
| Backend Agent | `Files changed:`, `New API contracts:`, `Items not implemented:`, `Test results:`, `Test output:` |
| Frontend Agent | `Files changed:`, `API endpoints consumed:`, `Items not implemented:`, `Test results:`, `Test output:` |
| Security Agent | `Status:`, `Findings:` |
| Reviewer | `Overall status:`, `Test results:`, `Criteria check:`, `Items for human review:` |

### Hub validation step

Added after every Agent dispatch, before passing output to the next agent:

```
After extracting [X OUTPUT]...[/X OUTPUT]:
1. Check that every required field for this agent is present
   (field name + colon must appear on its own line within the block).
2. If any required field is missing:
   Re-dispatch once, prepending to the original prompt:
   "Your previous response was missing these required fields: [list].
    Re-emit the complete [X OUTPUT] block with ALL required fields present.
    Do not omit any field even if its value is 'none' or 'n/a'."
3. If still missing after re-dispatch:
   Mark status: malformed.
   Do not pass a malformed block to downstream agents.
   Treat malformed the same as failed for pipeline flow decisions.
```

### Output format rule added to every sub-agent SKILL.md

```
OUTPUT FORMAT REQUIREMENT
Your output block must:
- Begin with [X OUTPUT] on its own line (no leading spaces or characters)
- End with [/X OUTPUT] on its own line
- Include every required field as "FieldName: value" or "FieldName:\n  indented content"
- Use the exact field names listed — no synonyms, no omissions

Missing or misformatted fields cause your output to be rejected and re-requested.
```

---

## Gap 3: Worktree Isolation

### Problem

Agents write directly to the active working tree. A mid-run failure leaves partial, uncommitted changes that pollute the branch and conflict on the next run.

### Fix

Every run creates a `git worktree`. All agents operate in the worktree path. On success the worktree is committed and removed. On failure it is preserved for inspection.

### Changes: hub Step 0

After branch creation (or confirming non-main branch):

```
1. Derive run-id:
   <branch-name-with-slashes-replaced-by-dashes>-<source-filename-without-extension>
   Example: branch "nob/user-profile" + spec "user-profile.md" → "nob-user-profile-user-profile"
   For workflows with no source file (Init, Venture, Refactor, Ideate): use <branch-name>-<workflow>

2. Run: git worktree add .nob/worktrees/<run-id> <branch-name>
   If worktree already exists at that path (resumed run): reuse it, skip creation.
   If a different run-id conflicts: append -2, -3, etc.
   If git worktree add fails for any other reason: print error and exit.

3. Store WORKTREE_PATH = .nob/worktrees/<run-id>
   Store WORKTREE_BRANCH = <branch-name>

4. Ensure these lines are in .gitignore at the repo root (append if absent):
   .nob/
   .nob/worktrees/

5. All subsequent agent dispatches replace "Working directory: {current path}"
   with "Working directory: {WORKTREE_PATH}"
```

### Worktree teardown — hub Step 4

```
After printing terminal summary:

If Overall status: PASS:
  Run: git -C {WORKTREE_PATH} add -A
  Run: git -C {WORKTREE_PATH} commit -m "nob: {run-id}"
  Run: git worktree remove .nob/worktrees/<run-id>
  Print: "Worktree committed and removed. Branch: {WORKTREE_BRANCH}"
  Print: "Next: git push -u origin {WORKTREE_BRANCH}"

If Overall status: FAIL or NEEDS REVIEW:
  Preserve the worktree — user may want to inspect changes or resume.
  Print: "Worktree preserved at .nob/worktrees/<run-id> for inspection."
  Print: "To clean up: git worktree remove .nob/worktrees/<run-id> --force"

If run is cancelled or hits an unrecoverable error:
  Run: git worktree remove .nob/worktrees/<run-id> --force
  Print: "Run cancelled — worktree cleaned up."
```

### Checkpoint additions

```json
{
  "worktree_path": ".nob/worktrees/<run-id>",
  "worktree_branch": "<branch-name>"
}
```

On Phase 0 resume: read `worktree_path` from checkpoint and restore WORKTREE_PATH. Do not create a new worktree if one already exists at that path.

---

## Gap 4: Timeout & Hang Recovery

### Problem

An agent that runs too wide (30+ file changes) or goes silent blocks the entire pipeline. There is no scope boundary, no distinct `timed_out` status, and no actionable recovery path for the user.

### Fix

Two layers: scope cap prevents runaway work upfront; output-based detection catches silent hangs. Both are cheap in Markdown.

### Scope cap — injected into every Backend and Frontend agent dispatch

```
SCOPE LIMIT
If completing this task requires touching more than 15 files, implement the
highest-priority items first (core logic, primary happy path, critical data
model changes). Stop before reaching the limit. List any remaining unimplemented
work under Deferred items: in your output block.
A focused partial result is better than a timeout with no output.
```

### Output-based detection — hub changes

```
If output block missing after first dispatch:
  → Re-dispatch once (existing behavior — unchanged)

If output block still missing after re-dispatch:
  → Mark status: timed_out in checkpoint
  → Store timed_out_at: "<phase>/<agent-name>"
  → Do NOT pass null output to downstream agents
  → Treat timed_out same as failed for pipeline flow:
     - Fan-out: skip slice, continue remaining slices
     - Single mode: stop pipeline, skip Reviewer
```

### Reviewer: Deferred items handling

```
Step 2.5 (new): Read Deferred items: field from [BACKEND-AGENT OUTPUT] and
[FRONTEND-AGENT OUTPUT]. For each deferred item, find the matching acceptance
criterion in [PM-AGENT OUTPUT]. Mark that criterion ⚠ partial with reason:
"deferred by agent due to scope limit". Add to Items for human review.
```

### Terminal summary additions

```
[if any slice or agent timed_out:]
Timed out:
  <slice-name>: timed out at <phase>/<agent-name>
  Re-run `/nob <spec-file>` to resume — checkpoint skips completed slices.

[if any slice or agent malformed:]
Malformed output:
  <slice-name>: <agent-name> returned invalid output block after two attempts
  Check agent output above, then re-run `/nob <spec-file>` to retry.
```

### Updated checkpoint schema

```json
{
  "run_id": "<branch>-<source>",
  "worktree_path": ".nob/worktrees/<run-id>",
  "worktree_branch": "<branch-name>",
  "workflow": "Spec→Code | Bug→Fix | API→Sync",
  "source": "<spec file path>",
  "phases_completed": [],
  "slices": {
    "<slice-name>": {
      "status": "pending | in_progress | completed | failed | timed_out | malformed",
      "timed_out_at": "<phase>/<agent-name> or null",
      "pm_output": null,
      "backend_output": null,
      "frontend_output": null
    }
  },
  "reviewer_output": null
}
```

---

## Files Changed

| File | Changes |
|---|---|
| `skills/nob/SKILL.md` | Step 0 worktree setup + teardown; hub output validation step; scope cap injection; `timed_out`/`malformed` handling; terminal summary updates; checkpoint schema |
| `skills/nob/backend-agent/SKILL.md` | Test execution step; `Test output:`, `Deferred items:` fields; output format rule |
| `skills/nob/frontend-agent/SKILL.md` | Same as backend-agent |
| `skills/nob/reviewer/SKILL.md` | Read `Test output:` verbatim; corroborate `Test results:`; handle `Deferred items:` as ⚠ partial |
| `skills/nob/planner/SKILL.md` | Output format rule |
| `skills/nob/pm-agent/SKILL.md` | Output format rule |
| `skills/nob/security-agent/SKILL.md` | Output format rule |

**Not changed:** `idea-framer`, `market-researcher`, `business-modeler`, `gtm-strategist`, `financial-modeler`, `venture-reviewer`, `init-agent`, `refactor-agent`, `ideation-agent` — all are early-exit workflows that bypass the main dev pipeline.

---

## Out of Scope

- CI/CD webhook trigger
- Auto-PR creation
- Cross-run memory
- Token cost reporting

These are High/Medium priority gaps addressed separately.
