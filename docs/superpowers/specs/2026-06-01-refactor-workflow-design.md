# Nob Refactor Workflow — Design Spec

**Date:** 2026-06-01
**Status:** Approved

## Overview

Add a `Refactor` workflow to nob that migrates existing projects to nob's monorepo structure (`apps/frontend/`, `apps/backend/`, `shared/core/`). Most existing projects don't follow this layout, and nob's dev pipeline works best when they do. The workflow shows a migration plan first, executes only on user approval, and continues automatically into the original dev pipeline when triggered mid-run.

---

## Architecture

Two changes to the hub (`skills/nob/SKILL.md`), one new sub-skill file:

**New file:** `skills/nob/refactor-agent/SKILL.md` — self-contained sub-skill handling analysis, plan presentation, user approval, and execution.

**Hub change 1 — new Step 0.5 (Structure Check)** inserted between Step 0 (git branch) and Step 1 (read project config). Runs on every workflow except `Init` and `Venture`.

**Hub change 2 — new workflow type** `Refactor` added to the Step 2 trigger table.

---

## Hub Changes

### Step 0.5: Structure Check

Inserted between Step 0 (git branch safety) and Step 1 (read project config). Skip entirely if workflow is `Init` or `Venture`.

**Mismatch detection — check in order:**

1. `.nob.yml` exists and `stack.frontend.path` = `apps/frontend/` and `stack.backend.path` = `apps/backend/` → **no mismatch**, skip this step entirely.
2. Directory is empty → **no mismatch**, skip.
3. `apps/frontend/` or `apps/backend/` missing AND a recognizable frontend/backend dir exists elsewhere (`frontend/`, `src/`, `client/`, `server/`, `api/`, `web/`) → **mismatch**.
4. `shared/core/` missing but `apps/` layout is already correct → **partial mismatch** (offer refactor to add `shared/core/` only).

**When mismatch detected**, print:

```
Detected project structure doesn't match nob's layout:
  Found:    [detected dirs]
  Expected: apps/frontend/  +  apps/backend/  +  shared/core/

Refactor now before proceeding? (yes / skip)
```

Wait for user response:
- `yes` → dispatch refactor-agent (model: `agents.models["refactor-agent"] ?? "sonnet"`), store `[REFACTOR-AGENT OUTPUT]`, then continue to Step 1.
- `skip` → set `STRUCTURE_CHECK_SKIPPED=true`, proceed to Step 1 unchanged. Do not offer again in this run.

### Step 2: New workflow type

Add to the intent pattern table:

| Intent pattern | Workflow |
|---|---|
| `nob refactor`, `restructure project`, `migrate to nob structure`, `migrate project` | Refactor |

When workflow is `Refactor`: dispatch refactor-agent then jump to Step 4 (terminal summary) using the Refactor summary format. Do not run Planner or any dev pipeline agents.

### Step 4: Refactor terminal summary

```
Nob refactor complete.

Moves:       [source] → apps/frontend/  ✓ | ✗
             [source] → apps/backend/   ✓ | ✗
Shared:      shared/core/contracts/     ✓ | ✗
             shared/core/schema/        ✓ | ✗
Imports:     [N] files rewritten        ✓ | ✗
Config:      CLAUDE.md                  ✓ | ✗
             .nob.yml                   ✓ | ✗

[if warnings:]
Manual review needed:
  [list of unresolved import patterns]

Next: /nob implement docs/specs/your-feature.md
```

### Default model entry

Add to the auto-detected RESOLVED_CONFIG defaults:
```yaml
agents:
  models:
    refactor-agent: sonnet
```

---

## Refactor Agent (`skills/nob/refactor-agent/SKILL.md`)

### Inputs (from hub `[INPUTS]` block)

- `Working directory` — absolute path
- `Detected source paths` — e.g. `frontend/`, `backend/` (or "unknown" if hub couldn't determine)
- `Stack type` — if known from auto-detection or `.nob.yml`
- `Original user intent` — the user's original message (for clean handback in auto-detected mode)
- `Refactor mode` — `explicit` (standalone `/nob refactor`) or `mid-run` (auto-detected mismatch)

### Step 1: Analysis pass

Read to understand the project:
- All top-level directories (`ls -A {WORKING_DIR}`)
- Root `package.json`, `pyproject.toml`, or `go.mod` — determine stack type if not provided
- First 50 lines of 3–5 key source files to understand import path patterns

Determine:
- `SOURCE_FRONTEND` — detected frontend directory (e.g. `frontend/`, `src/client/`)
- `SOURCE_BACKEND` — detected backend directory (e.g. `backend/`, `server/`, `api/`)
- `IMPORT_PATTERN` — how imports reference the other layer (e.g. `../backend/`, `from backend.`)
- `IS_GIT_REPO` — `git status` exit code 0 = true

### Step 2: Build migration plan

Construct a structured plan object:
- `moves` — list of `{from, to}` directory pairs (only dirs that exist and need moving)
- `new_dirs` — `shared/core/contracts/`, `shared/core/schema/`; `shared/core/package.json` if JS/TS stack
- `import_files` — estimated count of files with imports to rewrite
- `config_files` — `CLAUDE.md`, `.nob.yml`

### Step 3: Present plan to user

```
Nob Refactor Plan
─────────────────────────────────────
Moves:
  [SOURCE_FRONTEND]/    →  apps/frontend/
  [SOURCE_BACKEND]/     →  apps/backend/

New directories:
  shared/core/contracts/
  shared/core/schema/
  [if JS/TS: shared/core/package.json]

Import rewrites:
  ~[N] files — patterns containing "[IMPORT_PATTERN]"

Config files written:
  CLAUDE.md  (new — AI agent boundary rules)
  .nob.yml   (new — stack paths)

Proceed with refactor? (yes / cancel)
─────────────────────────────────────
```

Wait for user response:
- `cancel` → emit `[REFACTOR-AGENT OUTPUT]` with `Status: cancelled`. Hub exits (explicit) or resumes original pipeline without changes (mid-run).
- `yes` → proceed to Step 4.

### Step 4: Execution

Execute in this exact order. If any step fails: stop immediately, emit `[REFACTOR-AGENT OUTPUT]` listing what succeeded and what failed. Do not proceed to subsequent steps.

**4a. Git safety notice**

If `IS_GIT_REPO` is true: print "Tip: run `git stash` if you want a clean rollback point before this runs."

**4b. Move directories**

For each `{from, to}` in `moves`:
- If `IS_GIT_REPO`: `git mv {from} {to}` (preserves history)
- Otherwise: `mkdir -p apps && mv {from} {to}`
- If source dir doesn't exist: skip silently, note in output.

**4c. Create shared scaffold**

```bash
mkdir -p shared/core/contracts
mkdir -p shared/core/schema
touch shared/core/contracts/.gitkeep
touch shared/core/schema/.gitkeep
```

If JS/TS stack: write `shared/core/package.json` using the template from the monorepo structure spec:
```json
{
  "name": "@[project-slug]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts"
}
```

**4d. Rewrite imports**

Walk all source files in `apps/frontend/` and `apps/backend/`. For each file, find and rewrite import/require statements referencing old paths.

Language-aware patterns:

| Stack | Pattern to find | Rewrite to |
|---|---|---|
| JS/TS | `from '[old-backend-path]` | calculate correct relative path from the file's location to `apps/backend/` |
| JS/TS | `require('[old-backend-path]` | same — calculate from file location |
| Python | `from backend.` | `from apps.backend.` |
| Python | `import backend.` | `import apps.backend.` |
| Go | module path in `go.mod` | update module declaration + all internal imports |

For JS/TS: resolve the old import path to its absolute location, then compute the new relative path from the importing file's new location (inside `apps/`) to the target's new location (inside `apps/`). Do not hardcode a fixed `../` depth.

If a file's imports can't be auto-resolved (ambiguous depth, dynamic requires, etc.): skip that file, add it to a `warnings` list.

Count total files rewritten. Store `IMPORT_WARNINGS` list.

**4e. Write config files**

Write `CLAUDE.md` using the template from the monorepo structure spec, filled with detected stack values. If `CLAUDE.md` already exists: overwrite it.

Write `.nob.yml` with:
```yaml
stack:
  frontend:
    enabled: true
    type: [detected frontend type]
    path: apps/frontend/
  backend:
    enabled: true
    type: [detected backend type]
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

### Step 5: Emit output block

```
[REFACTOR-AGENT OUTPUT]
Status: complete | cancelled | failed
Moves:
  [from] → [to]: success | skipped | failed
Shared: created | failed
Imports rewritten: [N]
Config: CLAUDE.md written | failed, .nob.yml written | failed
Warnings:
  [list of files that need manual import review, or "none"]
[/REFACTOR-AGENT OUTPUT]
```

---

## Continue-automatically flow

**Explicit Refactor** (`nob refactor`): hub prints Refactor terminal summary and exits.

**Auto-detected mid-run**: after refactor-agent returns with `Status: complete`, hub prints:
> "Refactor complete. Continuing with your original request..."

Then resumes at Step 1 (read project config) using the now-updated structure. The full dev pipeline (Planner → PM Agent → Backend + Frontend → QA → Reviewer) runs normally.

If refactor-agent returns `Status: cancelled` or `Status: failed` in mid-run mode: hub resumes the original pipeline without structural changes, noting the skip in the terminal summary.

---

## Error handling

| Scenario | Behaviour |
|---|---|
| `git mv` fails (e.g. unstaged changes) | Fall back to `mv`, warn user to run `git add` manually |
| Source dir doesn't exist | Skip that move silently, note in output |
| Import rewrite produces a syntax error | Skip that file, add to warnings |
| `.nob.yml` write fails | Report failure, stop execution |
| Refactor-agent returns no output block | Re-dispatch once; if still missing, print raw output and stop |

---

## Files to create / modify

| File | Change |
|---|---|
| `skills/nob/SKILL.md` | Add Step 0.5, add Refactor to Step 2 table, add Refactor terminal summary to Step 4, add `refactor-agent: sonnet` to default model config |
| `skills/nob/refactor-agent/SKILL.md` | New file |

---

## Out of scope

- Moving shared types from `apps/` into `shared/core/contracts/` (shared extraction) — left to the developer
- Updating CI/CD pipeline configs (Dockerfile paths, GitHub Actions) — too project-specific to automate safely
- Turborepo / Nx workspace tooling — unchanged
- Rollback / undo command — git history via `git mv` is the rollback mechanism
