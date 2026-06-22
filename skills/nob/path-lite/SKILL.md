---
name: path-lite
description: 'Lite path orchestration for single-unit changes (4–10 files). Hub dispatches here when ROUTE = lite. Does PM + Tech Lead reasoning inline (no sub-agents for those roles), dispatches one Dev agent, then Reviewer, with one automatic retry pass. Emits [LITE PATH OUTPUT].'
---

# Nob — Lite Path

Dispatched by the Nob hub when ROUTE = lite. Reasons through PM and Tech Lead inline, then dispatches Dev + Reviewer sub-agents.

---

## Setup

Set SKILL_BASE_DIR from `Hub skill base dir:` in [INPUTS]. All sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md`.
Set WORKTREE_PATH from `Working directory:` in [INPUTS].
Set RUN_ID from `Run ID:` in [INPUTS].
Set RETRY_COUNT = 0.

---

## Output Block Validation

After extracting any `[X OUTPUT]...[/X OUTPUT]` block from an agent result, apply this before passing it downstream.

Required fields per agent:

| Agent | Required fields |
|---|---|
| Dev Agent | `Units touched:`, `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:` |
| Reviewer | `Overall status:`, `Test results:`, `Contract check:`, `Security:`, `Migration safety:`, `Code quality:`, `Design compliance:`, `Criteria check:`, `Items for human review:` |

**Validation steps:**
1. Check every required field appears as `FieldName:` on its own line.
2. If all present: proceed normally.
3. If any missing: re-dispatch the agent once, prepending: `"Your previous response was missing these required fields: [list]. Re-emit the complete [X OUTPUT] block with ALL required fields present. Do not omit any field even if its value is 'none' or 'n/a'."`
4. If still missing after re-dispatch: mark the agent as `malformed`. Do not pass a malformed block downstream. Treat as `failed` for pipeline flow decisions.

---

## Step 1: Inline PM reasoning

Do not dispatch a PM sub-agent. Derive requirements from `User intent:`, `Spec file contents:`, and `Affected files:` in [INPUTS].

Produce and store as PM_OUTPUT:

```
[PM OUTPUT]
Acceptance criteria:
- {what "done" looks like — one criterion per line}
Edge cases to handle:
- {what could go wrong, or: none}
Out of scope:
- {explicitly excluded items, or: none}
Ambiguities flagged:
- {unclear requirements, or: none}
[/PM OUTPUT]
```

---

## Step 2: Inline Tech Lead reasoning

Do not dispatch a Tech Lead sub-agent. Derive a flat task list from `Affected files:`, `Affected units:`, and `User intent:` in [INPUTS].

Tasks should map one-to-one with affected files or closely related groups. Use ids `t1`, `t2`, … in order.

Produce and store as TECH_LEAD_OUTPUT:

```
[TECH LEAD OUTPUT]
Affected units: {unit names from [INPUTS], comma-separated}
Interfaces written:
- none
Data schemas written:
- none
Task count: {N}
Tasks:
  - id: t1
    title: {short title}
    description: {what to change and how — be specific about the exact edit}
    unit: {unit name}
    files: {file path(s)}
    depends_on: []
  {repeat for each task}
Risks:
- none
Escalations made:
- none
Unresolved blockers:
- none
Contract violations:
- none
Note: lite path — PM and Tech Lead reasoning done inline by hub; no sub-agents dispatched for those roles.
[/TECH LEAD OUTPUT]
```

---

## Step 3: Dispatch Dev

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
none

Data schemas:
none

Task list:
{Tasks section from TECH_LEAD_OUTPUT}

Risks:
none
[/TECH LEAD SPEC]

Acceptance criteria:
{Acceptance criteria section from PM_OUTPUT}

Project memory:
{Project memory from [INPUTS]}

Max parallel slices: 1
Already-completed tasks: none
[/INPUTS]
```

Extract `[DEV OUTPUT]...[/DEV OUTPUT]`. Store as DEV_OUTPUT. Apply Output Block Validation.
If missing after one re-dispatch: mark failed; emit [LITE PATH OUTPUT] with `Status: FAIL` and `Failure: dev agent returned no output` and exit.

Run `date +%s` → DEV_END_EPOCH. Compute DEV_DURATION_MS = (DEV_END_EPOCH - DEV_START_EPOCH) × 1000.

---

## Step 4: Dispatch Reviewer

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

All agent outputs for review:
{TECH_LEAD_OUTPUT}
{PM_OUTPUT}
{DEV_OUTPUT}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply Output Block Validation.

Run `date +%s` → REVIEWER_END_EPOCH. Compute REVIEWER_DURATION_MS = (REVIEWER_END_EPOCH - REVIEWER_START_EPOCH) × 1000.

---

## Step 5: Auto-retry (1 pass, no user gate)

If `Overall status:` from REVIEWER_OUTPUT is not PASS and RETRY_COUNT < 1:

1. Collect RETRY_ITEMS = all `✗` and `⚠` lines from REVIEWER_OUTPUT.
2. Print: `Reviewer found {N} item(s) — auto-fixing (1 pass, lite path):\n{RETRY_ITEMS}`
3. Re-dispatch Dev with the same prompt from Step 3, prepending to `[INPUTS]`: `"Reviewer found these failures — fix only these:\n{RETRY_ITEMS}"`.
4. Extract new DEV_OUTPUT. Apply Output Block Validation.
5. Re-dispatch Reviewer with the same prompt from Step 4. Extract new REVIEWER_OUTPUT. Apply Output Block Validation.
6. Set RETRY_COUNT = 1.

If `Overall status:` is still not PASS after the retry: note `Retry: 1 pass → still failing` and continue to Step 6.

---

## Step 6: Commit (if PASS)

If `Overall status: PASS`:
- `git -C {WORKTREE_PATH} add -A`
- `git -C {WORKTREE_PATH} commit -m "nob: {RUN_ID}"`

---

## Step 7: Emit output

Emit the following blocks. The hub reads these to print Step 4 terminal summary.

```
[LITE PATH OUTPUT]
Status: {Overall status from REVIEWER_OUTPUT — PASS | NEEDS REVIEW | FAIL}
Retry count: {RETRY_COUNT}
Retry ran: {true | false}
Agents run: pm({pm model}) · dev({dev model}) · reviewer({reviewer model})
Timing: dev {round(DEV_DURATION_MS/1000)}s · reviewer {round(REVIEWER_DURATION_MS/1000)}s
[/LITE PATH OUTPUT]
```

Then emit the output blocks verbatim so the hub can extract them:

```
[PM OUTPUT]
{PM_OUTPUT content}
[/PM OUTPUT]

[TECH LEAD OUTPUT]
{TECH_LEAD_OUTPUT content}
[/TECH LEAD OUTPUT]

[DEV OUTPUT]
{DEV_OUTPUT content}
[/DEV OUTPUT]

[REVIEWER OUTPUT]
{REVIEWER_OUTPUT content}
[/REVIEWER OUTPUT]
```
