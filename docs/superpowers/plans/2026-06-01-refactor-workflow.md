# Refactor Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/nob refactor` workflow that migrates existing projects to nob's monorepo structure (`apps/frontend/`, `apps/backend/`, `shared/core/`), including directory moves, import rewrites, and config generation.

**Architecture:** A new `refactor-agent` sub-skill handles analysis, plan presentation, user approval, and execution. The hub gets two additions: a Step 0.5 structure-check that auto-detects mismatch on any run and offers refactor before proceeding, and a new `Refactor` workflow type that routes directly to the refactor-agent and exits. After a mid-run refactor completes, the hub resumes the original pipeline from Step 1.

**Tech Stack:** Markdown skill files only — no build system or tests. Verification steps are read-and-check-against-spec.

---

### Task 1: Create `skills/nob/refactor-agent/SKILL.md`

**Files:**
- Create: `skills/nob/refactor-agent/SKILL.md`

- [ ] **Step 1: Verify the directory doesn't exist yet**

```bash
ls skills/nob/refactor-agent/
```

Expected: `No such file or directory`

- [ ] **Step 2: Write the file**

Create `skills/nob/refactor-agent/SKILL.md` with this exact content:

```markdown
---
name: nob-refactor-agent
description: Migrates an existing project to nob's monorepo structure (apps/frontend/, apps/backend/, shared/core/). Analyzes the current layout, presents a migration plan, and executes on user approval. Moves directories with git history preservation, rewrites cross-layer import paths, and writes CLAUDE.md and .nob.yml.
---

# Nob — Refactor Agent

## Overview
Migrate an existing project to nob's monorepo structure. Analyze the current layout, build a migration plan, show it to the user, and execute only on approval. Move directories, rewrite imports, and write nob config files.

---

## Inputs

Provided by the hub in the `[INPUTS]` block:
- `Working directory` — absolute path to the project root
- `Detected source paths` — frontend and backend dirs detected by the hub (e.g. `frontend/`, `backend/`), or "unknown"
- `Stack type` — if known from hub auto-detection or `.nob.yml` (e.g. `node`, `python`, `go`), or "unknown"
- `Original user intent` — the user's original message
- `Refactor mode` — `explicit` (standalone `/nob refactor`) or `mid-run` (auto-detected mismatch)

---

## Step 1: Analysis pass

Extract `Working directory` from `[INPUTS]`. Store as WORKING_DIR.

Run `ls -A {WORKING_DIR}` to list all top-level entries.

**Determine stack type** — use `Stack type` from inputs if provided and not "unknown"; otherwise detect from WORKING_DIR:
- Root `package.json` exists → JS/TS. Read it and check `dependencies` for `next` → `next`, `vue` → `vue`, `react` or `react-dom` → `react`, `express`/`fastify`/`koa` → `node`.
- Root `pyproject.toml` or `requirements.txt` → `python`.
- Root `go.mod` → `go`.
- `pubspec.yaml` → `flutter`.
- Cannot determine → store as "unknown".

Store as STACK_TYPE and FRONTEND_TYPE (the frontend framework name) and BACKEND_TYPE (the backend framework name).

**Check git**: run `git -C {WORKING_DIR} status`. Exit code 0 → IS_GIT_REPO = true. Otherwise IS_GIT_REPO = false.

**Identify source directories** — use `Detected source paths` from inputs if not "unknown"; otherwise scan WORKING_DIR:
- SOURCE_FRONTEND: first existing directory among `frontend/`, `web/`, `client/`, `app/` that is NOT `apps/frontend/`. Skip if `apps/frontend/` already exists.
- SOURCE_BACKEND: first existing directory among `backend/`, `server/`, `api/` that is NOT `apps/backend/`. Skip if `apps/backend/` already exists.
- If neither can be determined, set to null.

**Estimate import count**: if SOURCE_FRONTEND and SOURCE_BACKEND are both non-null and STACK_TYPE is JS/TS or Python, run:

For JS/TS:
```bash
grep -r "\.\./[frontend-or-backend-dirname]" {WORKING_DIR} --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" -l 2>/dev/null | wc -l
```

For Python:
```bash
grep -r "^from backend\.\|^import backend\." {WORKING_DIR} --include="*.py" -l 2>/dev/null | wc -l
```

Store result as IMPORT_FILE_COUNT. If command fails or returns 0: set IMPORT_FILE_COUNT = 0.

---

## Step 2: Build migration plan

Construct:
- MOVES: array of `{from, to}` pairs — only include dirs that exist and are not already at the target path:
  - If SOURCE_FRONTEND is non-null: `{from: SOURCE_FRONTEND, to: "apps/frontend"}`
  - If SOURCE_BACKEND is non-null: `{from: SOURCE_BACKEND, to: "apps/backend"}`
- NEW_DIRS: always `shared/core/contracts` and `shared/core/schema`; add `shared/core/package.json` if STACK_TYPE is JS/TS
- IMPORT_FILE_COUNT from Step 1
- CONFIG_FILES: `CLAUDE.md`, `.nob.yml`

---

## Step 3: Present plan to user

Print:

```
Nob Refactor Plan
─────────────────────────────────────
Moves:
  [for each move in MOVES: "  {from}/ → {to}/"]
  [if MOVES is empty: "  None — directory layout already correct"]

New directories:
  shared/core/contracts/
  shared/core/schema/
  [if JS/TS stack: "  shared/core/package.json"]

Import rewrites:
  [if IMPORT_FILE_COUNT > 0: "  ~{IMPORT_FILE_COUNT} files"]
  [if IMPORT_FILE_COUNT == 0: "  None detected"]

Config files:
  CLAUDE.md  (AI agent boundary rules)
  .nob.yml   (stack paths and agent config)

Proceed with refactor? (yes / cancel)
─────────────────────────────────────
```

Wait for user response:
- `cancel`, `no`, or any negative → emit `[REFACTOR-AGENT OUTPUT]` with `Status: cancelled` and exit.
- `yes` → proceed to Step 4.

---

## Step 4: Execution

Execute sub-steps in this exact order. If any sub-step fails, stop immediately — do NOT continue to the next sub-step. Emit `[REFACTOR-AGENT OUTPUT]` with `Status: failed`, list what succeeded and what failed, and exit.

### 4a. Git safety notice

If IS_GIT_REPO is true: print "Tip: run `git stash` if you want a clean rollback point before continuing."

### 4b. Move directories

Run `mkdir -p {WORKING_DIR}/apps` first.

For each `{from, to}` in MOVES:

If IS_GIT_REPO:
```bash
git -C {WORKING_DIR} mv {from} {to}
```
If `git mv` fails (e.g. unstaged changes blocking it): fall back to:
```bash
mv {WORKING_DIR}/{from} {WORKING_DIR}/{to}
```
Add to MOVE_WARNINGS: "`git mv` failed for `{from}` — run `git add -A` after refactor to stage the move."

If not IS_GIT_REPO:
```bash
mv {WORKING_DIR}/{from} {WORKING_DIR}/{to}
```

If the source directory doesn't exist: skip silently. Record as `skipped` in the output block.

### 4c. Create shared scaffold

```bash
mkdir -p {WORKING_DIR}/shared/core/contracts
mkdir -p {WORKING_DIR}/shared/core/schema
touch {WORKING_DIR}/shared/core/contracts/.gitkeep
touch {WORKING_DIR}/shared/core/schema/.gitkeep
```

If STACK_TYPE is JS/TS: write `{WORKING_DIR}/shared/core/package.json`:

```json
{
  "name": "@core/shared",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts"
}
```

### 4d. Rewrite imports

Walk all source files recursively in `{WORKING_DIR}/apps/frontend/` and `{WORKING_DIR}/apps/backend/`.

**JS/TS files** (`.ts`, `.tsx`, `.js`, `.jsx`):

For each import or require statement referencing the old frontend or backend directory name:
1. Identify the old path string (e.g. `'../backend/utils'`).
2. Resolve it to an absolute path using the importing file's pre-move location.
3. Compute the new relative path: from the importing file's current location inside `apps/` to the resolved target's new location inside `apps/`. Example: a file now at `apps/frontend/src/api/client.ts` importing `apps/backend/src/utils/auth.ts` gets the path `../../../backend/src/utils/auth`.
4. Replace the old path string with the computed path.

If a file contains a dynamic `require()` (variable as argument), a barrel re-export that can't be traced, or the path cannot be resolved: skip that file, add its path to IMPORT_WARNINGS.

Use the Edit tool to apply rewrites — one Edit call per file changed. Do not use `sed` or shell substitutions.

**Python files** (`.py`):

Replace:
- `from backend.` → `from apps.backend.`
- `import backend.` → `import apps.backend.`

Use the Edit tool with `replace_all: true` for each pattern per file.

**Go files** (`.go` and `go.mod`):

Read `{WORKING_DIR}/go.mod`. If the module path references the old backend directory name, update it. Update all matching `import` blocks in `.go` files.

Count total files where at least one import was rewritten. Store as IMPORTS_REWRITTEN.
Store skipped file paths as IMPORT_WARNINGS.

### 4e. Write config files

Detect project name: read root `package.json` `.name` field if it exists; otherwise use the basename of WORKING_DIR.

Write `{WORKING_DIR}/CLAUDE.md` (overwrite if exists) using the Write tool:

```markdown
# Project: {PROJECT_NAME}

## Stack
- Frontend: {FRONTEND_TYPE}
- Backend: {BACKEND_TYPE}

## Structure
- `apps/frontend/` — UI layer. Deployable target. No business logic.
- `apps/backend/`  — API layer. Deployable target. No shared contracts here.
- `shared/core/contracts/` — Source of truth for types and API shapes.
- `shared/core/schema/`    — Source of truth for database schema and migrations.

## AI Agent Rules
- Feature work → edit `apps/`
- Shared types or API shape changes → edit `shared/core/contracts/`
- Database changes → edit `shared/core/schema/`
- Adding a new domain → create `shared/[domain]/contracts/` and `shared/[domain]/schema/`
- Never put app-specific logic in `shared/`
- Never put shared contracts inside `apps/`

## API Conventions
- Base URL: /api/v1
- Error format: `{ "error": { "code": "string", "message": "string" } }`
```

Write `{WORKING_DIR}/.nob.yml` (overwrite if exists) using the Write tool:

```yaml
stack:
  frontend:
    enabled: true
    type: {FRONTEND_TYPE}
    path: apps/frontend/
  backend:
    enabled: true
    type: {BACKEND_TYPE}
    path: apps/backend/
  shared:
    core: shared/core/

agents:
  enabled: [planner, pm-agent, backend-agent, frontend-agent, qa-agent, reviewer]
  models:
    backend-agent: sonnet
    frontend-agent: sonnet
    planner: haiku
    pm-agent: haiku
    qa-agent: haiku
    reviewer: haiku
    refactor-agent: sonnet
  max_parallel_slices: 3
  checkpoint:
    enabled: true
    path: .nob/
```

---

## Step 5: Emit output block

```
[REFACTOR-AGENT OUTPUT]
Status: complete
Moves:
  {for each move: "{from} → {to}: success | skipped | failed"}
Shared: created
Imports rewritten: {IMPORTS_REWRITTEN}
Config: CLAUDE.md written, .nob.yml written
Warnings:
  {IMPORT_WARNINGS joined by newline, or "none"}
[/REFACTOR-AGENT OUTPUT]
```

If Step 4 was halted by failure: emit `Status: failed` and list which sub-step failed.
If Step 3 resulted in cancel: emit `Status: cancelled`.
```

- [ ] **Step 3: Verify file was created and contains expected sections**

```bash
grep -n "^## Step" skills/nob/refactor-agent/SKILL.md
```

Expected output (5 steps):
```
## Step 1: Analysis pass
## Step 2: Build migration plan
## Step 3: Present plan to user
## Step 4: Execution
## Step 5: Emit output block
```

- [ ] **Step 4: Commit**

```bash
git add skills/nob/refactor-agent/SKILL.md
git commit -m "feat: add refactor-agent sub-skill"
```

---

### Task 2: Add `refactor-agent: sonnet` to hub RESOLVED_CONFIG defaults

**Files:**
- Modify: `skills/nob/SKILL.md` (the `agents.models` defaults block, lines ~79–102)

- [ ] **Step 1: Verify current state of the models block**

```bash
grep -n "venture-reviewer" skills/nob/SKILL.md
```

Expected: a line like `    venture-reviewer: haiku`

- [ ] **Step 2: Add `refactor-agent: sonnet` after `venture-reviewer: haiku`**

In `skills/nob/SKILL.md`, find the RESOLVED_CONFIG defaults block. Replace:

```yaml
    venture-reviewer: haiku
  max_parallel_slices: 3
```

With:

```yaml
    venture-reviewer: haiku
    refactor-agent: sonnet
  max_parallel_slices: 3
```

- [ ] **Step 3: Verify**

```bash
grep -A1 "venture-reviewer" skills/nob/SKILL.md
```

Expected:
```
    venture-reviewer: haiku
    refactor-agent: sonnet
```

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add refactor-agent model to hub RESOLVED_CONFIG defaults"
```

---

### Task 3: Insert Step 0.5 (Structure Check) into the hub

**Files:**
- Modify: `skills/nob/SKILL.md` (between Step 0 and Step 1)

- [ ] **Step 1: Verify insertion point**

```bash
grep -n "not a git repo, skip this step\|## Step 1: Read project config" skills/nob/SKILL.md
```

Expected: two matching lines close together.

- [ ] **Step 2: Insert Step 0.5 between Step 0 and Step 1**

In `skills/nob/SKILL.md`, replace:

```
If git is not available or the working directory is not a git repo, skip this step and note it in the terminal summary.

## Step 1: Read project config
```

With:

```
If git is not available or the working directory is not a git repo, skip this step and note it in the terminal summary.

## Step 0.5: Structure Check

Skip this step entirely if workflow is `Init` or `Venture`.

Check for structure mismatch in this order:

1. If `.nob.yml` exists and `stack.frontend.path` is `apps/frontend/` and `stack.backend.path` is `apps/backend/` → **no mismatch**. Skip this step.
2. If the working directory is empty (no files other than `.git`/`.gitignore`) → **no mismatch**. Skip this step.
3. If `apps/frontend/` or `apps/backend/` is missing AND a recognisable source directory exists elsewhere (`frontend/`, `web/`, `client/`, `src/`, `backend/`, `server/`, `api/`) → **mismatch**.
4. If `apps/` layout is correct but `shared/core/` is absent → **partial mismatch**.

When mismatch detected, store detected dir names as DETECTED_DIRS. Print:

```
Detected project structure doesn't match nob's layout:
  Found:    [DETECTED_DIRS]
  Expected: apps/frontend/  +  apps/backend/  +  shared/core/

Refactor now before proceeding? (yes / skip)
```

Wait for user response:
- `yes` → read `{SKILL_BASE_DIR}/refactor-agent/SKILL.md`. Dispatch an Agent with `model: agents.models["refactor-agent"] ?? "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/refactor-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Detected source paths: {DETECTED_DIRS}
Stack type: unknown
Original user intent: {user's original message}
Refactor mode: mid-run
[/INPUTS]
```

Extract `[REFACTOR-AGENT OUTPUT]...[/REFACTOR-AGENT OUTPUT]`. Store as REFACTOR_OUTPUT.

If `Status: complete` in REFACTOR_OUTPUT: print "Refactor complete. Continuing with your original request..." then proceed to Step 1.
If `Status: cancelled` or `Status: failed`: proceed to Step 1 without changes. Note the skip in the terminal summary.

- `skip` or any non-yes response → set STRUCTURE_CHECK_SKIPPED = true. Proceed to Step 1 unchanged. Do not offer again in this run.

## Step 1: Read project config
```

- [ ] **Step 3: Verify Step 0.5 is present**

```bash
grep -n "Step 0.5\|Structure Check" skills/nob/SKILL.md
```

Expected: two matching lines showing the new section header.

- [ ] **Step 4: Verify ordering is correct (Step 0 → 0.5 → 1)**

```bash
grep -n "^## Step 0\|^## Step 0.5\|^## Step 1:" skills/nob/SKILL.md
```

Expected: three lines in ascending order.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Step 0.5 structure check to hub"
```

---

### Task 4: Add Refactor workflow type to Step 2 + early exit section

**Files:**
- Modify: `skills/nob/SKILL.md` (Step 2 trigger table + early exit routing + new early exit section)

- [ ] **Step 1: Add Refactor row to the Step 2 trigger table**

In `skills/nob/SKILL.md`, replace:

```
| "I want to build a startup", "I want to build a product", "I want to build a company", "I have an idea", "bring to market", "startup idea", "business idea", "validate my idea", "launch a startup", "launch a product", "launch a company", "nob venture" | Venture |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
> "Is this a new feature to implement, a bug to fix, an API contract sync, or a business idea you'd like to validate?"
```

With:

```
| "I want to build a startup", "I want to build a product", "I want to build a company", "I have an idea", "bring to market", "startup idea", "business idea", "validate my idea", "launch a startup", "launch a product", "launch a company", "nob venture" | Venture |
| "nob refactor", "restructure project", "migrate to nob structure", "migrate project", "refactor project structure" | Refactor |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
> "Is this a new feature to implement, a bug to fix, an API contract sync, a business idea you'd like to validate, or a project to restructure?"
```

- [ ] **Step 2: Add routing line for Refactor after the existing Init routing line**

In `skills/nob/SKILL.md`, replace:

```
If the identified workflow is `Init`, skip to the **Init workflow early exit** section immediately below before proceeding to Phase 0.
```

With:

```
If the identified workflow is `Init`, skip to the **Init workflow early exit** section immediately below before proceeding to Phase 0.

If the identified workflow is `Refactor`, skip to the **Refactor workflow early exit** section immediately below before proceeding to Phase 0.
```

- [ ] **Step 3: Add the Refactor early exit section after the Venture early exit section**

In `skills/nob/SKILL.md`, find the line `## Phase 0: Resume scan` and insert the following block immediately before it (the block ends just before `## Phase 0`):

    ## Refactor workflow early exit

    If the identified workflow is `Refactor`:
    - Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
    - Read `{SKILL_BASE_DIR}/refactor-agent/SKILL.md`.
    - Dispatch an Agent with `model: agents.models["refactor-agent"] ?? "sonnet"` and this prompt:

        [INSTRUCTIONS]
        {full contents of {SKILL_BASE_DIR}/refactor-agent/SKILL.md}
        [/INSTRUCTIONS]

        [INPUTS]
        Working directory: {current working directory path}
        Detected source paths: unknown
        Stack type: unknown
        Original user intent: {user's original message}
        Refactor mode: explicit
        [/INPUTS]

    - Extract `[REFACTOR-AGENT OUTPUT]...[/REFACTOR-AGENT OUTPUT]` from the result. Store as REFACTOR_OUTPUT.
    - Jump directly to Step 4 (Print terminal summary) using the Refactor terminal summary format.

- [ ] **Step 4: Verify the three new elements are in place**

```bash
grep -n "Refactor" skills/nob/SKILL.md | head -20
```

Expected: lines for the trigger table row, the routing line, the early exit section header, and the prompt block.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Refactor workflow type and early exit to hub"
```

---

### Task 5: Add Refactor terminal summary to Step 4 + update hub frontmatter

**Files:**
- Modify: `skills/nob/SKILL.md` (Step 4 summary block + frontmatter description)

- [ ] **Step 1: Add Refactor terminal summary to Step 4**

In `skills/nob/SKILL.md`, replace:

```
**If workflow is `Init`, use this summary:**

**If workflow is `Venture`**: summary is printed inline in the `## Venture Workflow` section above. This section is not reached for Venture runs.
```

With:

```
**If workflow is `Init`, use this summary:**

**If workflow is `Venture`**: summary is printed inline in the `## Venture Workflow` section above. This section is not reached for Venture runs.

**If workflow is `Refactor`**, use this summary:

```
Nob refactor complete.

Moves:       [source] → apps/frontend/  ✓ | ✗
             [source] → apps/backend/   ✓ | ✗
Shared:      shared/core/contracts/     ✓ | ✗
             shared/core/schema/        ✓ | ✗
Imports:     [N] files rewritten        ✓ | ✗
Config:      CLAUDE.md                  ✓ | ✗
             .nob.yml                   ✓ | ✗

[if warnings from REFACTOR_OUTPUT:]
Manual review needed:
  [list of unresolved import patterns from REFACTOR_OUTPUT Warnings field]

Next: /nob implement docs/specs/your-feature.md
```

Populate each field from the corresponding field in REFACTOR_OUTPUT. Mark ✓ for success/created, ✗ for failed.

If REFACTOR_OUTPUT Status is `cancelled`: print "Refactor cancelled. No changes made." and exit.
If REFACTOR_OUTPUT Status is `failed`: print the failure details from REFACTOR_OUTPUT and exit.

Also add this error handling entry to the Error Handling section:

```
- **Refactor-agent returns no [REFACTOR-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
```

```

- [ ] **Step 2: Update hub frontmatter description to mention Refactor**

In `skills/nob/SKILL.md`, replace:

```
description: 'Use when asked to implement a feature spec, fix a bug, or sync clients after an API change across a fullstack monorepo. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob [intent]". Orchestrates Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer in sequence.'
```

With:

```
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, or migrate an existing project to nob''s monorepo structure. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [intent]". Orchestrates Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer in sequence. Also detects structure mismatch on any run and offers refactor before proceeding.'
```

- [ ] **Step 3: Verify Refactor summary is present in Step 4**

```bash
grep -n "Nob refactor complete\|If workflow is \`Refactor\`" skills/nob/SKILL.md
```

Expected: two matching lines.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Refactor terminal summary and update hub description"
```

---

### Task 6: Update `.nob.yml.template` with `refactor-agent` model entry

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`

- [ ] **Step 1: Verify current state**

```bash
grep -n "venture-reviewer\|refactor" skills/nob/templates/.nob.yml.template
```

Expected: `venture-reviewer: haiku` present, `refactor-agent` absent.

- [ ] **Step 2: Add `refactor-agent: sonnet` to the models section**

In `skills/nob/templates/.nob.yml.template`, replace:

```
    venture-reviewer: haiku
```

With:

```
    venture-reviewer: haiku
    refactor-agent: sonnet      # project migration agent
```

- [ ] **Step 3: Verify**

```bash
grep "refactor-agent" skills/nob/templates/.nob.yml.template
```

Expected: `    refactor-agent: sonnet      # project migration agent`

- [ ] **Step 4: Commit**

```bash
git add skills/nob/templates/.nob.yml.template
git commit -m "chore: add refactor-agent model entry to .nob.yml template"
```

---

## Final verification

- [ ] **Confirm all six workflow types are in the hub trigger table**

```bash
grep -A8 "## Step 2: Identify workflow type" skills/nob/SKILL.md | grep "|"
```

Expected: 6 rows (Spec→Code, Bug→Fix, API→Sync, Init, Venture, Refactor).

- [ ] **Confirm refactor-agent directory structure is complete**

```bash
ls skills/nob/refactor-agent/
```

Expected: `SKILL.md`

- [ ] **Confirm refactor-agent model appears in both hub defaults and template**

```bash
grep "refactor-agent" skills/nob/SKILL.md skills/nob/templates/.nob.yml.template
```

Expected: at least two matching lines (one per file).
