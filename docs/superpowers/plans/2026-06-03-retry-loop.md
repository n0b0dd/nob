# Retry Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Nob's single-pass Phase 3.5 with a configurable retry loop: first pass automatic, subsequent passes user-gated, with stuck detection and a `.nob.yml`-configurable max.

**Architecture:** Two files change. Step 1 of the hub gains one config extraction line for `agents.max_retries`. Phase 3.5 is fully replaced with a loop that tracks `RETRY_COUNT`, `PREV_RETRY_ITEMS`, and `MAX_RETRIES`. The terminal summary and one error-handling comment are updated to match. The `.nob.yml` template gains a `max_retries` field.

**Tech Stack:** Markdown (SKILL.md instruction files), YAML (config template)

---

## File Map

| File | Change |
|---|---|
| `skills/nob/SKILL.md` | Task 1: add `agents.max_retries` extraction in Step 1 |
| `skills/nob/templates/.nob.yml.template` | Task 1: add `max_retries: 3` field |
| `skills/nob/SKILL.md` | Task 2: replace Phase 3.5 entirely |
| `skills/nob/SKILL.md` | Task 2: update terminal summary `Retry:` lines |
| `skills/nob/SKILL.md` | Task 2: update error handling comment |

---

## Task 1: Add max_retries config extraction

**Files:**
- Modify: `skills/nob/SKILL.md` ~line 189 — add extraction line after `max_tokens_per_run`
- Modify: `skills/nob/templates/.nob.yml.template` ~line 52 — add `max_retries` field

- [ ] **Step 1: Read and confirm both insertion points**

Read `skills/nob/SKILL.md` lines 186–193. Confirm the block ends with:
```
- `agents.max_tokens_per_run` (absent/null if not present — budget guard disabled when absent)

**Project memory**: check whether `.nob/project-memory.md` exists using the Read tool.
```

Read `skills/nob/templates/.nob.yml.template` lines 50–56. Confirm:
```
  max_tokens_per_run: 500000  # optional; omit or remove to disable budget guard

  venture:
```

- [ ] **Step 2: Add extraction line to SKILL.md**

`old_string`:
```
- `agents.max_tokens_per_run` (absent/null if not present — budget guard disabled when absent)

**Project memory**: check whether `.nob/project-memory.md` exists using the Read tool.
```

`new_string`:
```
- `agents.max_tokens_per_run` (absent/null if not present — budget guard disabled when absent)
- `agents.max_retries` (default: 3 if not present — maximum retry passes in Phase 3.5)

**Project memory**: check whether `.nob/project-memory.md` exists using the Read tool.
```

- [ ] **Step 3: Add max_retries field to .nob.yml template**

`old_string`:
```
  max_tokens_per_run: 500000  # optional; omit or remove to disable budget guard

  venture:
```

`new_string`:
```
  max_tokens_per_run: 500000  # optional; omit or remove to disable budget guard
  max_retries: 3              # max retry passes: 1 automatic + user-gated after that (default: 3)

  venture:
```

- [ ] **Step 4: Verify both edits**

Read `skills/nob/SKILL.md` lines 186–195. Confirm `agents.max_retries` line appears after `agents.max_tokens_per_run`.

Read `skills/nob/templates/.nob.yml.template` lines 50–58. Confirm `max_retries: 3` appears after `max_tokens_per_run`.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md skills/nob/templates/.nob.yml.template
git commit -m "feat: add agents.max_retries config extraction and template field"
```

---

## Task 2: Replace Phase 3.5 with retry loop

**Files:**
- Modify: `skills/nob/SKILL.md` — replace Phase 3.5 section (~lines 1112–1225)
- Modify: `skills/nob/SKILL.md` — update terminal summary Retry lines (~lines 1322–1323)
- Modify: `skills/nob/SKILL.md` — update error handling comment (~line 1420)

- [ ] **Step 1: Read and confirm Phase 3.5 boundaries**

Read `skills/nob/SKILL.md` lines 1112–1230. Confirm the section starts with `## Phase 3.5: Targeted retry` and ends with `---` followed by `## Step 4: Print terminal summary`.

- [ ] **Step 2: Replace Phase 3.5**

`old_string`:
```
## Phase 3.5: Targeted retry

Note: the Security Agent is not re-dispatched during retry. SECURITY_OUTPUT from Phase 2.5 carries through to the second Reviewer run unchanged — the retry fixes spec compliance failures, not security findings.

Read `Overall status:` from REVIEWER_OUTPUT. Set RETRY_RAN = false.

If `Overall status: PASS`: skip this phase entirely and proceed to Step 4.

If `Overall status: NEEDS REVIEW` or `Overall status: FAIL`:

**Determine which agents to re-dispatch:**

Extract from REVIEWER_OUTPUT:
- `Test results: Backend: FAIL` → set RETRY_BACKEND = true
- `Test results: Frontend: FAIL` → set RETRY_FRONTEND = true
- For each `✗` or `⚠` criterion line: cross-reference its text against PM_OUTPUT's `Backend changes needed:` and `Frontend changes needed:` sections
  - Found in `Backend changes needed:` → RETRY_BACKEND = true
  - Found in `Frontend changes needed:` → RETRY_FRONTEND = true
  - Found in both → set both to true
- Any CONTRACT VIOLATION in contract check → RETRY_FRONTEND = true; also set CONTRACT_RETRY = true

If RETRY_BACKEND and RETRY_FRONTEND are both false: no agent can auto-fix the remaining items. Skip retry (RETRY_RAN stays false). Proceed to Step 4.

Collect RETRY_ITEMS = all `✗` criterion lines, all `⚠` criterion lines, and all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

**Present and ask:**

```
Reviewer found N items:
  [RETRY_ITEMS listed one per line]

Attempt to auto-fix? (yes / no)
```

Wait for response.

**If no:** RETRY_RAN stays false. Proceed to Step 4.

**If yes:** Set RETRY_RAN = true. Dispatch flagged agents concurrently in the same assistant turn (do not await one before dispatching the other).

**Backend retry** (only if RETRY_BACKEND = true):

Read `{SKILL_BASE_DIR}/backend-agent/SKILL.md`. Dispatch with `model: agents.models["backend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/backend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Backend changes needed, plus backend test failures}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]`. Replace BACKEND_OUTPUT with this result.

**Frontend retry** (only if RETRY_FRONTEND = true):

Read `{SKILL_BASE_DIR}/frontend-agent/SKILL.md`. Dispatch with `model: agents.models["frontend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/frontend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

{if CONTRACT_RETRY = true:
Backend Agent output (use these API contracts as the authoritative source of truth):
{BACKEND_OUTPUT}
}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Frontend changes needed, frontend test failures, and contract violations}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Replace FRONTEND_OUTPUT with this result.

**After retry agents return:**

Re-dispatch Reviewer with updated BACKEND_OUTPUT and FRONTEND_OUTPUT using the same prompt structure as Phase 3 (Mode: single path). Extract new REVIEWER_OUTPUT. This is the FINAL review — do not offer retry again regardless of status.

Write updated final checkpoint (if checkpoint.enabled): read checkpoint.json, update `reviewer_output` to the new REVIEWER_OUTPUT, write back.

**Fan-out mode:** When Mode is fan-out, REVIEWER_OUTPUT covers all slices in a single combined block. If retry is triggered, re-dispatch all slices as a new batch using the same batch structure and prompt as Phase 2 fan-out. After slices complete, merge their outputs and re-run Reviewer once. This is the FINAL review — do not offer retry again.
```

`new_string`:
```
## Phase 3.5: Retry loop

Note: the Security Agent is not re-dispatched during retry. SECURITY_OUTPUT from Phase 2.5 carries through unchanged — retry fixes spec compliance failures, not security findings.

Initialize: RETRY_COUNT = 0. PREV_RETRY_ITEMS = []. RETRY_RAN = false.

--- Loop start ---

Read `Overall status:` from REVIEWER_OUTPUT.

If `Overall status: PASS`: exit loop. Proceed to Step 4.

Collect RETRY_ITEMS = all `✗` criterion lines, all `⚠` criterion lines, and all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

**Stuck check** (skip when RETRY_COUNT == 0):
If RETRY_COUNT > 0 AND RETRY_ITEMS is identical to PREV_RETRY_ITEMS:
  Set RETRY_RAN = true.
  Print:
  ```
  Retry stuck — same N failure(s) appeared in two consecutive passes:
    [RETRY_ITEMS listed one per line]
  Human review required before continuing.
  ```
  Exit loop. Proceed to Step 4.

**Max retries check:**
If RETRY_COUNT >= MAX_RETRIES:
  Set RETRY_RAN = true.
  Print:
  ```
  Max retries (MAX_RETRIES) reached. Human review required.
  ```
  Exit loop. Proceed to Step 4.

**Determine which agents to re-dispatch:**

Extract from REVIEWER_OUTPUT:
- `Test results: Backend: FAIL` → set RETRY_BACKEND = true
- `Test results: Frontend: FAIL` → set RETRY_FRONTEND = true
- For each `✗` or `⚠` criterion line: cross-reference its text against PM_OUTPUT's `Backend changes needed:` and `Frontend changes needed:` sections
  - Found in `Backend changes needed:` → RETRY_BACKEND = true
  - Found in `Frontend changes needed:` → RETRY_FRONTEND = true
  - Found in both → set both to true
- Any CONTRACT VIOLATION in contract check → RETRY_FRONTEND = true; also set CONTRACT_RETRY = true

If RETRY_BACKEND and RETRY_FRONTEND are both false: no agent can auto-fix the remaining items. Exit loop. Proceed to Step 4.

**User gate:**

If RETRY_COUNT == 0:
  Print:
  ```
  Reviewer found N item(s) — auto-fixing (pass 1/MAX_RETRIES):
    [RETRY_ITEMS listed one per line]
  ```
  (No user prompt — proceed automatically.)
Else:
  Print:
  ```
  Still failing after pass RETRY_COUNT/MAX_RETRIES:
    [RETRY_ITEMS listed one per line]

  Retry again? (yes / no)
  ```
  Wait for user response.
  If `no` or any non-yes response: exit loop. Proceed to Step 4.

Set PREV_RETRY_ITEMS = RETRY_ITEMS.
Set RETRY_RAN = true.

**Backend retry** (only if RETRY_BACKEND = true):

Read `{SKILL_BASE_DIR}/backend-agent/SKILL.md`. Dispatch with `model: agents.models["backend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/backend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Backend changes needed, plus backend test failures}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]`. Replace BACKEND_OUTPUT with this result.

**Frontend retry** (only if RETRY_FRONTEND = true):

Read `{SKILL_BASE_DIR}/frontend-agent/SKILL.md`. Dispatch with `model: agents.models["frontend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/frontend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

{if CONTRACT_RETRY = true:
Backend Agent output (use these API contracts as the authoritative source of truth):
{BACKEND_OUTPUT}
}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Frontend changes needed, frontend test failures, and contract violations}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Replace FRONTEND_OUTPUT with this result.

**After retry agents return:**

Re-dispatch Reviewer with updated BACKEND_OUTPUT and FRONTEND_OUTPUT using the same prompt structure as Phase 3 (Mode: single path). Extract new REVIEWER_OUTPUT.

Write updated checkpoint (if checkpoint.enabled): read checkpoint.json, update `reviewer_output` to the new REVIEWER_OUTPUT, write back.

Increment RETRY_COUNT by 1.

Go to Loop start.

--- Loop end ---

**Fan-out mode:** REVIEWER_OUTPUT covers all slices in a single combined block. When retry is triggered, re-dispatch all slices as a new batch using the same structure as Phase 2 fan-out. After slices complete, merge outputs and re-run Reviewer once. Increment RETRY_COUNT. Continue loop.
```

- [ ] **Step 3: Verify Phase 3.5 replacement**

Read `skills/nob/SKILL.md` lines 1112–1240. Confirm:
- Section is now titled `## Phase 3.5: Retry loop`
- `RETRY_COUNT = 0`, `PREV_RETRY_ITEMS = []`, `RETRY_RAN = false` initialization present
- Stuck check block present with `RETRY_COUNT > 0` guard
- Max retries check block present using `MAX_RETRIES`
- User gate: RETRY_COUNT == 0 path prints without prompting; else path asks `"Retry again? (yes / no)"`
- `Set PREV_RETRY_ITEMS = RETRY_ITEMS` appears before dispatch
- `Increment RETRY_COUNT by 1` and `Go to Loop start` appear at the end of the loop body
- Fan-out mode paragraph updated (no longer says "FINAL review — do not offer retry again")

- [ ] **Step 4: Update terminal summary Retry lines**

`old_string`:
```
[if RETRY_RAN = true: "Retry:     ran  →  Final review: [Overall status from final REVIEWER_OUTPUT]"]
[if RETRY_RAN = false and first review was not PASS: "Retry:     skipped"]
```

`new_string`:
```
[Retry line — derive from RETRY_COUNT, RETRY_RAN, and exit reason:
  if RETRY_RAN = true and not stuck and not max-hit: "Retry:     {RETRY_COUNT} pass(es) → Final review: [Overall status from final REVIEWER_OUTPUT]"
  if stuck: "Retry:     stuck after {RETRY_COUNT} pass(es) — same failures in 2 consecutive rounds"
  if max retries hit: "Retry:     max retries ({MAX_RETRIES}) reached after {RETRY_COUNT} pass(es)"
  if RETRY_RAN = false and first review was not PASS: "Retry:     skipped — [no fixable agents | user declined]"]
```

- [ ] **Step 5: Update error handling comment**

`old_string`:
```
- **Reviewer status is FAIL**: print all failing items prominently; offer one targeted retry via Phase 3.5; do NOT offer a second retry
```

`new_string`:
```
- **Reviewer status is FAIL**: print all failing items prominently; Phase 3.5 retry loop handles up to MAX_RETRIES passes (1 automatic + user-gated after that)
```

- [ ] **Step 6: Verify all three SKILL.md edits**

Read `skills/nob/SKILL.md` lines 1318–1330. Confirm the new `Retry:` line block is present.

Run:
```bash
grep -n "do NOT offer a second retry" skills/nob/SKILL.md
```
Expected: no output (old error handling line gone).

Run:
```bash
grep -n "MAX_RETRIES\|RETRY_COUNT\|PREV_RETRY_ITEMS" skills/nob/SKILL.md | wc -l
```
Expected: at least 10 lines (confirms variables are used throughout the loop).

- [ ] **Step 7: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: replace Phase 3.5 single-pass retry with configurable retry loop"
```

---

## Self-Review Checklist

After both tasks complete, verify:

- [ ] `agents.max_retries` appears in Step 1 config extraction in `skills/nob/SKILL.md`
- [ ] `max_retries: 3` appears in `.nob.yml.template` after `max_tokens_per_run`
- [ ] Phase 3.5 is titled `Retry loop` (not `Targeted retry`)
- [ ] RETRY_COUNT, PREV_RETRY_ITEMS, MAX_RETRIES all used in Phase 3.5
- [ ] Stuck check has `RETRY_COUNT > 0` guard
- [ ] User gate: first pass (RETRY_COUNT == 0) has no prompt; later passes prompt `"Retry again? (yes / no)"`
- [ ] `Set PREV_RETRY_ITEMS = RETRY_ITEMS` appears before dispatch in loop body
- [ ] `Increment RETRY_COUNT by 1` and `Go to Loop start` appear at end of loop body
- [ ] Terminal summary Retry lines reflect all exit reasons
- [ ] Error handling comment no longer says "do NOT offer a second retry"
- [ ] Two commits on current branch
