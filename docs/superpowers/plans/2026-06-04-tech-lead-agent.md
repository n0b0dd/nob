# Tech Lead Agent — Pipeline Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Nob pipeline from `Planner → PM → Backend+Frontend → Security → Reviewer` to `PM → Tech Lead → Security → Reviewer`, where Tech Lead absorbs Planner's responsibilities and actively manages Backend and Frontend in parallel with a blocker resolution loop.

**Architecture:** Hub becomes a thin chain (PM → Tech Lead → Security → Reviewer). Tech Lead reads PM product requirements, writes all technical artifacts (API contracts, data schemas, task breakdown), dispatches Backend and Frontend concurrently, resolves blockers autonomously or escalates to human, and merges outputs before releasing to Security. The Planner skill is retired.

**Tech Stack:** Markdown skill files only — no runtime, no build system. Changes are purely to `.md` instruction files and `.yml` config templates.

---

## File Map

| File | Action |
|---|---|
| `skills/tech-lead/SKILL.md` | **Create** — new Tech Lead agent |
| `skills/nob/SKILL.md` | **Modify** — slim Hub, replace Planner+Backend+Frontend phases with Tech Lead dispatch |
| `skills/pm/SKILL.md` | **Modify** — remove API contracts and data schemas from all outputs |
| `skills/backend/SKILL.md` | **Modify** — receive Tech Lead spec, emit `[BLOCKER]`/`[DONE]` blocks |
| `skills/frontend/SKILL.md` | **Modify** — same as Backend |
| `skills/planner/SKILL.md` | **Modify** — add deprecation notice at top |
| `skills/nob/templates/.nob.yml.template` | **Modify** — add `tech_lead` model entry, swap `planner` for `tech-lead` in enabled list |
| `CLAUDE.md` | **Modify** — update repo structure table and pipeline description |

---

## Task 1: Create `skills/tech-lead/SKILL.md`

**Files:**
- Create: `skills/tech-lead/SKILL.md`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p skills/tech-lead
```

Expected: directory created, no output.

- [ ] **Step 2: Write `skills/tech-lead/SKILL.md`**

Write the following content exactly:

````markdown
---
name: tech-lead
description: "Owns all technical work from PM requirements to implementation completion. Writes API contracts, data schemas, and task breakdowns. Dispatches Backend and Frontend concurrently, resolves blockers autonomously or escalates to human, and merges outputs before Security review. Invocable via /nob:tech-lead or through the Nob hub after the PM Agent."
---

# Nob — Tech Lead Agent

## Overview
Tech Lead translates PM product requirements into a complete technical specification, then actively manages Backend and Frontend implementation. It holds authority over all technical decisions end-to-end: contracts, schemas, sequencing, and blocker resolution. Human escalation is reserved for decisions outside its technical authority (product intent) or high-risk flags ([AUTH], [BREAKING]).

## Step 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. Ask the user for the PM output or spec file path.

## Step 1: Read technical context

Read `CLAUDE.md` at the repo root — understand conventions, stack, folder structure. If not found, note it and continue.

Read `.nob.yml` at the repo root using the Read tool. Extract:
- `stack.backend.type` and `stack.backend.path`
- `stack.frontend.type` and `stack.frontend.path`
- `agents.max_parallel_slices` (default: 3)
- `agents.max_retries` (default: 3)

### Step 1.5: Discover affected files

Extract 3–5 key entity, route, or component names from the PM output. For each key term, run targeted searches:

```bash
# Backend — routes, services, controllers, models
grep -rl "<term>" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.rb" . 2>/dev/null | grep -v node_modules | head -10

# Schema / migrations
find . \( -name "*.prisma" -o -name "schema.rb" -o -name "*.migration.*" -o -name "*.sql" \) 2>/dev/null | grep -v node_modules | head -5

# Frontend — components, screens, pages, views
grep -rl "<term>" --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.dart" . 2>/dev/null | grep -v node_modules | head -10
```

Store results as AFFECTED_FILES = { backend: [...], schema: [...], frontend: [...] }.

## Step 2: Write technical specification

From PM output, derive and write the following. Do NOT invent requirements — derive only from PM output.

### 2a: API contracts

For each backend change in PM output:
- Extract HTTP method and path
- Define request shape: `{ fieldName: type }` — use exact field names from PM output; write `type: unknown — decide in implementation` for unspecified types
- Define response shape: same approach
- Note auth requirements, pagination, idempotency if implied by PM output

If no backend API changes: write `none`.

### 2b: Data schemas

For each entity implied by PM output that involves persistence:
- Name the entity and map it to a database table/collection if applicable
- List fields with types: use exact names from PM output; write `type: unknown` for unspecified
- Note relationships to other entities if implied

If no data persistence implied: write `none`.

### 2c: Risk flags

Scan PM output and AFFECTED_FILES for:
- `[AUTH]` — changes touching authentication, authorization, permissions, or middleware
- `[MIGRATION]` — changes to database schema, model fields, or existing data structure
- `[BREAKING]` — changes to an existing API endpoint's contract (method, path, request/response shape)
- `[SHARED]` — changes to shared utilities, core modules, or types used across multiple layers

If none apply: write `none`.

**Escalate high-risk flags immediately:** If `[AUTH]` or `[BREAKING]` flags are present, print:
```
Risk escalation: [flag] detected — [description].
Proposed resolution: [your recommendation].
Approve or override?
```
Wait for user response before dispatching dev agents.

### 2d: Per-layer task breakdown

Write specific tasks for Backend and Frontend using file paths from AFFECTED_FILES where known.

Backend tasks example format:
- "Add `POST /api/profiles` handler in `src/routes/profiles.ts`, extend `prisma/schema.prisma` User model with `avatarUrl: String?`"

Frontend tasks example format:
- "Add ProfileEditor component in `apps/frontend/src/components/ProfileEditor.tsx`, wire to `GET /api/profiles` endpoint"

## Step 3: Determine run mode

Count independent work streams from PM output:
- A work stream is independent if it shares no API contracts or UI state with other streams
- When in doubt: `Mode: single`

If 1 independent work stream → `Mode: single`
If 2+ independent work streams → `Mode: fan-out` (cap at `max_parallel_slices`)

## Step 4: Dispatch dev team

Read SKILL_BASE_DIR from the system context line `Base directory for this skill:`. Sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md`.

Read `{SKILL_BASE_DIR}/../backend/SKILL.md` and `{SKILL_BASE_DIR}/../frontend/SKILL.md`.

### Single mode

Dispatch Backend and Frontend in the same assistant turn (parallel). Use models from [INPUTS] `Agent models:` block.

**Backend Agent prompt:**

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../backend/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from [INPUTS]}

Stack guidance path: {backend stack guidance path from [INPUTS]}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from Tech Lead:
[TECH LEAD SPEC]
API contracts:
{API contracts from Step 2a}

Data schemas:
{data schemas from Step 2b}

Backend tasks:
{backend task list from Step 2d}

Affected files:
{AFFECTED_FILES.backend and AFFECTED_FILES.schema}
[/TECH LEAD SPEC]

Acceptance criteria:
{PM output acceptance criteria}

Project memory:
{project memory from [INPUTS]}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first. Stop before reaching the limit. List remaining work under Deferred items: in your output.

BLOCKER PROTOCOL: If you encounter a blocker you cannot resolve (schema ambiguity, missing contract, cross-layer dependency), emit a [BLOCKER] block before your [BACKEND OUTPUT] block:
[BLOCKER]
type: technical | ambiguity | cross-layer | risk
flag: AUTH | MIGRATION | BREAKING | SHARED | none
description: <one sentence>
proposed_resolution: <your best answer, or: none>
blocking_layer: backend | frontend | both
[/BLOCKER]
Then emit [BACKEND OUTPUT] with whatever you completed before the blocker.
[/INPUTS]
```

**Frontend Agent prompt:**

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../frontend/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from [INPUTS]}

Stack guidance path: {frontend stack guidance path from [INPUTS]}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from Tech Lead:
[TECH LEAD SPEC]
API contracts:
{API contracts from Step 2a — use these as the authoritative source for all API calls}

Data schemas:
{data schemas from Step 2b}

Frontend tasks:
{frontend task list from Step 2d}

Affected files:
{AFFECTED_FILES.frontend}
[/TECH LEAD SPEC]

Acceptance criteria:
{PM output acceptance criteria}

Backend Agent is running in parallel — use API contracts from Tech Lead spec above as the authoritative source.

Project memory:
{project memory from [INPUTS]}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first. Stop before reaching the limit. List remaining work under Deferred items: in your output.

BLOCKER PROTOCOL: If you encounter a blocker you cannot resolve, emit a [BLOCKER] block before your [FRONTEND OUTPUT] block:
[BLOCKER]
type: technical | ambiguity | cross-layer | risk
flag: AUTH | MIGRATION | BREAKING | SHARED | none
description: <one sentence>
proposed_resolution: <your best answer, or: none>
blocking_layer: backend | frontend | both
[/BLOCKER]
Then emit [FRONTEND OUTPUT] with whatever you completed before the blocker.
[/INPUTS]
```

### Fan-out mode

For each slice (up to `max_parallel_slices` at a time):
- Scope the API contracts, schemas, and task breakdown to that slice's work stream
- Dispatch one Backend + one Frontend per slice, all slices in the same assistant turn

Store each slice result keyed by slice name.

## Step 5: Active blocker resolution loop

After Backend and Frontend agents return their results, check for `[BLOCKER]` blocks.

**Blocker resolution policy:**

| Blocker type | Resolution |
|---|---|
| `type: technical` | Resolve autonomously: pick the best option from your technical context. Amend the relevant section of the Tech Lead spec. Re-dispatch only the blocked agent with the resolved spec. |
| `type: ambiguity` | Check PM output first. If resolvable from PM output: resolve autonomously. If not resolvable: escalate to human. Print the blocker description and your proposed resolution. Wait for human approval or override. Resume after response. |
| `type: cross-layer` | Coordinate: extract the relevant partial output from the other layer (e.g. Backend's interim API contract) and inject it into the blocked layer's re-dispatch prompt. |
| `type: risk` (AUTH or BREAKING) | Always escalate to human. Print the blocker and proposed resolution. Wait for human response before re-dispatching. |

**Re-dispatch only the blocked layer.** The unblocked layer's output is held as-is.

**Max blocker resolution passes:** 3. If the same blocker appears after 3 re-dispatches, mark it as unresolved and include it in `[TECH LEAD OUTPUT]` under `Unresolved blockers:`. Do not block the pipeline — pass through to Reviewer with the blocker noted.

Loop until all layers emit `[DONE]` (no more `[BLOCKER]` blocks) or max passes reached.

**Note:** A `[BLOCKER]` block alongside a `[BACKEND OUTPUT]` or `[FRONTEND OUTPUT]` block means the agent completed partial work before blocking. Preserve the partial output and re-dispatch only for the remaining work described in the blocker.

## Step 6: Cross-layer contract check

Before emitting output:

1. Check PM output acceptance criteria → Backend contracts: does Backend implement all API changes needed?
2. Check PM output acceptance criteria → Frontend contracts: does Frontend consume the required endpoints?
3. Check Tech Lead contracts → Frontend actual usage: does Frontend call the endpoints Tech Lead specified?

If violations found: note them in `[TECH LEAD OUTPUT]` under `Contract violations:`. Do not block — Reviewer will catch them.

## Output Format Requirement

Your output must include three labeled blocks in this order:

1. `[TECH LEAD OUTPUT]...[/TECH LEAD OUTPUT]`
2. `[BACKEND OUTPUT]...[/BACKEND OUTPUT]` (forwarded from Backend agent, or constructed from fan-out slice outputs)
3. `[FRONTEND OUTPUT]...[/FRONTEND OUTPUT]` (forwarded from Frontend agent, or constructed from fan-out slice outputs)

Missing blocks will cause your output to be re-requested by the Hub.

## Output Format

```
[TECH LEAD OUTPUT]
Run mode: single | fan-out (N slices)
Affected layers: frontend | backend | frontend + backend

API contracts written:
- [METHOD] [/path]: request: { fieldName: type } → response: { fieldName: type }
- none

Data schemas written:
- [EntityName]: { fieldName: type, ... }
- none

Risks:
- [AUTH | MIGRATION | BREAKING | SHARED] [description]
- none

Escalations made:
- [description of what was escalated and human's response, or: none]

Unresolved blockers:
- [BLOCKER description, or: none]

Contract violations:
- [violation description, or: none]
[/TECH LEAD OUTPUT]

[BACKEND OUTPUT]
{forward the complete [BACKEND OUTPUT] block from the Backend agent exactly as returned}
[/BACKEND OUTPUT]

[FRONTEND OUTPUT]
{forward the complete [FRONTEND OUTPUT] block from the Frontend agent exactly as returned}
[/FRONTEND OUTPUT]
```

For fan-out mode, merge all slice Backend outputs under a single `[BACKEND OUTPUT]` block (labeled by slice), and all slice Frontend outputs under a single `[FRONTEND OUTPUT]` block.

## Error Handling

- **PM output missing API contracts section**: derive contracts from PM's `Backend changes needed:` field. If insufficient: flag as `[non-blocking]` ambiguity and make a reasonable assumption.
- **Backend agent returns no [BACKEND OUTPUT]**: re-dispatch once. If still missing: mark `backend: failed` in output and proceed with Frontend only.
- **Frontend agent returns no [FRONTEND OUTPUT]**: re-dispatch once. If still missing: mark `frontend: failed` in output and proceed with Backend only.
- **Both agents fail**: emit `[TECH LEAD OUTPUT]` with failure status. Do not emit Backend or Frontend blocks. Hub will stop pipeline.
- **Max blocker passes reached**: include remaining blockers in `Unresolved blockers:` and continue.
- **CLAUDE.md not found**: note it and continue.
- **.nob.yml not found**: use defaults (max_parallel_slices: 3, max_retries: 3).
````

- [ ] **Step 3: Verify the file was created**

```bash
ls -la skills/tech-lead/SKILL.md
```

Expected: file exists with non-zero size.

- [ ] **Step 4: Read back and verify key sections are present**

Read `skills/tech-lead/SKILL.md` and confirm these headings exist:
- `## Step 0: Mode Detection`
- `## Step 2: Write technical specification`
- `## Step 4: Dispatch dev team`
- `## Step 5: Active blocker resolution loop`
- `## Output Format`

- [ ] **Step 5: Commit**

```bash
git add skills/tech-lead/SKILL.md
git commit -m "feat: add Tech Lead agent skill"
```

---

## Task 2: Update `skills/nob/SKILL.md` — Slim the Hub

**Files:**
- Modify: `skills/nob/SKILL.md`

This task makes 5 targeted edits to the Hub. Read the file before editing.

- [ ] **Step 1: Read the current Hub skill**

Read `skills/nob/SKILL.md` to confirm current content before editing.

- [ ] **Step 2: Update the frontmatter description**

Find:
```
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, or migrate an existing project to nob''s monorepo structure. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [intent]". Orchestrates Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer in sequence. Also auto-detects structure mismatch on any run and offers refactor before proceeding.'
```

Replace with:
```
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, or migrate an existing project to nob''s monorepo structure. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [intent]". Orchestrates PM Agent → Tech Lead Agent → Security → Reviewer in sequence. Also auto-detects structure mismatch on any run and offers refactor before proceeding.'
```

- [ ] **Step 3: Update the RESOLVED_CONFIG auto-detection defaults**

Find the `agents:` section inside the auto-detection YAML block (the block starting with `agents:\n  enabled: [planner, pm, backend, frontend, security, reviewer, ideation, ask]`):

Replace:
```yaml
agents:
  enabled: [planner, pm, backend, frontend, security, reviewer, ideation, ask]
  models:
    backend: sonnet
    frontend: sonnet
    planner: haiku
    pm: haiku
    reviewer: haiku
    security: haiku
    init: sonnet
    idea-framer: haiku
    market-researcher: sonnet
    business-modeler: haiku
    gtm-strategist: haiku
    financial-modeler: haiku
    venture-reviewer: haiku
    refactor: sonnet
    ideation: haiku
    ask: haiku
  max_parallel_slices: 3
  venture:
    enabled: true
  checkpoint:
    enabled: true
    path: .nob/
```

With:
```yaml
agents:
  enabled: [pm, tech-lead, backend, frontend, security, reviewer, ideation, ask]
  models:
    backend: sonnet
    frontend: sonnet
    tech-lead: sonnet
    pm: haiku
    reviewer: haiku
    security: haiku
    init: sonnet
    idea-framer: haiku
    market-researcher: sonnet
    business-modeler: haiku
    gtm-strategist: haiku
    financial-modeler: haiku
    venture-reviewer: haiku
    refactor: sonnet
    ideation: haiku
    ask: haiku
  max_parallel_slices: 3
  venture:
    enabled: true
  checkpoint:
    enabled: true
    path: .nob/
```

- [ ] **Step 4: Update the Output Block Validation table**

Find the table row for Planner:
```
| Planner | `Workflow:`, `Mode:`, `Affected layers:`, `Risks:`, `Ambiguities:` |
```

Replace with:
```
| Tech Lead | `Run mode:`, `Affected layers:`, `API contracts written:`, `Risks:` |
```

Also find the PM Agent validation row:
```
| PM Agent | `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:` |
```

Replace with:
```
| PM Agent | `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:` |
```

- [ ] **Step 4b: Fix model resolution — remove L3 complexity override**

In the Hub's `## Step 1: Read project config` section, find the `**L3: Complexity-based model override**` block (it reads `Complexity:` from `PLAN_OUTPUT` and may downgrade backend/frontend models to haiku).

Delete the entire L3 block. In its place, in the `### Extract from RESOLVED_CONFIG` section, add these two lines after the other extractions:

```
- `BACKEND_MODEL_RESOLVED` = `agents.models["backend"] ?? "sonnet"` — Tech Lead handles complexity-based dispatch internally
- `FRONTEND_MODEL_RESOLVED` = `agents.models["frontend"] ?? "sonnet"`
```

- [ ] **Step 4c: Fix --plan-only early exit**

Find the `**M3: --plan-only early exit**` block inside Phase 1. It currently prints `PLAN_OUTPUT` verbatim.

Replace the entire M3 block with:

```markdown
**M3: --plan-only early exit**

If PLAN_ONLY = true:
- Dispatch PM Agent only (same prompt as Phase 2 PM dispatch below).
- Print PM_OUTPUT verbatim.
- Print: `"Plan-only run complete — PM requirements extracted. Re-run without --plan-only to execute full pipeline."`
- Exit. Do not write a checkpoint. Do not dispatch Tech Lead or any further agents.
```

- [ ] **Step 5: Replace Phase 1 (Planner dispatch) with Tech Lead setup**

Find the entire `## Phase 1: Slice plan` section (from `## Phase 1: Slice plan` down to, but not including, `## Phase 2: Parallel pipelines`).

Replace the entire Phase 1 section with:

```markdown
## Phase 1: (retired — Planner merged into Tech Lead)

Planner is no longer dispatched as a separate phase. Tech Lead reads the spec directly and produces the plan as part of its technical specification step.

Proceed directly to Phase 2.

---
```

- [ ] **Step 6: Replace Phase 2 Single-slice path**

Find the section `### Single-slice path (Mode: single)` down to and including the line `Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]`.

Replace it entirely with:

```markdown
### Single-slice path

Run PM Agent first (sequential), then Tech Lead (which manages Backend + Frontend internally).

**Agent 1 — PM Agent**

Run `date +%s` via the Bash tool and store as PM_START_EPOCH.

Read `{SKILL_BASE_DIR}/../pm/SKILL.md`. Dispatch with `model: agents.models["pm"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

Project memory:
{PROJECT_MEMORY}
[/INPUTS]
```

Extract `[PM OUTPUT]...[/PM OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

Run `date +%s` and store as PM_END_EPOCH. Compute PM_DURATION_MS = (PM_END_EPOCH - PM_START_EPOCH) × 1000. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  pm              {model}  OK    {PM_DURATION_MS}ms`.

---

**Agent 2 — Tech Lead Agent**

Run `date +%s` via the Bash tool and store as TL_START_EPOCH.

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch with `model: agents.models["tech-lead"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../tech-lead/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

Backend stack guidance path: {BACKEND_STACK_GUIDANCE_PATH}
Frontend stack guidance path: {FRONTEND_STACK_GUIDANCE_PATH}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

PM Agent output:
{PM_OUTPUT}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}

Project memory:
{PROJECT_MEMORY}

Agent models:
  backend: {BACKEND_MODEL_RESOLVED}
  frontend: {FRONTEND_MODEL_RESOLVED}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]...[/TECH LEAD OUTPUT]`. Store as TECH_LEAD_OUTPUT. Apply Output Block Validation for Tech Lead.
Extract `[BACKEND OUTPUT]...[/BACKEND OUTPUT]`. Store as BACKEND_OUTPUT.
Extract `[FRONTEND OUTPUT]...[/FRONTEND OUTPUT]`. Store as FRONTEND_OUTPUT.

If BACKEND_OUTPUT or FRONTEND_OUTPUT is missing: re-dispatch Tech Lead once with the same prompt. If still missing after re-dispatch: mark the missing layer as `failed`; proceed with available outputs.

Run `date +%s` and store as TL_END_EPOCH. Compute TL_DURATION_MS = (TL_END_EPOCH - TL_START_EPOCH) × 1000. Append to RUN_LOG_PATH:
```
{date -u +%FT%TZ}  tech-lead       {model}  OK    {TL_DURATION_MS}ms
{date -u +%FT%TZ}  backend         {BACKEND_MODEL_RESOLVED}  OK    {TL_DURATION_MS}ms
{date -u +%FT%TZ}  frontend        {FRONTEND_MODEL_RESOLVED}  OK    {TL_DURATION_MS}ms
```

Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]

Proceed to Phase 2.5.
```

- [ ] **Step 7: Replace Phase 2 Fan-out path**

Find the section `### Fan-out path (Mode: fan-out)` through the end of Phase 2 (the `---` before Phase 2.5).

Replace it entirely with:

```markdown
### Fan-out path (Mode: fan-out)

PM Agent runs once for the full spec (same as single-slice path above — run it first if not already done). Then dispatch Tech Lead with fan-out context:

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch Tech Lead with `model: agents.models["tech-lead"] ?? "sonnet"` using the same prompt as the single-slice path, but append to the [INPUTS] block:

```
Fan-out mode: true
Max parallel slices: {agents.max_parallel_slices}
Spec file path: {spec file path}
Spec file contents: {spec file content}
```

Tech Lead determines slices internally and dispatches N Backend+Frontend pairs concurrently (up to max_parallel_slices).

Extract `[TECH LEAD OUTPUT]`, `[BACKEND OUTPUT]`, and `[FRONTEND OUTPUT]` from the result. For fan-out runs, Backend and Frontend outputs will contain labeled slice sections.

Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]

Proceed to Phase 2.5.
```

- [ ] **Step 8: Update Phase 3.5 retry to re-dispatch Tech Lead**

Find in Phase 3.5 the section starting with `**Backend retry** (if RETRY_BACKEND = true)` through `Extract \`[FRONTEND OUTPUT]...[/FRONTEND OUTPUT]\`. Replace FRONTEND_OUTPUT with this result.`

Replace it with:

```markdown
**Tech Lead retry** (re-dispatches only failing layer(s)):

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch Tech Lead with `model: agents.models["tech-lead"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../tech-lead/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

Backend stack guidance path: {BACKEND_STACK_GUIDANCE_PATH}
Frontend stack guidance path: {FRONTEND_STACK_GUIDANCE_PATH}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

PM Agent output:
{PM_OUTPUT}

Reviewer found these failures — re-implement only the failing layer(s):
{RETRY_ITEMS listed one per line}

Layers to retry:
  backend: {RETRY_BACKEND}
  frontend: {RETRY_FRONTEND}

{if BACKEND_FIX_SCOPE non-null:
Backend fix scope (touch only these files):
{BACKEND_FIX_SCOPE listed one path per line}
}
{if FRONTEND_FIX_SCOPE non-null:
Frontend fix scope (touch only these files):
{FRONTEND_FIX_SCOPE listed one path per line}
}

Root cause (from diagnostic):
{DIAG_OUTPUT "Root cause summary:" line, or: "Diagnostic not available — use your judgment"}

Project memory:
{PROJECT_MEMORY}

Agent models:
  backend: {BACKEND_MODEL_RESOLVED}
  frontend: {FRONTEND_MODEL_RESOLVED}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]`, `[BACKEND OUTPUT]`, and `[FRONTEND OUTPUT]`. Replace TECH_LEAD_OUTPUT, BACKEND_OUTPUT, and FRONTEND_OUTPUT with results.
```

- [ ] **Step 9: Update the terminal summary Agents line**

Find in Step 4 terminal summary:
```
Agents:    [each agent that ran as "name(model)" separated by " · " — e.g.: planner(haiku) · pm(haiku) · backend(sonnet) · frontend(sonnet) · security(haiku) · reviewer(haiku). List only agents that actually ran; skip disabled/skipped agents. Use BACKEND_MODEL_RESOLVED and FRONTEND_MODEL_RESOLVED for those two agents.]
```

Replace with:
```
Agents:    [each agent that ran as "name(model)" separated by " · " — e.g.: pm(haiku) · tech-lead(sonnet) · backend(sonnet) · frontend(sonnet) · security(haiku) · reviewer(haiku). List only agents that actually ran; skip disabled/skipped agents. Use BACKEND_MODEL_RESOLVED and FRONTEND_MODEL_RESOLVED for those two agents.]
```

- [ ] **Step 10: Verify the file reads correctly**

Read `skills/nob/SKILL.md` lines 1-50 to confirm frontmatter updated.
Grep for `Planner` to ensure no remaining references outside of error handling and comments:

```bash
grep -n "Planner\|planner" skills/nob/SKILL.md
```

Expected: only error handling entries and the retired Phase 1 notice. No active dispatch calls.

- [ ] **Step 11: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: slim Hub — replace Planner+Backend+Frontend phases with Tech Lead dispatch"
```

---

## Task 3: Update `skills/pm/SKILL.md` — Narrow to Product Requirements

**Files:**
- Modify: `skills/pm/SKILL.md`

PM Agent must stop writing API contracts and data schemas. Those move to Tech Lead.

- [ ] **Step 1: Read the current PM skill**

Read `skills/pm/SKILL.md` to confirm current content.

- [ ] **Step 2: Update Spec-Writing Mode — remove API contracts and data models**

Find the `NEEDS_API_CONTRACTS` and `NEEDS_DATA_MODELS` evaluation block (the two lines starting with `- **NEEDS_API_CONTRACTS**`).

Delete both evaluation lines and replace the spec file template's `## API contracts` and `## Data models` sections with the following in the template:

Find:
```markdown
## API contracts
<!-- Include this section only when NEEDS_API_CONTRACTS = true. Otherwise write: not applicable -->
- [METHOD] /exact/path
  - Request: `{ fieldName: type, fieldName: type }`
  - Response: `{ fieldName: type, fieldName: type }`
  - Notes: [auth required? idempotent? paginated?]
<!-- One block per endpoint. Use exact field names from CLARIFICATIONS where given.
     Write `type: unknown — to be decided` for any field whose type was not specified. -->

## Data models
<!-- Include this section only when NEEDS_DATA_MODELS = true. Otherwise write: not applicable -->
[Entity name]:
  - fieldName: type        # [brief note on what this field holds]
  - fieldName: type
<!-- One block per entity. If the entity maps to a database table or file format, say so.
     Write `type: unknown — to be decided` for any field whose type was not specified.
     Do not invent fields not implied by CLARIFICATIONS — write `not specified` instead. -->
```

Replace with:
```markdown
## API contracts
not applicable — API contracts are defined by the Tech Lead Agent during implementation

## Data models
not applicable — data schemas are defined by the Tech Lead Agent during implementation
```

Also delete the two `NEEDS_API_CONTRACTS`/`NEEDS_DATA_MODELS` evaluation lines before the Write step:

Find and delete:
```
- **NEEDS_API_CONTRACTS** = true if answers mention HTTP endpoints, client-server data exchange, a new route, a REST or GraphQL call, or any named API operation.
- **NEEDS_DATA_MODELS** = true if answers mention persisting data, a database record, a file format, a structured object with named fields, or any schema the system stores or returns.
```

- [ ] **Step 3: Update Requirements Extraction Mode output — remove API contracts**

Find the `[PM OUTPUT]` format block and remove the `API contracts:` field:

Find:
```
API contracts:
- [METHOD] [/exact/path]: request: { fieldName: type, ... } → response: { fieldName: type, ... }
- none — no HTTP API changes in this feature
```

Replace with:
```
API contracts:
not applicable — defined by Tech Lead Agent
```

- [ ] **Step 4: Update the Output Block Validation requirement in the PM skill**

Find (in the Output Format Requirement section):
```
- Include every required field: `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:`
```

Replace with:
```
- Include every required field: `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:`
```

- [ ] **Step 5: Update Step 1c (Third-party API lookup)**

The third-party API lookup step currently fetches API shapes for the PM contracts. Since PM no longer writes contracts, update the last sentence of the step:

Find:
```
5. Use `THIRD_PARTY_CONTEXT` when writing `API contracts:` in Step 2 — replace inferred shapes with authoritative ones.
```

Replace with:
```
5. Store `THIRD_PARTY_CONTEXT` in your output under `Third-party API notes:` — the Tech Lead Agent will use these when writing API contracts.
```

And update the PM OUTPUT block to include:
After `Ambiguities flagged:`, add:
```
Third-party API notes:
- [service name]: [relevant API shape or endpoint, or: none]
```

- [ ] **Step 6: Verify**

```bash
grep -n "API contracts\|Data models\|NEEDS_API" skills/pm/SKILL.md
```

Expected: `API contracts` appears only as `not applicable` or `Third-party API notes` pass-through. No `NEEDS_API_CONTRACTS` evaluation.

- [ ] **Step 7: Commit**

```bash
git add skills/pm/SKILL.md
git commit -m "feat: narrow PM Agent — remove API contracts and data schemas (moved to Tech Lead)"
```

---

## Task 4: Update `skills/backend/SKILL.md` — Receive Tech Lead Spec, Emit BLOCKER/DONE

**Files:**
- Modify: `skills/backend/SKILL.md`

Backend Agent now receives a Tech Lead spec (not PM output) and must emit `[BLOCKER]` blocks when blocked.

- [ ] **Step 1: Read the current Backend skill**

Read `skills/backend/SKILL.md` to confirm current content and understand its input/output structure.

- [ ] **Step 2: Update the input section description**

Find any section that describes "Requirements from PM Agent" in the instructions and update it to reference Tech Lead:

Find (anywhere in the file):
```
Requirements from PM Agent:
```

Replace with (replace_all: true):
```
Requirements from Tech Lead:
```

- [ ] **Step 3: Add BLOCKER protocol section**

Find the Output Format section in the backend skill (the section describing `[BACKEND OUTPUT]`). Add the following section immediately before it:

```markdown
## Blocker Protocol

If you encounter an issue you cannot resolve on your own, emit a `[BLOCKER]` block immediately before your `[BACKEND OUTPUT]` block.

When to emit a blocker:
- Schema ambiguity that would change the API contract (e.g., unsure whether a field should be nullable)
- Missing specification for a required endpoint
- Dependency on a Frontend contract that is not yet defined
- Risk flag discovered during implementation ([AUTH], [MIGRATION], [BREAKING], [SHARED])

Blocker block format:
```
[BLOCKER]
type: technical | ambiguity | cross-layer | risk
flag: AUTH | MIGRATION | BREAKING | SHARED | none
description: <one sentence describing the blocker>
proposed_resolution: <your best suggestion, or: none>
blocking_layer: backend | frontend | both
[/BLOCKER]
```

Emit the blocker, then continue implementing as much as possible. Emit `[BACKEND OUTPUT]` with whatever you completed, noting the remaining work under `Deferred items:`.

Do NOT halt and wait — always emit both a `[BLOCKER]` (if blocked) and a `[BACKEND OUTPUT]`.
```

- [ ] **Step 4: Verify**

```bash
grep -n "Tech Lead\|BLOCKER\|PM Agent" skills/backend/SKILL.md
```

Expected: "Requirements from Tech Lead" present, "BLOCKER" block documented, no remaining "Requirements from PM Agent" references.

- [ ] **Step 5: Commit**

```bash
git add skills/backend/SKILL.md
git commit -m "feat: update Backend Agent — receive Tech Lead spec, add BLOCKER protocol"
```

---

## Task 5: Update `skills/frontend/SKILL.md` — Receive Tech Lead Spec, Emit BLOCKER/DONE

**Files:**
- Modify: `skills/frontend/SKILL.md`

Identical changes to Task 4 but for the Frontend skill. Also update the reference to "API contracts from PM Agent" which Frontend currently uses.

- [ ] **Step 1: Read the current Frontend skill**

Read `skills/frontend/SKILL.md` to confirm current content.

- [ ] **Step 2: Update input references from PM Agent to Tech Lead**

Find (replace_all: true):
```
Requirements from PM Agent:
```
Replace with:
```
Requirements from Tech Lead:
```

Find:
```
Backend Agent is running in parallel — use API contracts from PM Agent output above.
```
Replace with:
```
Backend Agent is running in parallel — use API contracts from Tech Lead spec above as the authoritative source.
```

- [ ] **Step 3: Add BLOCKER protocol section**

Add the same BLOCKER protocol section as in Task 4 immediately before the Output Format section.

The blocker block format is identical to Backend's.

- [ ] **Step 4: Verify**

```bash
grep -n "Tech Lead\|BLOCKER\|PM Agent" skills/frontend/SKILL.md
```

Expected: "Requirements from Tech Lead" present, "BLOCKER" block documented, no remaining "PM Agent" references to API contracts.

- [ ] **Step 5: Commit**

```bash
git add skills/frontend/SKILL.md
git commit -m "feat: update Frontend Agent — receive Tech Lead spec, add BLOCKER protocol"
```

---

## Task 6: Retire `skills/planner/SKILL.md`

**Files:**
- Modify: `skills/planner/SKILL.md`

Add a deprecation notice at the top so any direct `/nob:planner` invocation explains the change.

- [ ] **Step 1: Read the current Planner skill**

Read `skills/planner/SKILL.md` lines 1-10 to see the frontmatter.

- [ ] **Step 2: Update the frontmatter description**

Find the `description:` field in the frontmatter. Replace its value with:

```
description: "DEPRECATED — Planner has been retired. Its responsibilities (technical planning, API contract definition, risk flagging, fan-out decisions) are now handled by the Tech Lead Agent. Use /nob:tech-lead or run /nob to trigger the full pipeline."
```

- [ ] **Step 3: Add deprecation banner at top of content**

Find the line `# Nob — Planner Agent` and replace it with:

```markdown
# Nob — Planner Agent (DEPRECATED)

> **This skill is retired.** Planner's responsibilities have been merged into the Tech Lead Agent (`skills/tech-lead/SKILL.md`). If you are seeing this, invoke `/nob:tech-lead` or run `/nob implement <spec>` to use the updated pipeline.

---
```

- [ ] **Step 4: Verify**

```bash
head -20 skills/planner/SKILL.md
```

Expected: deprecation notice visible in first 20 lines.

- [ ] **Step 5: Commit**

```bash
git add skills/planner/SKILL.md
git commit -m "chore: deprecate Planner skill — content merged into Tech Lead"
```

---

## Task 7: Update `.nob.yml.template` and `CLAUDE.md`

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read both files**

Read `skills/nob/templates/.nob.yml.template` and `CLAUDE.md`.

- [ ] **Step 2: Update `.nob.yml.template` — add tech_lead model, swap planner**

Find in the `agents:` → `enabled:` list:
```yaml
  enabled:
    - planner
    - pm
    - backend
    - frontend
    - security
    - reviewer
    - ideation
    - ask
```

Replace with:
```yaml
  enabled:
    - pm
    - tech-lead
    - backend
    - frontend
    - security
    - reviewer
    - ideation
    - ask
```

Find in the `models:` block:
```yaml
    planner: haiku          # planning/review/qa agents can use haiku
    pm: haiku
```

Replace with:
```yaml
    tech-lead: sonnet       # tech lead writes contracts and coordinates dev team
    pm: haiku
```

- [ ] **Step 3: Update `CLAUDE.md` — repo structure table**

Find in the repo structure table:
```
  planner/        — Breaks the spec into a sequenced plan (/nob:planner)
```

Replace with:
```
  tech-lead/      — Technical lead: writes contracts, coordinates dev team (/nob:tech-lead)
  planner/        — DEPRECATED: merged into tech-lead
```

- [ ] **Step 4: Update `CLAUDE.md` — pipeline description**

Find:
```
**Planner → PM → Backend + Frontend (concurrent) → Security → Reviewer**
```

Replace with:
```
**PM → Tech Lead → Security → Reviewer**

(Tech Lead dispatches Backend + Frontend concurrently and manages the active blocker loop internally.)
```

- [ ] **Step 5: Verify both files**

```bash
grep -n "planner\|tech-lead\|Tech Lead" skills/nob/templates/.nob.yml.template CLAUDE.md
```

Expected: `tech-lead` present in both files. `planner` appears only in the deprecated note in CLAUDE.md.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/templates/.nob.yml.template CLAUDE.md
git commit -m "chore: update .nob.yml.template and CLAUDE.md for Tech Lead pipeline"
```

---

## Final Verification

- [ ] **Step 1: Check for orphaned Planner references in Hub**

```bash
grep -n "planner\|Planner" skills/nob/SKILL.md | grep -v "retired\|DEPRECATED\|error"
```

Expected: zero active dispatch references to Planner.

- [ ] **Step 2: Check for PM-owned API contracts in Hub flow**

```bash
grep -n "API contracts" skills/pm/SKILL.md
```

Expected: only `not applicable` lines.

- [ ] **Step 3: Check Tech Lead is dispatched in Hub**

```bash
grep -n "tech-lead\|Tech Lead" skills/nob/SKILL.md
```

Expected: Tech Lead dispatch present in Phase 2.

- [ ] **Step 4: Check Backend and Frontend reference Tech Lead**

```bash
grep -n "Tech Lead\|BLOCKER" skills/backend/SKILL.md skills/frontend/SKILL.md
```

Expected: both files contain "Tech Lead" and "BLOCKER" references.

- [ ] **Step 5: Final commit summary**

```bash
git log --oneline -8
```

Expected: 7 commits visible covering all tasks in this plan.
