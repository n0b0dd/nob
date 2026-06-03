# Backlog Implementation Plan (H1–H3, M1, M3, L1–L3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add eight features from `docs/backlog.md` to the nob hub orchestrator: pre-flight validation, --plan-only flag, model visibility, audit trail, auto-PR, cross-run memory, push notification, and complexity-based model selection.

**Architecture:** All changes are surgical edits to two Markdown files — `skills/nob/SKILL.md` (hub instructions) and `skills/nob/templates/.nob.yml.template` (user config template). No build system, no runtime. Each task inserts or replaces a specific section of those files.

**Tech Stack:** Markdown skill files, Bash tool (`date +%s`, `date -u +%FT%TZ`, `gh`), Claude Code Agent tool, PushNotification tool.

---

## File Map

| File | Changes |
|------|---------|
| `skills/nob/SKILL.md` | Tasks 1–9: Step 1 additions, new Step 1.5, Step 2 addition, Phase 1 additions, Phase 2 agent prompt additions, Phase 2 timing wrappers, terminal summary lines, worktree teardown auto-PR, new Step 4.5 |
| `skills/nob/templates/.nob.yml.template` | Task 10: `max_tokens_per_run` field + L3 model comment |

---

## Task 1: H3 — Spec pre-flight validation (Step 1.5)

**Files:**
- Modify: `skills/nob/SKILL.md` — insert new `## Step 1.5` section

- [ ] **Step 1: Read the insertion point**

Open `skills/nob/SKILL.md`. Find the line:
```
- `agents.checkpoint.path` (default: `.nob/` if not present)
```
The new section inserts immediately after this line, before `## Step 2`.

- [ ] **Step 2: Insert Step 1.5**

Using the Edit tool, replace:
```
- `agents.checkpoint.path` (default: `.nob/` if not present)

## Step 2: Identify workflow type
```
with:
```
- `agents.checkpoint.path` (default: `.nob/` if not present)

**Project memory**: check whether `.nob/project-memory.md` exists using the Read tool. If found and non-empty: store contents as PROJECT_MEMORY. Otherwise set PROJECT_MEMORY = "none".

## Step 1.5: Spec pre-flight validation

Skip this step for Init, Venture, Refactor, Ideate workflows, and `--plan-only` runs.

For `Spec→Code` and `Bug→Fix` workflows only — validate the spec before dispatching any agents:

1. **Path present**: confirm the user's message contains a file path (not empty string). If not: print `"Error: no spec file path provided. Usage: /nob implement <path-to-spec.md>"` and exit.
2. **File exists**: use the Read tool to open the spec file. If the Read tool returns an error: print `"Error: spec file not found: <path>. Check the path and try again."` and exit.
3. **File non-empty**: check that the file content length > 0 characters. If empty: print `"Error: spec file is empty: <path>."` and exit.
4. **Acceptance criteria present**: check that the file content contains `## acceptance criteria` (case-insensitive substring match). If absent: print `"Error: spec file has no ## Acceptance criteria section: <path>. Add one before running nob."` and exit.

If all four checks pass: proceed to Step 2.

## Step 2: Identify workflow type
```

- [ ] **Step 3: Verify**

Read back the section around `## Step 1.5` in `skills/nob/SKILL.md`. Confirm:
- The section appears between the config extraction block and `## Step 2`
- All four error messages are present
- PROJECT_MEMORY extraction line is present just before `## Step 1.5`

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add H3 spec pre-flight validation (Step 1.5) and L1 memory read setup"
```

---

## Task 2: M3 — `--plan-only` flag detection + H1 budget config extraction

**Files:**
- Modify: `skills/nob/SKILL.md` — add `--plan-only` detection at top of Step 2; add `max_tokens_per_run` extraction in config section

- [ ] **Step 1: Add --plan-only detection to Step 2**

Using the Edit tool, replace:
```
## Step 2: Identify workflow type

| Intent pattern | Workflow |
```
with:
```
## Step 2: Identify workflow type

**`--plan-only` detection**: before identifying the workflow, check whether the user's message contains `--plan-only`. If found: store PLAN_ONLY = true. Otherwise: PLAN_ONLY = false. Proceed to workflow identification regardless.

| Intent pattern | Workflow |
```

- [ ] **Step 2: Add max_tokens_per_run extraction**

Using the Edit tool, replace:
```
Also extract:
- `agents.max_parallel_slices` (default: 3 if not present)
- `agents.checkpoint.enabled` (default: true if not present)
- `agents.checkpoint.path` (default: `.nob/` if not present)
```
with:
```
Also extract:
- `agents.max_parallel_slices` (default: 3 if not present)
- `agents.checkpoint.enabled` (default: true if not present)
- `agents.checkpoint.path` (default: `.nob/` if not present)
- `agents.max_tokens_per_run` (absent/null if not present — budget guard disabled when absent)
```

- [ ] **Step 3: Verify**

Read back both sections. Confirm:
- `--plan-only` detection paragraph appears at the very top of Step 2 before the intent table
- `max_tokens_per_run` extraction line is present in "Also extract:" list

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add M3 --plan-only detection and H1 max_tokens_per_run config extraction"
```

---

## Task 3: L3 complexity override + M3 early exit + H1 budget guard (Phase 1 post-planner)

**Files:**
- Modify: `skills/nob/SKILL.md` — insert three new blocks after PLAN_OUTPUT extraction in Phase 1

- [ ] **Step 1: Find insertion point**

Open `skills/nob/SKILL.md`. Find this exact text:
```
If PLAN_OUTPUT ambiguities section contains anything other than "none": present them to the user as a numbered list and wait for answers before proceeding. Store answers for inclusion in subsequent agent prompts.

**Determine mode from PLAN_OUTPUT:**
```

Insert the three new blocks between the ambiguities line and `**Determine mode from PLAN_OUTPUT:**`.

- [ ] **Step 2: Insert L3, M3 exit, and H1 budget guard**

Using the Edit tool, replace:
```
If PLAN_OUTPUT ambiguities section contains anything other than "none": present them to the user as a numbered list and wait for answers before proceeding. Store answers for inclusion in subsequent agent prompts.

**Determine mode from PLAN_OUTPUT:**
- `Mode: single` → set SLICES = [{name: "main", scope: "full spec"}]
- `Mode: fan-out` → parse each `Slice N — slug-name` / `Scope:` pair; set SLICES = array of {name, scope} objects
```
with:
```
If PLAN_OUTPUT ambiguities section contains anything other than "none": present them to the user as a numbered list and wait for answers before proceeding. Store answers for inclusion in subsequent agent prompts.

**L3: Complexity-based model override**

Read `Complexity:` from PLAN_OUTPUT. Apply independently per layer:
- If `Complexity.backend = "simple"` AND `backend-agent` key is absent from the user's `.nob.yml` `agents.models` block (or `.nob.yml` was not found): override backend-agent's resolved model to `haiku`. Store as BACKEND_MODEL_RESOLVED.
- If `Complexity.frontend = "simple"` AND `frontend-agent` key is absent from the user's `.nob.yml` `agents.models` block: override frontend-agent's resolved model to `haiku`. Store as FRONTEND_MODEL_RESOLVED.
- Otherwise: use the model values extracted from RESOLVED_CONFIG as-is.

If PLAN_OUTPUT does not contain Complexity fields: apply no override (treat both as complex).

**Determine mode from PLAN_OUTPUT:**
- `Mode: single` → set SLICES = [{name: "main", scope: "full spec"}]
- `Mode: fan-out` → parse each `Slice N — slug-name` / `Scope:` pair; set SLICES = array of {name, scope} objects

**M3: --plan-only early exit**

If PLAN_ONLY = true:
- Print the full contents of PLAN_OUTPUT verbatim.
- Print: `"Plan-only run complete. Re-run without --plan-only to execute."`
- Exit. Do not write a checkpoint. Do not dispatch any further agents.

**H1: Budget guard (fan-out only)**

If `Mode: fan-out` AND `max_tokens_per_run` is set:
- For each slice, assign a unit cost: sonnet = 2 units, haiku = 1 unit (based on BACKEND_MODEL_RESOLVED for that slice).
- Estimated total = sum of unit costs across all slices.
- If `estimated_total × 100000 > max_tokens_per_run`: print:
  ```
  Warning: fan-out with {N} slices (~{estimated_total × 100000} estimated tokens) may exceed max_tokens_per_run ({max_tokens_per_run}).
  Continue? (yes / abort)
  ```
  Wait for response. If `abort`: exit. If `yes`: proceed.
```

- [ ] **Step 3: Verify**

Read back Phase 1 around the PLAN_OUTPUT extraction. Confirm the three blocks appear in this order:
1. L3 complexity override
2. Determine mode (with SLICES assignment)
3. M3 --plan-only early exit
4. H1 budget guard

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add L3 complexity model override, M3 plan-only exit, H1 budget guard in Phase 1"
```

---

## Task 4: H2 — Checkpoint schema extension + run log creation

**Files:**
- Modify: `skills/nob/SKILL.md` — extend checkpoint JSON + add run log creation after checkpoint write

- [ ] **Step 1: Extend checkpoint JSON**

Using the Edit tool, replace the checkpoint JSON block:
```
Using the Write tool, write `{checkpoint.path}checkpoint.json`:
```json
{
  "run_id": "{run-id derived in Step 0.1}",
  "worktree_path": "{WORKTREE_PATH}",
  "worktree_branch": "{WORKTREE_BRANCH}",
  "workflow": "{workflow value from PLAN_OUTPUT}",
  "source": "{source file path}",
  "phases_completed": ["phase1"],
  "slices": {
    "{slice-name}": { "status": "pending", "timed_out_at": null, "pm_output": null, "backend_output": null, "frontend_output": null }
  },
  "reviewer_output": null
}
```
One entry per slice in the `slices` object.
```
with:
```
Run `date -u +%FT%TZ` via the Bash tool and store as RUN_START_TIMESTAMP.

Using the Write tool, write `{checkpoint.path}checkpoint.json`:
```json
{
  "run_id": "{run-id derived in Step 0.1}",
  "run_start_time": "{RUN_START_TIMESTAMP}",
  "worktree_path": "{WORKTREE_PATH}",
  "worktree_branch": "{WORKTREE_BRANCH}",
  "workflow": "{workflow value from PLAN_OUTPUT}",
  "source": "{source file path}",
  "phases_completed": ["phase1"],
  "slices": {
    "{slice-name}": { "status": "pending", "timed_out_at": null, "pm_output": null, "backend_output": null, "frontend_output": null }
  },
  "agents": {},
  "reviewer_output": null
}
```
One entry per slice in the `slices` object.

**Create run log**: using the Write tool, create `.nob/run-{run-id}.log` with this initial content:
```
{RUN_START_TIMESTAMP}  run            -       START   -
```
Store as RUN_LOG_PATH = `.nob/run-{run-id}.log`.
```

- [ ] **Step 2: Verify**

Read back the Phase 1 checkpoint section. Confirm:
- `run_start_time` field present in JSON
- `"agents": {}` field present in JSON
- Run log creation block present after the checkpoint write

- [ ] **Step 3: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add H2 checkpoint schema extension (run_start_time, agents{}) and run log creation"
```

---

## Task 5: H2 — Timing wrappers around Phase 2 single-path agent dispatches

**Files:**
- Modify: `skills/nob/SKILL.md` — add `date +%s` before/after PM, Backend+Frontend, Security, and Reviewer dispatches; write timing to checkpoint and log after each

- [ ] **Step 1: Wrap PM Agent dispatch**

Find:
```
**Agent 1 — PM Agent**

Read `{SKILL_BASE_DIR}/../pm-agent/SKILL.md`. Dispatch with `model: agents.models["pm-agent"] ?? "haiku"`:
```

Using the Edit tool, replace:
```
**Agent 1 — PM Agent**

Read `{SKILL_BASE_DIR}/../pm-agent/SKILL.md`. Dispatch with `model: agents.models["pm-agent"] ?? "haiku"`:
```
with:
```
**Agent 1 — PM Agent**

Run `date +%s` via the Bash tool and store as PM_START_EPOCH.

Read `{SKILL_BASE_DIR}/../pm-agent/SKILL.md`. Dispatch with `model: agents.models["pm-agent"] ?? "haiku"`:
```

- [ ] **Step 2: Record PM timing after extraction**

Find:
```
Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

---

**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**
```

Using the Edit tool, replace:
```
Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

---

**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**
```
with:
```
Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

Run `date +%s` and store as PM_END_EPOCH. Compute PM_DURATION_MS = (PM_END_EPOCH - PM_START_EPOCH) × 1000. Read checkpoint, set `agents["pm-agent"] = { "model": "{resolved pm-agent model}", "started_at": "{PM_START_EPOCH}", "duration_ms": PM_DURATION_MS, "error": null }`, write back. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  pm-agent        {model}  OK    {PM_DURATION_MS}ms`.

---

**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**
```

- [ ] **Step 3: Wrap Backend+Frontend dispatch**

Find:
```
**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**

Dispatch both in the same assistant turn — one Agent call for Backend, one for Frontend. Do not await Backend's result before dispatching Frontend.
```

Using the Edit tool, replace:
```
**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**

Dispatch both in the same assistant turn — one Agent call for Backend, one for Frontend. Do not await Backend's result before dispatching Frontend.
```
with:
```
**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**

Run `date +%s` and store as IMPL_START_EPOCH.

Dispatch both in the same assistant turn — one Agent call for Backend, one for Frontend. Do not await Backend's result before dispatching Frontend.
```

- [ ] **Step 4: Record Backend+Frontend timing after both return**

Find the line:
```
Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]
```

Using the Edit tool, replace:
```
Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]
```
with:
```
Run `date +%s` and store as IMPL_END_EPOCH. Compute IMPL_DURATION_MS = (IMPL_END_EPOCH - IMPL_START_EPOCH) × 1000. Read checkpoint, set `agents["backend-agent"] = { "model": "{BACKEND_MODEL_RESOLVED}", "started_at": "{IMPL_START_EPOCH}", "duration_ms": IMPL_DURATION_MS, "error": null }` and `agents["frontend-agent"] = { "model": "{FRONTEND_MODEL_RESOLVED}", "started_at": "{IMPL_START_EPOCH}", "duration_ms": IMPL_DURATION_MS, "error": null }`, write back. Append two lines to RUN_LOG_PATH:
```
{date -u +%FT%TZ}  backend-agent   {BACKEND_MODEL_RESOLVED}  OK    {IMPL_DURATION_MS}ms
{date -u +%FT%TZ}  frontend-agent  {FRONTEND_MODEL_RESOLVED}  OK    {IMPL_DURATION_MS}ms
```

Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]
```

- [ ] **Step 5: Wrap Security Agent dispatch (Phase 2.5)**

Find:
```
Read `{SKILL_BASE_DIR}/security-agent/SKILL.md`. Dispatch with `model: agents.models["security-agent"] ?? "haiku"`:
```

Using the Edit tool, replace (first occurrence — the Phase 2.5 dispatch):
```
Read `{SKILL_BASE_DIR}/security-agent/SKILL.md`. Dispatch with `model: agents.models["security-agent"] ?? "haiku"`:
```
with:
```
Run `date +%s` and store as SEC_START_EPOCH.

Read `{SKILL_BASE_DIR}/security-agent/SKILL.md`. Dispatch with `model: agents.models["security-agent"] ?? "haiku"`:
```

Find:
```
Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT. Apply the **Output Block Validation Procedure** for Security Agent before proceeding.

**Apply severity gate:**
```

Using the Edit tool, replace:
```
Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT. Apply the **Output Block Validation Procedure** for Security Agent before proceeding.

**Apply severity gate:**
```
with:
```
Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT. Apply the **Output Block Validation Procedure** for Security Agent before proceeding.

Run `date +%s` and store as SEC_END_EPOCH. Compute SEC_DURATION_MS = (SEC_END_EPOCH - SEC_START_EPOCH) × 1000. Read checkpoint, set `agents["security-agent"] = { "model": "{resolved security-agent model}", "started_at": "{SEC_START_EPOCH}", "duration_ms": SEC_DURATION_MS, "error": null }`, write back. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  security-agent  {model}  OK    {SEC_DURATION_MS}ms`.

**Apply severity gate:**
```

- [ ] **Step 6: Wrap Reviewer dispatch (Phase 3)**

Find:
```
Read `{SKILL_BASE_DIR}/reviewer/SKILL.md`. Dispatch with `model: agents.models["reviewer"] ?? "haiku"`:
```

Using the Edit tool, replace:
```
Read `{SKILL_BASE_DIR}/reviewer/SKILL.md`. Dispatch with `model: agents.models["reviewer"] ?? "haiku"`:
```
with:
```
Run `date +%s` and store as REVIEWER_START_EPOCH.

Read `{SKILL_BASE_DIR}/reviewer/SKILL.md`. Dispatch with `model: agents.models["reviewer"] ?? "haiku"`:
```

Find:
```
Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply the **Output Block Validation Procedure** for Reviewer before proceeding.

**Write final checkpoint** (if checkpoint.enabled):
```

Using the Edit tool, replace:
```
Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply the **Output Block Validation Procedure** for Reviewer before proceeding.

**Write final checkpoint** (if checkpoint.enabled):
```
with:
```
Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply the **Output Block Validation Procedure** for Reviewer before proceeding.

Run `date +%s` and store as REVIEWER_END_EPOCH. Compute REVIEWER_DURATION_MS = (REVIEWER_END_EPOCH - REVIEWER_START_EPOCH) × 1000. Read checkpoint, set `agents["reviewer"] = { "model": "{resolved reviewer model}", "started_at": "{REVIEWER_START_EPOCH}", "duration_ms": REVIEWER_DURATION_MS, "error": null }`, write back. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  reviewer        {model}  OK    {REVIEWER_DURATION_MS}ms`.

**Write final checkpoint** (if checkpoint.enabled):
```

- [ ] **Step 7: Verify**

Read back Phase 2 single-slice path, Phase 2.5, and Phase 3. Confirm:
- `date +%s` call before PM dispatch
- Timing + checkpoint update + log append after PM extraction
- `date +%s` call before concurrent Backend+Frontend dispatch
- Timing + checkpoint update + log append (two lines) after SLICE_RESULTS assignment
- `date +%s` call before Security Agent dispatch
- Timing + checkpoint update + log append after Security extraction
- `date +%s` call before Reviewer dispatch
- Timing + checkpoint update + log append after Reviewer extraction

- [ ] **Step 8: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add H2 timing wrappers around Phase 2/2.5/3 agent dispatches"
```

---

## Task 6: L1 — Project memory injection into all agent [INPUTS] blocks

**Files:**
- Modify: `skills/nob/SKILL.md` — add `Project memory:` field to PM, Backend, Frontend single-path prompts and fan-out slice runner [INPUTS]

- [ ] **Step 1: Add to PM Agent [INPUTS]**

Find the PM Agent [INPUTS] block (single path). It ends with:
```
Plan context:
{PLAN_OUTPUT}
[/INPUTS]
```

Using the Edit tool, replace:
```
Plan context:
{PLAN_OUTPUT}
[/INPUTS]
```
with:
```
Plan context:
{PLAN_OUTPUT}

Project memory:
{PROJECT_MEMORY}
[/INPUTS]
```

- [ ] **Step 2: Add to Backend Agent [INPUTS] (single path)**

Find the Backend Agent [INPUTS] block. It ends with:
```
SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```
(the first occurrence — in the single-slice path, before the fan-out path)

Using the Edit tool, replace the first occurrence (single-slice Backend) — find the block containing `{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}` followed by `SCOPE LIMIT` in the Backend Agent section, then its `[/INPUTS]`:
```
{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```

with (in the single-slice Backend Agent block only):
```
{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

Project memory:
{PROJECT_MEMORY}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```

Note: There are two similar blocks (Backend and Frontend in single-slice, then Backend and Frontend in retry). Target only the single-slice phase 2 Backend block here. Use sufficient surrounding context to make the match unique.

- [ ] **Step 3: Add to Frontend Agent [INPUTS] (single path)**

Similarly, add `Project memory:` to the single-slice Frontend Agent [INPUTS]. The Frontend block ends with the same SCOPE LIMIT pattern. Replace (single-slice Frontend, which contains the `Backend Agent is running in parallel` line):
```
Backend Agent is running in parallel — use API contracts from PM Agent output above.
No [BACKEND-AGENT OUTPUT] will be provided.

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```
with:
```
Backend Agent is running in parallel — use API contracts from PM Agent output above.
No [BACKEND-AGENT OUTPUT] will be provided.

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

Project memory:
{PROJECT_MEMORY}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```

- [ ] **Step 4: Add to fan-out slice runner [INPUTS]**

Find the fan-out slice runner [INPUTS] block. It ends with:
```
{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```
(the last [INPUTS] block in the fan-out section — the outer slice runner prompt's inputs, not the inner Backend/Frontend prompts)

Using the Edit tool, replace:
```
{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```
with (use unique surrounding context to target the outer slice runner block):
```
{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

Project memory:
{PROJECT_MEMORY}
[/INPUTS]
```

- [ ] **Step 5: Verify**

Read back the four modified [INPUTS] blocks. Each should have `Project memory:\n{PROJECT_MEMORY}` before its closing `[/INPUTS]`.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add L1 project memory injection into all agent [INPUTS] blocks"
```

---

## Task 7: H1 + H2 — Terminal summary additions (Agents + Timing lines)

**Files:**
- Modify: `skills/nob/SKILL.md` — replace bare `Agents:` line with model-per-agent format; add `Timing:` line

- [ ] **Step 1: Replace Agents line and add Timing line**

Find (in the "For all other workflows" terminal summary block):
```
Agents:    [comma-separated list of agents that ran]

[if Mode: fan-out:]
```

Using the Edit tool, replace:
```
Agents:    [comma-separated list of agents that ran]

[if Mode: fan-out:]
```
with:
```
Agents:    [each agent that ran as "name(model)" separated by " · " — e.g.: planner(haiku) · pm-agent(haiku) · backend-agent(sonnet) · frontend-agent(sonnet) · security-agent(haiku) · reviewer(haiku). List only agents that actually ran; skip disabled/skipped agents. Use BACKEND_MODEL_RESOLVED and FRONTEND_MODEL_RESOLVED for those two agents.]
Timing:    [each agent that ran as "name Ns" separated by " · " — e.g.: planner 4s · pm-agent 3s · backend-agent 18s · reviewer 8s. Round duration_ms to nearest second. Show "n/a" if duration not recorded.]

[if Mode: fan-out:]
```

- [ ] **Step 2: Verify**

Read back the terminal summary block. Confirm both `Agents:` and `Timing:` lines are present with their format descriptions.

- [ ] **Step 3: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add H1 Agents(model) and H2 Timing lines to terminal summary"
```

---

## Task 8: M1 — Auto-PR creation after worktree teardown

**Files:**
- Modify: `skills/nob/SKILL.md` — add `gh pr create` block after PASS worktree teardown

- [ ] **Step 1: Insert auto-PR block**

Find:
```
If `Overall status: PASS`:
- Run: `git -C {WORKTREE_PATH} add -A`
- Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip commit if nothing to commit)
- Run: `git worktree remove {WORKTREE_PATH}`
- Print: `Worktree committed and removed. Branch: {WORKTREE_BRANCH}`
- Print: `Next: git push -u origin {WORKTREE_BRANCH}`

If `Overall status: FAIL` or `NEEDS REVIEW`:
```

Using the Edit tool, replace:
```
If `Overall status: PASS`:
- Run: `git -C {WORKTREE_PATH} add -A`
- Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip commit if nothing to commit)
- Run: `git worktree remove {WORKTREE_PATH}`
- Print: `Worktree committed and removed. Branch: {WORKTREE_BRANCH}`
- Print: `Next: git push -u origin {WORKTREE_BRANCH}`

If `Overall status: FAIL` or `NEEDS REVIEW`:
```
with:
```
If `Overall status: PASS`:
- Run: `git -C {WORKTREE_PATH} add -A`
- Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip commit if nothing to commit)
- Run: `git worktree remove {WORKTREE_PATH}`
- Print: `Worktree committed and removed. Branch: {WORKTREE_BRANCH}`

**Auto-PR** (PASS only):
Run `gh --version` via the Bash tool to check availability.
- If available: run `gh pr create --title "{spec filename without path or extension}" --body "{first 3000 characters of REVIEWER_OUTPUT}" --head {WORKTREE_BRANCH}`. Print: `PR created: {returned URL}`.
- If `gh pr create` fails: print the error and fall through to the git push command below.
- If `gh` is not available: do nothing here — the push command below suffices.
- Print: `Next: git push -u origin {WORKTREE_BRANCH}`

If `Overall status: FAIL` or `NEEDS REVIEW`:
```

- [ ] **Step 2: Verify**

Read back the worktree teardown section. Confirm the Auto-PR block is inside the PASS branch, after `git worktree remove`, and that the `git push` print follows it.

- [ ] **Step 3: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add M1 auto-PR creation after PASS worktree teardown"
```

---

## Task 9: L2 — Push notification + L1 memory write (Step 4.5)

**Files:**
- Modify: `skills/nob/SKILL.md` — add PushNotification after teardown + new Step 4.5

- [ ] **Step 1: Add push notification at end of teardown**

Find:
```
If WORKTREE_PATH equals the current working directory (git not available): skip teardown entirely.

---

## Error Handling
```

Using the Edit tool, replace:
```
If WORKTREE_PATH equals the current working directory (git not available): skip teardown entirely.

---

## Error Handling
```
with:
```
If WORKTREE_PATH equals the current working directory (git not available): skip teardown entirely.

**Push notification** (always — after teardown regardless of status):

Use the PushNotification tool with:
- `title`: `"Nob complete"`
- `body`: `"{workflow} · {spec filename without path} · {Overall status from REVIEWER_OUTPUT}"`

If the PushNotification tool is not available, skip silently.

## Step 4.5: Post-run memory write

Run only when `Overall status: PASS` and `agents.checkpoint.enabled` is true.

Extract from agent outputs:
1. **Test runner**: scan BACKEND_OUTPUT `Test output:` for the strings `jest`, `vitest`, `pytest`, `go test`, `rspec`, `mocha`. First match wins. Default: `unknown`.
2. **Key routes**: extract up to 5 lines from `New API contracts:` in BACKEND_OUTPUT. If absent or `none`: use `none`.
3. **Backend files**: first 3 paths from `Files changed:` in BACKEND_OUTPUT. If absent or `none`: use `none`.
4. **Frontend files**: first 3 paths from `Files changed:` in FRONTEND_OUTPUT. If absent or `none`: use `none`.

Run `date +%F` via the Bash tool to get TODAY (YYYY-MM-DD format).

Read existing `.nob/project-memory.md` using the Read tool (or start with empty string if not found). Append this entry and write back using the Write tool:

```markdown
## Run: {run-id} ({TODAY})
Spec: {spec file path}
Test runner: {detected}
Key routes: {list, or none}
Backend files: {top 3, or none}
Frontend files: {top 3, or none}
```

Append final summary line to RUN_LOG_PATH using the Edit tool:
```
{date -u +%FT%TZ}  run            -       PASS   -  total
```

---

## Error Handling
```

- [ ] **Step 2: Add new error handling entries**

Find in the Error Handling section:
```
- **Ideation agent returns no [IDEATION-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
```

Using the Edit tool, replace:
```
- **Ideation agent returns no [IDEATION-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
```
with:
```
- **Ideation agent returns no [IDEATION-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
- **Pre-flight validation fails (Step 1.5)**: print specific error message, exit immediately — no agents dispatched
- **`gh pr create` fails (M1)**: print the error output; print the `git push -u origin {WORKTREE_BRANCH}` command as fallback
- **`.nob/project-memory.md` unreadable (L1)**: set PROJECT_MEMORY = "none", skip silently; do not block pipeline
- **PushNotification tool unavailable (L2)**: skip silently
- **Run log write fails (H2)**: skip silently; do not block pipeline
- **PLAN_OUTPUT missing Complexity fields (L3)**: apply no model override; treat both layers as complex
```

- [ ] **Step 3: Verify**

Read back the section after the teardown block. Confirm:
- Push notification block present after teardown, before Step 4.5
- Step 4.5 contains all five extraction steps
- New error handling entries present

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add L2 push notification and L1 Step 4.5 memory write; extend error handling"
```

---

## Task 10: .nob.yml template — H1 field + L3 comment

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template` — add `max_tokens_per_run` and L3 model comment

- [ ] **Step 1: Add max_tokens_per_run field**

Find in the template:
```
  max_parallel_slices: 3    # cap concurrent fan-out pipelines (default: 3)
```

Using the Edit tool, replace:
```
  max_parallel_slices: 3    # cap concurrent fan-out pipelines (default: 3)
```
with:
```
  max_parallel_slices: 3    # cap concurrent fan-out pipelines (default: 3)
  max_tokens_per_run: 500000  # optional; omit or remove to disable budget guard
```

- [ ] **Step 2: Add L3 comment under models block**

Find:
```
  models:
    backend-agent: sonnet   # code-writing agents need sonnet
    frontend-agent: sonnet
```

Using the Edit tool, replace:
```
  models:
    backend-agent: sonnet   # code-writing agents need sonnet
    frontend-agent: sonnet
```
with:
```
  models:
    # Models set here are always respected. For simple specs, nob automatically
    # downgrades backend-agent and frontend-agent to haiku unless set explicitly here.
    backend-agent: sonnet   # code-writing agents need sonnet
    frontend-agent: sonnet
```

- [ ] **Step 3: Verify**

Read back `.nob.yml.template`. Confirm `max_tokens_per_run` field and the L3 comment are present.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/templates/.nob.yml.template
git commit -m "feat: add H1 max_tokens_per_run and L3 model comment to .nob.yml template"
```

---

## Final verification

- [ ] **Read skills/nob/SKILL.md in full** and scan for:
  - `## Step 1.5` present
  - `--plan-only` detection at top of Step 2
  - `max_tokens_per_run` in config extraction
  - `PROJECT_MEMORY` read + `Project memory:` in all four agent [INPUTS] blocks
  - L3 override block after ambiguities check
  - M3 early exit block after L3
  - H1 budget guard block after M3
  - `run_start_time` and `"agents": {}` in checkpoint JSON
  - `RUN_LOG_PATH` creation
  - `date +%s` timing wrappers around PM and Backend+Frontend dispatches
  - `Agents:` and `Timing:` lines in terminal summary
  - Auto-PR block inside PASS teardown
  - PushNotification after teardown
  - `## Step 4.5` present
  - New error handling entries

- [ ] **Read .nob.yml.template**: confirm `max_tokens_per_run` and L3 comment present.
