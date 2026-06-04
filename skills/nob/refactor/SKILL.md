---
name: nob-refactor
description: "Migrates an existing project to nob's monorepo structure (apps/frontend/, apps/backend/, shared/core/). Analyzes the current layout, presents a migration plan, and executes on user approval. Invocable via `/nob:refactor` directly or through the Nob hub. Triggers on: 'nob refactor', 'restructure project', 'migrate to nob structure'."
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
- `Refactor mode` — `explicit` (standalone `/nob refactor`) or `mid-run` (auto-detected mismatch). In `mid-run` mode the hub has already obtained user consent to proceed; Step 3's approval prompt is still shown to confirm the specific plan.

---

## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. Use the current working directory as the working directory and the user's message as the intent. No prior agent output needed — proceed to Step 1.

## Step 1: Analysis pass

Extract `Working directory` from `[INPUTS]`. Store as WORKING_DIR.

Run `ls -A {WORKING_DIR}` to list all top-level entries.

**Determine stack type** — use `Stack type` from inputs if provided and not "unknown". Otherwise detect from WORKING_DIR and the identified source directories:

To set FRONTEND_TYPE: check for a `package.json` in SOURCE_FRONTEND (if non-null), then fall back to root. Check `dependencies` for `next` → `next`, `vue` → `vue`, `react` or `react-dom` → `react`. Also check: `pubspec.yaml` → `flutter`.

To set BACKEND_TYPE: check for a `package.json` in SOURCE_BACKEND (if non-null), then fall back to root. Check `dependencies` for `express`/`fastify`/`koa` → `node`. Also check: `pyproject.toml` or `requirements.txt` → `python`; `go.mod` → `go`.

If FRONTEND_TYPE cannot be determined: set to "unknown".
If BACKEND_TYPE cannot be determined: set to "unknown".

STACK_TYPE is JS/TS if either FRONTEND_TYPE is `react`, `vue`, or `next`, or BACKEND_TYPE is `node`.
STACK_TYPE is `python` if BACKEND_TYPE is `python`.
STACK_TYPE is `go` if BACKEND_TYPE is `go`.
STACK_TYPE is `flutter` if FRONTEND_TYPE is `flutter`.

**Check git**: run `git -C {WORKING_DIR} status`. Exit code 0 → IS_GIT_REPO = true. Otherwise IS_GIT_REPO = false.

**Identify source directories** — use `Detected source paths` from inputs if not "unknown"; otherwise scan WORKING_DIR:
- SOURCE_FRONTEND: first existing directory among `frontend/`, `web/`, `client/`, `app/` that is NOT `apps/frontend/`. Skip if `apps/frontend/` already exists.
- SOURCE_BACKEND: first existing directory among `backend/`, `server/`, `api/` that is NOT `apps/backend/`. Skip if `apps/backend/` already exists.
- If neither can be determined, set to null.

**Estimate import count**: if SOURCE_FRONTEND and SOURCE_BACKEND are both non-null, extract the basename of SOURCE_BACKEND (e.g. `backend` from `backend/`). Store as BACKEND_BASENAME.

For JS/TS stack:
```bash
grep -r "\.\./${BACKEND_BASENAME}" {WORKING_DIR} --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" -l 2>/dev/null | wc -l
```

For Python stack:
```bash
grep -r "^from ${BACKEND_BASENAME}\.\|^import ${BACKEND_BASENAME}\." {WORKING_DIR} --include="*.py" -l 2>/dev/null | wc -l
```

Store result as IMPORT_FILE_COUNT. If the command fails or returns empty: set IMPORT_FILE_COUNT = 0.

---

## Step 2: Build migration plan

Construct:
- MOVES: array of `{from, to}` pairs — only include dirs that exist and are not already at the target path:
  - If SOURCE_FRONTEND is non-null: `{from: SOURCE_FRONTEND, to: "apps/frontend"}`
  - If SOURCE_BACKEND is non-null: `{from: SOURCE_BACKEND, to: "apps/backend"}`
- NEW_DIRS: always `shared/core/contracts` and `shared/core/schema`
- NEW_FILES: `shared/core/package.json` if STACK_TYPE is JS/TS
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
- `cancel`, `no`, or any negative → emit `[REFACTOR OUTPUT]` with `Status: cancelled` and exit.
- `yes` → proceed to Step 4.

---

## Step 4: Execution

Execute sub-steps in this exact order. If any sub-step fails, stop immediately — do NOT continue to the next sub-step. Emit `[REFACTOR OUTPUT]` with `Status: failed`, list what succeeded and what failed, and exit.

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

Check whether `{WORKING_DIR}/apps/frontend/` and `{WORKING_DIR}/apps/backend/` exist before walking. If neither exists, set IMPORTS_REWRITTEN = 0 and IMPORT_WARNINGS = [] and skip to Step 5.

Walk all source files recursively in whichever of `{WORKING_DIR}/apps/frontend/` and `{WORKING_DIR}/apps/backend/` exist.

**JS/TS files** (`.ts`, `.tsx`, `.js`, `.jsx`):

For each import or require statement where the path string contains BACKEND_BASENAME (e.g. `'../backend/utils'` or `'../../backend/auth'`):
1. Identify the old path string.
2. Resolve it relative to the importing file's current location to get the target's absolute path (e.g. `{WORKING_DIR}/apps/backend/utils`).
3. Compute a new relative path from the importing file's current location to that same absolute target. Example: a file at `apps/frontend/src/api/client.ts` targeting `apps/backend/src/utils/auth` resolves to `../../../backend/src/utils/auth`.
4. Replace the old path string with the newly computed relative path.

If a file contains a dynamic `require()` (variable as argument), a barrel re-export that can't be traced, or the path cannot be resolved: skip that file, add its path to IMPORT_WARNINGS.

Use the Edit tool to apply rewrites — one Edit call per file changed. Do not use `sed` or shell substitutions.

**Python files** (`.py`):

Replace:
- `from backend.` → `from apps.backend.`
- `import backend.` → `import apps.backend.`

Use the Edit tool with `replace_all: true` for each pattern per file.

**Go files** (`.go` and `go.mod`):

Read `{WORKING_DIR}/go.mod`. If the `module` declaration contains `/{BACKEND_BASENAME}` as a path component, replace that component with `/apps/backend`. Then in every `.go` file under `{WORKING_DIR}/apps/`, find import strings containing the old module path prefix and update them to the new module path. Use the Edit tool for all changes.

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
  enabled: [planner, pm, backend, frontend, security, reviewer]
  models:
    backend: sonnet
    frontend: sonnet
    planner: haiku
    pm: haiku
    reviewer: haiku
    security: haiku
    refactor: sonnet
  max_parallel_slices: 3
  checkpoint:
    enabled: true
    path: .nob/
```

---

## Step 5: Emit output block

```
[REFACTOR OUTPUT]
Status: complete
Moves:
  [list each move as: "{from} → {to}: success | skipped | failed", one per line]
Shared: created
Imports rewritten: {IMPORTS_REWRITTEN}
Config: CLAUDE.md written, .nob.yml written
Move warnings:
  {MOVE_WARNINGS joined by newline, or "none"}
Import warnings:
  {IMPORT_WARNINGS joined by newline, or "none"}
[/REFACTOR OUTPUT]
```

If Step 4 was halted by failure: emit `Status: failed` and list which sub-step failed.
If Step 3 resulted in cancel: emit `Status: cancelled`.
