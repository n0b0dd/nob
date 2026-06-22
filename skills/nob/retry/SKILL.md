---
name: retry
description: 'Retry loop for nob pipelines. Receives current reviewer findings and all prior agent outputs, coordinates tech-lead + dev re-run + reviewer re-check, loops until PASS / stuck / max-retries / user-declined / no-failing-tasks. Always routes through Tech Lead — even if the original run used direct-dev. Emits [RETRY OUTPUT] followed by updated [TECH LEAD OUTPUT], [DEV OUTPUT], and [REVIEWER OUTPUT] blocks.'
---

# Nob — Retry Loop

Dispatched by `path-full` after an initial Reviewer FAIL or NEEDS REVIEW result. Runs Phase 3.5 of the nob pipeline.

---

## Setup

Set SKILL_BASE_DIR from `Hub skill base dir:` in [INPUTS]. All sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md`.
Set WORKTREE_PATH from `Working directory:` in [INPUTS].
Set MAX_RETRIES from `Max retries:` in [INPUTS] (default: 3).
Set RETRY_COUNT = 0.
Set PREV_RETRY_ITEMS = [].
Set RETRY_RAN = false.

Restore current agent outputs from the labeled sections in [INPUTS]:
- REVIEWER_OUTPUT = content of `Current reviewer output:` section
- DEV_OUTPUT = content of `Current dev output:` section
- TECH_LEAD_OUTPUT = content of `Current tech lead output:` section
- PM_OUTPUT = content of `PM output:` section
- DEBUG_OUTPUT = content of `Debug output:` section (or "none" if absent)
- DESIGNER_OUTPUT = content of `Designer output:` section (or "none" if absent)

---

## Loop

Repeat until an exit condition is reached.

### 1. Check overall status

Extract `Overall status:` from REVIEWER_OUTPUT.

If `Overall status: PASS`: set RETRY_RAN = (RETRY_COUNT > 0). **Exit → exit_reason = pass.**

### 2. Collect failing items

RETRY_ITEMS = union of all `✗` criterion lines + all `⚠` criterion lines + all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

### 3. Stuck check (skip when RETRY_COUNT == 0)

If RETRY_COUNT > 0 AND RETRY_ITEMS is identical to PREV_RETRY_ITEMS:
  Set RETRY_RAN = true.
  Print:
  ```
  Retry stuck — same {N} failure(s) appeared in two consecutive passes:
    {RETRY_ITEMS listed one per line}
  Human review required before continuing.
  ```
  **Exit → exit_reason = stuck.**

### 4. Max retries check

If RETRY_COUNT >= MAX_RETRIES:
  Set RETRY_RAN = true.
  Print: `Max retries ({MAX_RETRIES}) reached. Human review required.`
  **Exit → exit_reason = max-retries.**

### 5. Determine failing tasks

For each `✗` or `⚠` criterion line in RETRY_ITEMS:
- Extract the unit name tagged at the end of the line (e.g. `[api]`, `[web]`, `[cli]`).
- Map unit name → task ids by scanning DEV_OUTPUT `Tasks:` list for entries whose `(unit: name)` matches. Collect the union as FAILING_TASK_IDS.
- If a criterion has no unit tag: add all task ids from DEV_OUTPUT to FAILING_TASK_IDS and note "no unit tag — re-dispatching all tasks".

For any CONTRACT VIOLATION in REVIEWER_OUTPUT `Contract check:`:
- Add all task ids for affected units to FAILING_TASK_IDS.
- Set CONTRACT_RETRY = true.

If FAILING_TASK_IDS is empty: **exit → exit_reason = no-failing-tasks.**

### 6. User gate

If RETRY_COUNT == 0:
  Print (no prompt — proceed automatically):
  ```
  Reviewer found {N} item(s) — auto-fixing (pass 1/{MAX_RETRIES}):
    {RETRY_ITEMS listed one per line}
  ```
Else:
  Print:
  ```
  Still failing after pass {RETRY_COUNT}/{MAX_RETRIES}:
    {RETRY_ITEMS listed one per line}

  Retry again? (yes / no)
  ```
  Wait for user response. If `no` or any non-yes: **exit → exit_reason = user-declined.**

### 7. Update loop state

Set PREV_RETRY_ITEMS = RETRY_ITEMS.
Set RETRY_RAN = true.

### 8. Retry diagnostic (haiku)

Dispatch a sub-agent with `model: haiku`:

```
[INSTRUCTIONS]
You are a focused retry diagnostic agent. For each failing item, identify which 1–2 files are most directly responsible. Do NOT implement anything. Do NOT read any file not listed in the inputs.

Emit exactly:

[RETRY-DIAGNOSTIC OUTPUT]
Fix scope per unit:
  [{unit-name}]:
    - {path}: {one sentence — what specifically needs to change}
  (repeat per failing unit; use "none" if no specific file identified)

Root cause summary: {1–2 sentences}
[/RETRY-DIAGNOSTIC OUTPUT]
[/INSTRUCTIONS]

[INPUTS]
Failing items:
{RETRY_ITEMS listed one per line}

Failing task ids / units:
{FAILING_TASK_IDS listed one per line}

Files changed per unit from previous pass:
{for each [unit] tag in DEV_OUTPUT "Files changed:" section: list the paths, or: none}
[/INPUTS]
```

Extract `[RETRY-DIAGNOSTIC OUTPUT]...[/RETRY-DIAGNOSTIC OUTPUT]`. Store as DIAG_OUTPUT. If extraction fails: DIAG_OUTPUT = null.

Parse `Fix scope per unit:` as UNIT_FIX_SCOPE (unit name → list of paths). If DIAG_OUTPUT is null: UNIT_FIX_SCOPE = {}.

### 9. Tech Lead retry

Always routes through Tech Lead — a localized fix that failed review is more complex than originally judged.

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

Max parallel slices: {Max parallel slices from [INPUTS]}

Already-completed tasks (skip these task ids): none

Reviewer found these failures — re-implement only the failing tasks:
{RETRY_ITEMS listed one per line}

Failing task ids to re-implement:
{FAILING_TASK_IDS listed one per line}

{if UNIT_FIX_SCOPE is non-empty:
Fix scope per unit (touch only these files):
{for each unit in UNIT_FIX_SCOPE: "  [{unit}]:\n    - {paths, one per line}"}
}

Root cause (from diagnostic):
{DIAG_OUTPUT "Root cause summary:" line, or: "Diagnostic not available — use your judgment"}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]...[/TECH LEAD OUTPUT]` → update TECH_LEAD_OUTPUT.
Extract `[DEV OUTPUT]...[/DEV OUTPUT]` → update DEV_OUTPUT.
If DEV_OUTPUT is missing: re-dispatch Tech Lead once with the same prompt. If still missing: **exit → exit_reason = tech-lead-failed.**

### 10. Re-dispatch Reviewer

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

All agent outputs for review:

{TECH_LEAD_OUTPUT}

{PM_OUTPUT}

{DEV_OUTPUT}

{if DESIGNER_OUTPUT is not "none":
{DESIGNER_OUTPUT}
}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]` → update REVIEWER_OUTPUT.

### 11. Increment and loop

Increment RETRY_COUNT. Return to step 1.

---

## Output

After the loop exits, emit:

```
[RETRY OUTPUT]
Status: {Overall status from final REVIEWER_OUTPUT — PASS | NEEDS REVIEW | FAIL}
Exit reason: {pass | stuck | max-retries | user-declined | no-failing-tasks | tech-lead-failed}
Retry count: {RETRY_COUNT}
Retry ran: {true | false}
[/RETRY OUTPUT]
```

Then emit the current TECH_LEAD_OUTPUT, DEV_OUTPUT, and REVIEWER_OUTPUT blocks verbatim (so path-full can extract the updated outputs):

```
[TECH LEAD OUTPUT]
{current TECH_LEAD_OUTPUT content}
[/TECH LEAD OUTPUT]

[DEV OUTPUT]
{current DEV_OUTPUT content}
[/DEV OUTPUT]

[REVIEWER OUTPUT]
{current REVIEWER_OUTPUT content}
[/REVIEWER OUTPUT]
```
