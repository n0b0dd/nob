---
name: path-full
description: 'Full pipeline orchestration — Phase 0 resume scan, PM, Debug (Bug→Fix), Tech Lead or direct-dev, Docs, Reviewer. Dispatches the retry skill when the first review is not PASS. Emits [FULL PATH OUTPUT] followed by all agent output blocks.'
---

# Nob — Full Path

Dispatched by the Nob hub when ROUTE = full. Runs Phases 0 through 3 of the nob pipeline and dispatches the retry skill for Phase 3.5.

---

## Setup

Set SKILL_BASE_DIR from `Hub skill base dir:` in [INPUTS]. All sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md`.
Set WORKTREE_PATH from `Working directory:` in [INPUTS] (Phase 0 may update this from checkpoint).
Set WORKTREE_BRANCH from `Worktree branch:` in [INPUTS].
Set RUN_ID from `Run ID:` in [INPUTS].
Set IS_BUG_FIX from `Is bug fix:` in [INPUTS] (true | false).
Set PLAN_FLAG from `Plan flag:` in [INPUTS] (true | false; default: false).
Set TDD_FLAG from `TDD flag:` in [INPUTS] (true | false; default: false).
Set TEST_WRITER_MODEL from `Agent models: test-writer:` in [INPUTS] (default: haiku).
Set TDD_ACTIVE = false. Set TEST_WRITER_OUTPUT = "none". Set TDD_STATUS = "skipped".

Extract all agent models, checkpoint settings, marker path, run log path, and max retries from [INPUTS].

---

## Output Block Validation

After extracting any `[X OUTPUT]...[/X OUTPUT]` block from an agent result, apply before passing downstream.

Required fields per agent:

| Agent | Required fields |
|---|---|
| PM Agent | `Acceptance criteria:`, `Edge cases to handle:`, `Out of scope:`, `Ambiguities flagged:` |
| Dev Agent | `Units touched:`, `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:` |
| Reviewer | `Overall status:`, `Test results:`, `Contract check:`, `Security:`, `Migration safety:`, `Code quality:`, `Design compliance:`, `Criteria check:`, `Items for human review:` |
| Docs Agent | `Files documented:`, `Files skipped:`, `Total:` |
| Test Writer | `Units tested:`, `Test files written:`, `Tests written:`, `Framework detected:` |

**Validation steps:**
1. Check every required field appears as `FieldName:` on its own line within the extracted block.
2. If all present: proceed normally.
3. If any missing: re-dispatch the agent once, prepending: `"Your previous response was missing these required fields: [list]. Re-emit the complete [X OUTPUT] block with ALL required fields present. Do not omit any field even if its value is 'none' or 'n/a'."`
4. If still missing after re-dispatch: mark the agent `malformed`. Do not pass a malformed block downstream. Treat as `failed` for all pipeline flow decisions.

---

## Phase 0: Resume scan

If `Checkpoint enabled:` in [INPUTS] is false: set RESUME_COMPLETED_TASKS = value from [INPUTS] (or empty). Proceed to Phase 2.

Check whether `{Checkpoint path from [INPUTS]}checkpoint.json` exists using the Read tool.

If not found or unreadable: proceed to Phase 2 as a fresh run. RESUME_COMPLETED_TASKS = empty.

If found and valid JSON:
1. **Restore worktree**: if `worktree_path` is set in the checkpoint and differs from current WORKTREE_PATH, update WORKTREE_PATH to that value. If the path does not exist on disk: run `git worktree add {worktree_path} {worktree_branch}` to recreate it.
2. If `reviewer_output` is non-null → run already complete. Emit:
   ```
   [FULL PATH OUTPUT]
   Status: {Overall status from reviewer_output}
   Impl path: {impl_path from checkpoint, or: unknown}
   Retry count: 0
   Retry ran: false
   Retry exit reason: none
   Agents run: (restored from checkpoint)
   Timing: (restored from checkpoint)
   [/FULL PATH OUTPUT]
   ```
   Then re-emit all stored output blocks from the checkpoint verbatim. Exit — do not re-run any phases.
3. If `"phase2"` is in `phases_completed` AND `reviewer_output` is null → build RESUME_COMPLETED_TASKS from the checkpoint `tasks` map: collect all task ids whose status is `"completed"`. Tasks with `"pending"`/`"in_progress"` (and tasks not in the map) will be re-run. Also read `plan_approval` from the checkpoint — if `plan_approval.status = "approved"`: set PLAN_APPROVAL_DONE = true (skip the approval gate in Phase 2). If absent or status is not "approved": PLAN_APPROVAL_DONE = false.
4. If `phases_completed` is empty: RESUME_COMPLETED_TASKS = empty. PLAN_APPROVAL_DONE = false. Fresh run.

If found but not valid JSON: print `"Warning: checkpoint corrupted — starting fresh."` RESUME_COMPLETED_TASKS = empty. Proceed to Phase 2.

---

## Phase 2: Tech Lead → dev pipeline

### Unit-boundary marker write

If `Unit boundary enabled:` is true AND the `Units:` list in [INPUTS] is non-empty:

Write `{Marker path from [INPUTS]}` using the Write tool. Content:
```json
{ "worktree": "{WORKTREE_PATH}", "allow": ["{each unit path from [INPUTS], one per element}", ".nob/", "docs/specs/", "docs/design/", "docs/bugs/", ".nob.yml"] }
```
Use the actual unit paths from [INPUTS] `Units:` list. If the write fails: skip silently.

### Initial checkpoint write

If `Checkpoint enabled:` is true and no checkpoint file exists (fresh run only):

Write `{Checkpoint path}checkpoint.json`:
```json
{ "spec_path": "{Spec file path from [INPUTS]}", "worktree_path": "{WORKTREE_PATH}", "worktree_branch": "{WORKTREE_BRANCH}", "phases_completed": [], "tasks": {} }
```

---

### Agent 1 — PM Agent

Run `date +%s` → PM_START_EPOCH.

Read `{SKILL_BASE_DIR}/../pm/SKILL.md`. Dispatch with `model: {pm model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}
Spec file path: {Spec file path from [INPUTS]}
Spec file contents:
{Spec file contents from [INPUTS]}

Project memory:
{Project memory from [INPUTS]}
[/INPUTS]
```

Extract `[PM OUTPUT]...[/PM OUTPUT]`. Store as PM_OUTPUT. Apply Output Block Validation.

Run `date +%s` → PM_END_EPOCH. PM_DURATION_MS = (PM_END_EPOCH - PM_START_EPOCH) × 1000.
Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  pm              {pm model}  OK    {PM_DURATION_MS}ms`

---

### Agent 1.5 — Debug diagnosis + routing (Bug→Fix only)

Skip this section entirely if IS_BUG_FIX is false. Set DEBUG_OUTPUT = "none". Set IMPL_PATH = "tech-lead". Skip to **Agent 2**.

1. Run `date +%s` → DEBUG_START_EPOCH.
2. Read `{SKILL_BASE_DIR}/../debug/SKILL.md`. Dispatch with `model: {debug model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../debug/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Per-unit stack-guidance path map:
{Per-unit stack-guidance path map from [INPUTS]}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

Bug report:
{Spec file contents from [INPUTS]}

Project memory:
{Project memory from [INPUTS]}
[/INPUTS]
```

3. Extract `[DEBUG OUTPUT]...[/DEBUG OUTPUT]`. Store as DEBUG_OUTPUT. Print it verbatim.
   If missing: re-dispatch once. If still missing: set DEBUG_OUTPUT = "none". Set IMPL_PATH = "tech-lead". Skip to step 6.
4. Run `date +%s` → DEBUG_END_EPOCH. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  debug           {debug model}  OK    {(DEBUG_END_EPOCH-DEBUG_START_EPOCH)×1000}ms`
5. **Routing decision** — set ESCALATE = true if ANY of: ≥2 affected units in `Affected units:`, `Risks:` contains `[BREAKING]`/`[MIGRATION]`/`[AUTH]`, `Confidence:` line starts with `low`, or >4 files listed in `Recommended fix:`. Set IMPL_PATH = "tech-lead" if ESCALATE, else "direct-dev". Print one line: `Bug fix path: {IMPL_PATH} ({reason})`.
6. **Risk gate** (only when ESCALATE is true and `[AUTH]` or `[BREAKING]` is in `Risks:`): print the offending risk line(s) and `Recommended fix:` section, then prompt: `"This fix touches [AUTH/BREAKING]. Proceed? (yes / no)"`. Wait. If `no` or non-yes: print `"Halted before code changes — worktree preserved at {WORKTREE_PATH}."` Exit. If `yes`: continue (IMPL_PATH is already "tech-lead").

---

### Agent 2 — Implementation

Run `date +%s` → TL_START_EPOCH. Branch on IMPL_PATH.

#### Path A — Tech Lead (feature builds and complicated bug fixes)

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch with `model: {tech-lead model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../tech-lead/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Per-unit stack-guidance path map:
{Per-unit stack-guidance path map from [INPUTS]}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

Workflow: {Workflow from [INPUTS]}

Spec file path: {Spec file path from [INPUTS]}
Spec file contents:
{Spec file contents from [INPUTS]}

PM Agent output:
{PM_OUTPUT}

{if DEBUG_OUTPUT is not "none":
Debug diagnosis:
{DEBUG_OUTPUT}
}

Project memory:
{Project memory from [INPUTS]}

Agent models:
  dev: {dev model from [INPUTS]}
  debug: {debug model from [INPUTS]}
  designer: {designer model from [INPUTS]}
  test-writer: {test-writer model from [INPUTS], or: haiku}

TDD flag: {TDD_FLAG — true | false}
Agents enabled: {Agents enabled from [INPUTS], comma-separated}

Max parallel slices: {Max parallel slices from [INPUTS]}

Already-completed tasks (skip these task ids): {RESUME_COMPLETED_TASKS, or: none}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]...[/TECH LEAD OUTPUT]`. Store as TECH_LEAD_OUTPUT. Apply Output Block Validation.
Extract `[DESIGNER OUTPUT]...[/DESIGNER OUTPUT]` if present. Store as DESIGNER_OUTPUT (or "none" if absent).
Extract `[TEST WRITER OUTPUT]...[/TEST WRITER OUTPUT]` if present. Store as TEST_WRITER_OUTPUT (or "none" if absent). If present and not "skipped": set TDD_ACTIVE = true. Extract TDD_TEST_FILES = comma-separated paths from the `Test files written:` section of TEST_WRITER_OUTPUT (or "none" if absent). Otherwise: set TDD_ACTIVE = false, TDD_TEST_FILES = "none".

#### Plan approval gate (Path A only)

Skip this section if PLAN_FLAG = false OR PLAN_APPROVAL_DONE = true.

If PLAN_FLAG = true AND PLAN_APPROVAL_DONE = false:

Set PLAN_EDIT_COUNT = 0.

**Render plan summary**:

1. Extract the `Tasks:` list from TECH_LEAD_OUTPUT. For each task, print one line:
   `[{unit}] {task-id}: {description} (files: {files})`
   If the task list is absent or malformed, print `(incomplete plan — task list not available)` and continue.
2. Extract `Risks:` from TECH_LEAD_OUTPUT. If non-empty and not `none`, print:
   ```
   Risks:
   {Risks block from TECH_LEAD_OUTPUT}
   ```
3. Prompt: `"Proceed with this plan? (yes / edit / cancel)"`

**Branch on response**:

- **yes**: set PLAN_APPROVAL_DONE = true. Continue to Dev dispatch.

- **edit**: if PLAN_EDIT_COUNT >= 1: print `"One edit re-dispatch already used."` and prompt `"Proceed with current plan or cancel? (proceed / cancel)"`. If `proceed`: set PLAN_APPROVAL_DONE = true; continue. If `cancel` or any non-proceed: go to **cancel** branch below.
  Otherwise (PLAN_EDIT_COUNT = 0):
  1. Ask: `"Describe your modification:"`. Store as PLAN_EDIT_INTENT.
  2. Re-dispatch Tech Lead with the same prompt from Agent 2 Path A, appending to [INPUTS]: `"User plan modification request: {PLAN_EDIT_INTENT} — revise the task list and contracts to incorporate this change."`.
  3. Extract new `[TECH LEAD OUTPUT]`. If extraction fails or validation fails after one re-dispatch: print `"Edit re-dispatch failed."` and prompt `"Retry edit or proceed with original plan? (retry / proceed / cancel)"`. If `retry`: repeat the re-dispatch once more; if still fails, prompt again with only `(proceed / cancel)`. If `proceed`: use original TECH_LEAD_OUTPUT and continue to Dev. If `cancel`: go to **cancel** branch.
  4. Increment PLAN_EDIT_COUNT. Re-render plan summary and prompt again.

- **cancel** (or any non-yes/non-edit response): print `"Run cancelled at plan approval — no changes made."`. Write to `{Checkpoint path}checkpoint.json`: set `plan_approval` to `{ "status": "cancelled", "edits": {PLAN_EDIT_COUNT} }`. Run `git worktree remove {WORKTREE_PATH} --force` (ignore errors). Exit — do not proceed to Dev or any further phase.

**Write approval to checkpoint**: after approval (yes or edit→proceed), if `Checkpoint enabled:` is true: read `{Checkpoint path}checkpoint.json`, set `plan_approval` to `{ "status": "approved", "edits": {PLAN_EDIT_COUNT} }`, write back. Set PLAN_APPROVAL_DONE = true.

Note: if `--plan` and `--tdd` are both active, this approval gate runs after TL and before the test-writer phase (i.e., before Dev dispatch), preserving the `--tdd` test-writing step that follows Dev.

Append to RUN_LOG_PATH: a `tech-lead` line.

#### Dev dispatch (Path A)

Run `date +%s` → DEV_START_EPOCH.

Read `{SKILL_BASE_DIR}/../dev/SKILL.md`. Dispatch with `model: {dev model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../dev/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Per-unit stack-guidance path map:
{Per-unit stack-guidance path map from [INPUTS]}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

[TECH LEAD SPEC]
Interfaces / contracts:
{Interfaces written: section from TECH_LEAD_OUTPUT}

Data schemas:
{Data schemas written: section from TECH_LEAD_OUTPUT}

Task list:
{Task list: section from TECH_LEAD_OUTPUT — all entries in canonical format}

Risks:
{Risks: section from TECH_LEAD_OUTPUT}
[/TECH LEAD SPEC]

Acceptance criteria:
{Acceptance criteria section from PM_OUTPUT}

{if DESIGNER_OUTPUT is not "none":
Designer output:
{DESIGNER_OUTPUT}
}

TDD mode: {TDD_ACTIVE — true | false}
TDD test files: {TDD_TEST_FILES, or: none}

Project memory:
{Project memory from [INPUTS]}

Max parallel slices: {Max parallel slices from [INPUTS]}

Already-completed tasks (skip these task ids): {RESUME_COMPLETED_TASKS, or: none}
[/INPUTS]
```

Extract `[DEV OUTPUT]...[/DEV OUTPUT]`. Store as DEV_OUTPUT. Apply Output Block Validation. If missing after one re-dispatch: mark `failed`. Stop pipeline.

Run `date +%s` → DEV_END_EPOCH.

**Set TDD_STATUS** (after Dev returns):
- If TDD_ACTIVE = true and DEV_OUTPUT test results all PASS: TDD_STATUS = "Red ✓ → Green ✓".
- If TDD_ACTIVE = true and any test FAIL: TDD_STATUS = "Red ✓ → Green ✗".
- If TDD_ACTIVE = true and no test results: TDD_STATUS = "Red ✓ → Green ?" (Reviewer will verify).
- If TDD_ACTIVE = false: TDD_STATUS = "skipped".

Append to RUN_LOG_PATH: a `dev` line. Proceed to **Common**.

#### Path B — Direct dev (localized bug fixes)

Skip Tech Lead. Build a minimal `[TECH LEAD SPEC]` from DEBUG_OUTPUT:

1. From `Recommended fix:` in DEBUG_OUTPUT, extract one task per file listed:
   ```
   - id: t{N}
     title: fix {basename}
     description: {recommended change for that file; if "Suggested regression test:" is not "none", append "Also add the suggested regression test: {test description}."}
     unit: {[unit] tag on that line}
     files: {path on that line}
     depends_on: []
   ```
2. Set IMPL_RISKS = `Risks:` section from DEBUG_OUTPUT (or "none").
3. Read `{SKILL_BASE_DIR}/../dev/SKILL.md`. Dispatch ONE dev Agent with `model: {dev model from [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../dev/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Per-unit stack-guidance path map:
{Per-unit stack-guidance path map from [INPUTS]}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

[TECH LEAD SPEC]
Interfaces / contracts:
none

Data schemas:
none

Task list:
{task list constructed above}

Risks:
{IMPL_RISKS}
[/TECH LEAD SPEC]

Acceptance criteria:
{Acceptance criteria section from PM_OUTPUT}

Bug diagnosis (root cause — implement the fix it recommends):
{DEBUG_OUTPUT}

Project memory:
{Project memory from [INPUTS]}

Max parallel slices: {Max parallel slices from [INPUTS]}

Already-completed tasks (skip these task ids): {RESUME_COMPLETED_TASKS, or: none}
[/INPUTS]
```

4. Extract `[DEV OUTPUT]...[/DEV OUTPUT]`. Store as DEV_OUTPUT. Apply Output Block Validation. If missing: re-dispatch once; if still missing: mark `failed`. Stop pipeline.
5. Set DESIGNER_OUTPUT = "none".
6. Synthesize TECH_LEAD_OUTPUT (stub — satisfies Reviewer contract check):
   ```
   [TECH LEAD OUTPUT]
   Affected units: {Affected units from DEBUG_OUTPUT}
   Interfaces written:
   - none
   Data schemas written:
   - none
   Task count: {N from constructed task list}
   Risks:
   {IMPL_RISKS}
   Escalations made:
   - none
   Unresolved blockers:
   - none
   Contract violations:
   - none
   Note: direct-dev path (localized bug fix) — Tech Lead skipped; diagnosis in [DEBUG OUTPUT].
   [/TECH LEAD OUTPUT]
   ```
7. Append to RUN_LOG_PATH: a `dev` line only (no tech-lead line). Proceed to **Common**.

#### Common: checkpoint + timing

Set IMPL_OUTPUT = DEV_OUTPUT.

If `Checkpoint enabled:` is true:
- Parse `Tasks:` list from DEV_OUTPUT. Build TASK_STATUS map: `done` → `"completed"`, `partial`/`failed` → `"pending"`.
- Read `{Checkpoint path}checkpoint.json`. Set its `tasks` field to TASK_STATUS. Append `"phase2"` to `phases_completed` if not already present. Write back. If write fails: skip silently.

Run `date +%s` → TL_END_EPOCH. TL_DURATION_MS = (TL_END_EPOCH - TL_START_EPOCH) × 1000.
Append run-log lines for the path taken: `{date -u +%FT%TZ}  {agent}         {model}  OK    {TL_DURATION_MS}ms`.

---

## Phase 2.5: Docs

If `docs` is explicitly NOT in `Agents enabled:` from [INPUTS] (and the list is explicitly set): set DOCS_OUTPUT = "none". Skip to Phase 3.

**Skip when no new contracts**: check `Contracts produced:` in DEV_OUTPUT. If the field is absent, `none`, or contains only `- none` entries: set DOCS_OUTPUT = "none" and skip to Phase 3. Docs adds no value when no new API surface was produced.

Otherwise (default is enabled):

Run `date +%s` → DOCS_START_EPOCH.

Read `{SKILL_BASE_DIR}/../docs/SKILL.md`. Dispatch with `model: {docs model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../docs/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Dev output:
{DEV_OUTPUT}

Units:
{Units from [INPUTS] — one per line as "- name: {name}, type: {type}, path: {path}"}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

Project memory:
{Project memory from [INPUTS]}

Standalone target: none
[/INPUTS]
```

Extract `[DOCS OUTPUT]...[/DOCS OUTPUT]`. Store as DOCS_OUTPUT. Apply Output Block Validation.
If missing after one re-dispatch: set DOCS_OUTPUT = "none". Note `docs: failed` for the output block. A failed docs agent must not block the pipeline.

Run `date +%s` → DOCS_END_EPOCH. DOCS_DURATION_MS = (DOCS_END_EPOCH - DOCS_START_EPOCH) × 1000.
Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  docs            {docs model}  OK    {DOCS_DURATION_MS}ms`.

---

## Phase 3: Review

Run `date +%s` → REVIEWER_START_EPOCH.

Read `{SKILL_BASE_DIR}/../reviewer/SKILL.md`. Dispatch with `model: {reviewer model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}
Spec file path: {Spec file path from [INPUTS]}
Spec file contents:
{Spec file contents from [INPUTS]}

TDD flag: {TDD_FLAG — true | false}
TDD test files: {TDD_TEST_FILES — comma-separated paths from TEST_WRITER_OUTPUT "Test files written:", or: none}

All agent outputs for review:

{TECH_LEAD_OUTPUT}

{PM_OUTPUT}

{DEV_OUTPUT}

{if DESIGNER_OUTPUT is not "none":
{DESIGNER_OUTPUT}
}

{if DOCS_OUTPUT is not "none":
{DOCS_OUTPUT}
}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply Output Block Validation.

Run `date +%s` → REVIEWER_END_EPOCH. REVIEWER_DURATION_MS = (REVIEWER_END_EPOCH - REVIEWER_START_EPOCH) × 1000.

If `Checkpoint enabled:` is true: read `{Checkpoint path}checkpoint.json`, set `reviewer_output` to full REVIEWER_OUTPUT string, write back.

Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  reviewer        {reviewer model}  OK    {REVIEWER_DURATION_MS}ms`.

---

## Phase 3.5: Retry (if needed)

If `Overall status:` from REVIEWER_OUTPUT is PASS: set RETRY_OUTPUT_META = none. Skip this phase.

If not PASS: dispatch the retry skill.

Read `{SKILL_BASE_DIR}/retry/SKILL.md`. Dispatch with `model: {dev model from Agent models in [INPUTS]}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/retry/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}
Run ID: {RUN_ID}
Hub skill base dir: {SKILL_BASE_DIR}

Workflow: {Workflow from [INPUTS]}
Is bug fix: {Is bug fix from [INPUTS]}
Spec file path: {Spec file path from [INPUTS]}
Spec file contents:
{Spec file contents from [INPUTS]}

Per-unit stack-guidance path map:
{Per-unit stack-guidance path map from [INPUTS]}

.nob.yml contents:
{.nob.yml contents from [INPUTS]}

CLAUDE.md contents:
{CLAUDE.md contents from [INPUTS]}

Agent models:
{Agent models block from [INPUTS] verbatim}

Max parallel slices: {Max parallel slices from [INPUTS]}
Max retries: {Max retries from [INPUTS]}
Units: {Units from [INPUTS]}
Project memory: {Project memory from [INPUTS]}

PM output:
{PM_OUTPUT}

Debug output:
{DEBUG_OUTPUT}

Designer output:
{DESIGNER_OUTPUT}

Current reviewer output:
{REVIEWER_OUTPUT}

Current dev output:
{DEV_OUTPUT}

Current tech lead output:
{TECH_LEAD_OUTPUT}
[/INPUTS]
```

Extract `[RETRY OUTPUT]...[/RETRY OUTPUT]`. Store as RETRY_OUTPUT_META.
Extract updated `[TECH LEAD OUTPUT]` → update TECH_LEAD_OUTPUT.
Extract updated `[DEV OUTPUT]` → update DEV_OUTPUT.
Extract updated `[REVIEWER OUTPUT]` → update REVIEWER_OUTPUT.

If `Checkpoint enabled:` is true after retry: update checkpoint `tasks` map from new DEV_OUTPUT and update `reviewer_output` from new REVIEWER_OUTPUT. Write back.

---

## Emit output

If `Overall status: PASS`:
- `git -C {WORKTREE_PATH} add -A`
- `git -C {WORKTREE_PATH} commit -m "nob: {RUN_ID}"`

Compute RETRY_COUNT and RETRY_RAN from RETRY_OUTPUT_META (or 0 / false if retry was not dispatched).
Compute RETRY_EXIT_REASON from RETRY_OUTPUT_META `Exit reason:` field (or "none" if retry was not dispatched).

Build AGENTS_RUN and TIMING strings:
- Feature build (IS_BUG_FIX = false): `pm({pm model}) [· designer({designer model}) if DESIGNER_OUTPUT is not "none"] · tech-lead({tech-lead model}) [· test-writer({test-writer model}) if TEST_WRITER_OUTPUT is not "none"] · dev({dev model}) [· docs({docs model}) if DOCS_OUTPUT is not "none"] · reviewer({reviewer model})`
- Bug→Fix direct-dev: `pm({pm model}) · debug({debug model}) · dev({dev model}) [· docs({docs model})] · reviewer({reviewer model})`
- Bug→Fix escalated (IMPL_PATH = tech-lead): `pm({pm model}) · debug({debug model}) · tech-lead({tech-lead model}) [· test-writer({test-writer model}) if TEST_WRITER_OUTPUT is not "none"] · dev({dev model}) [· docs({docs model})] · reviewer({reviewer model})`

Emit:

```
[FULL PATH OUTPUT]
Status: {Overall status from final REVIEWER_OUTPUT}
Impl path: {IMPL_PATH — tech-lead | direct-dev}
Retry count: {RETRY_COUNT}
Retry ran: {true | false}
Retry exit reason: {RETRY_EXIT_REASON — none | pass | stuck | max-retries | user-declined | no-failing-tasks | tech-lead-failed}
Agents run: {AGENTS_RUN string}
Timing: pm {round(PM_DURATION_MS/1000)}s{· debug {round(DEBUG_DURATION/1000)}s if ran} · {tech-lead {round(TL_DURATION_MS/1000)}s if ran} · dev {round(TL_DURATION_MS/1000)}s{· docs {round(DOCS_DURATION_MS/1000)}s if ran} · reviewer {round(REVIEWER_DURATION_MS/1000)}s
Plan approval: {approved (no edits) | approved (N edits) | cancelled | n/a — from plan_approval in checkpoint, or n/a if PLAN_FLAG = false}
TDD status: {TDD_STATUS — "Red ✓ → Green ✓" | "Red ✓ → Green ✗" | "skipped"}
[/FULL PATH OUTPUT]
```

Then emit all agent output blocks verbatim so the hub can extract them:

```
[PM OUTPUT]
{PM_OUTPUT}
[/PM OUTPUT]

[DEBUG OUTPUT]
{DEBUG_OUTPUT — omit this block entirely if DEBUG_OUTPUT = "none"}
[/DEBUG OUTPUT]

[TECH LEAD OUTPUT]
{TECH_LEAD_OUTPUT}
[/TECH LEAD OUTPUT]

[DEV OUTPUT]
{DEV_OUTPUT}
[/DEV OUTPUT]

[DESIGNER OUTPUT]
{DESIGNER_OUTPUT — omit this block entirely if DESIGNER_OUTPUT = "none"}
[/DESIGNER OUTPUT]

[TEST WRITER OUTPUT]
{TEST_WRITER_OUTPUT — omit this block entirely if TEST_WRITER_OUTPUT = "none"}
[/TEST WRITER OUTPUT]

[DOCS OUTPUT]
{DOCS_OUTPUT — omit this block entirely if DOCS_OUTPUT = "none"}
[/DOCS OUTPUT]

[REVIEWER OUTPUT]
{REVIEWER_OUTPUT}
[/REVIEWER OUTPUT]
```
