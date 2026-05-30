# Universal Monorepo Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `frontend/` + `backend/` scaffold with a universal `apps/` + `shared/` domain-organized monorepo structure across all four files that produce or reference those paths.

**Architecture:** Four files need updating: `init-agent/SKILL.md` (generates the scaffold), `SKILL.md` hub (auto-detection + terminal summary), `.nob.yml.template` (user config template), and `CLAUDE.md.template` (user project template). The init-agent gets the heaviest changes — new shared/core scaffold section, ORM detection, conditional workspace tooling. All other changes are path updates and content additions.

**Tech Stack:** Markdown skill files only — no build system, no tests. Verification is done by grepping for expected strings after each edit.

---

## File Map

| File | Change type |
|---|---|
| `skills/nob/templates/.nob.yml.template` | Update paths + add `shared.core` section |
| `skills/nob/templates/CLAUDE.md.template` | Update paths + add AI Agent Rules section |
| `skills/nob/SKILL.md` | Update auto-detection scan paths + terminal summary |
| `skills/nob/init-agent/SKILL.md` | Path migration + ORM logic + shared/core scaffold + updated templates + install + output |

---

### Task 1: Update `.nob.yml.template`

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`

- [ ] **Step 1: Confirm current paths**

```bash
grep -n "path:" skills/nob/templates/.nob.yml.template
```
Expected: lines showing `/frontend` and `/backend`.

- [ ] **Step 2: Replace frontend path**

Edit `skills/nob/templates/.nob.yml.template`:

Old:
```
    path: /frontend      # path relative to repo root
```

New:
```
    path: apps/frontend/   # path relative to repo root
```

- [ ] **Step 3: Replace backend path**

Edit `skills/nob/templates/.nob.yml.template`:

Old:
```
    path: /backend
```

New:
```
    path: apps/backend/
```

- [ ] **Step 4: Add shared section after backend block**

Edit `skills/nob/templates/.nob.yml.template`:

Old:
```
  docs:
    enabled: true
```

New:
```
  shared:
    core: shared/core/     # domain-organized shared contracts and schema

  docs:
    enabled: true
```

- [ ] **Step 5: Verify**

```bash
grep -n "path:\|shared:" skills/nob/templates/.nob.yml.template
```
Expected: `apps/frontend/`, `apps/backend/`, and `shared:` + `core: shared/core/` appear.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/templates/.nob.yml.template
git commit -m "feat: update .nob.yml template paths to apps/ + shared/ structure"
```

---

### Task 2: Update `CLAUDE.md.template`

**Files:**
- Modify: `skills/nob/templates/CLAUDE.md.template`

- [ ] **Step 1: Confirm current folder structure section**

```bash
grep -n "frontend\|backend\|Folder" skills/nob/templates/CLAUDE.md.template
```
Expected: `/frontend` and `/backend` in Folder Structure section.

- [ ] **Step 2: Replace folder structure section**

Edit `skills/nob/templates/CLAUDE.md.template`:

Old:
```
## Folder Structure
- `/frontend` — UI layer
- `/backend` — API and business logic
- `/docs/specs` — feature specifications (PM writes here)
- `/docs/bugs` — bug reports (QA writes here)
- `/docs/backlog` — acceptance criteria (PO writes here)
```

New:
```
## Folder Structure
- `apps/frontend/` — UI layer. Deployable target. No business logic.
- `apps/backend/` — API layer. Deployable target. No shared contracts here.
- `shared/core/contracts/` — Source of truth for types and API shapes.
- `shared/core/schema/` — Source of truth for database schema and migrations.
- `/docs/specs` — feature specifications (PM writes here)
- `/docs/bugs` — bug reports (QA writes here)
- `/docs/backlog` — acceptance criteria (PO writes here)

## AI Agent Rules
- Feature work → edit `apps/`
- Shared types or API shape changes → edit `shared/core/contracts/`
- Database changes → edit `shared/core/schema/`
- Adding a new domain → create `shared/[domain]/contracts/` and `shared/[domain]/schema/`
- Never put app-specific logic in `shared/`
- Never put shared contracts inside `apps/`
```

- [ ] **Step 3: Verify**

```bash
grep -n "apps/\|shared/\|AI Agent Rules" skills/nob/templates/CLAUDE.md.template
```
Expected: `apps/frontend/`, `apps/backend/`, `shared/core/contracts/`, `shared/core/schema/`, and `## AI Agent Rules` all appear.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/templates/CLAUDE.md.template
git commit -m "feat: update CLAUDE.md template with apps/shared structure and AI agent rules"
```

---

### Task 3: Update hub `SKILL.md` — auto-detection paths

**Files:**
- Modify: `skills/nob/SKILL.md`

- [ ] **Step 1: Find the auto-detection frontend scan**

```bash
grep -n "frontend/\|web/\|client/\|app/" skills/nob/SKILL.md | head -20
```
Expected: line ~49 scanning `frontend/`, `web/`, `client/`, `app/`.

- [ ] **Step 2: Add apps/frontend to frontend scan**

Edit `skills/nob/SKILL.md`:

Old:
```
1. Scan for `package.json` in `frontend/`, `web/`, `client/`, `app/` (in that order). If found, read it and check `dependencies`:
```

New:
```
1. Scan for `package.json` in `apps/frontend/`, `frontend/`, `web/`, `client/`, `app/` (in that order). If found, read it and check `dependencies`:
```

- [ ] **Step 3: Find the auto-detection backend scan**

```bash
grep -n "backend/\|server/\|api/" skills/nob/SKILL.md | head -20
```
Expected: lines ~62-65 scanning `backend/`, `server/`, `api/`.

- [ ] **Step 4: Add apps/backend to backend scan**

Edit `skills/nob/SKILL.md`:

Old:
```
1. Scan for `package.json` in `backend/`, `server/`, `api/` (in that order). Check `dependencies` for `express`, `fastify`, `koa`, `hapi` → type `node`. Path = that directory.
2. `requirements.txt` or `pyproject.toml` in `backend/` → type `python`, path = `backend/`
3. `go.mod` in `backend/` → type `go`, path = `backend/`
4. `pom.xml` in `backend/` → type `java`, path = `backend/`
```

New:
```
1. Scan for `package.json` in `apps/backend/`, `backend/`, `server/`, `api/` (in that order). Check `dependencies` for `express`, `fastify`, `koa`, `hapi` → type `node`. Path = that directory.
2. `requirements.txt` or `pyproject.toml` in `apps/backend/` or `backend/` → type `python`, path = that directory.
3. `go.mod` in `apps/backend/` or `backend/` → type `go`, path = that directory.
4. `pom.xml` in `apps/backend/` or `backend/` → type `java`, path = that directory.
```

- [ ] **Step 5: Verify**

```bash
grep -n "apps/frontend\|apps/backend" skills/nob/SKILL.md | head -10
```
Expected: both `apps/frontend/` and `apps/backend/` appear in the auto-detection section.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add apps/frontend and apps/backend to hub auto-detection scan paths"
```

---

### Task 4: Update hub `SKILL.md` — terminal summary

**Files:**
- Modify: `skills/nob/SKILL.md`

- [ ] **Step 1: Find terminal summary Init block**

```bash
grep -n "frontend/ and backend/\|Copy .env" skills/nob/SKILL.md
```
Expected: line ~853 with `frontend/ and backend/`.

- [ ] **Step 2: Update Init terminal summary install display**

Edit `skills/nob/SKILL.md`:

Old:
```
Files created: [N]
Installs:
  frontend: [npm install ✓ | flutter pub get ✓ | failed ✗]
  backend:  [npm install ✓ | pip install ✓ | go mod tidy ✓ | failed ✗]
```

New:
```
Files created: [N]
Installs:
  [if JS/TS stack: pnpm install (root) ✓ | failed ✗]
  [if Python backend: apps/backend pip install ✓ | failed ✗]
  [if Go backend: apps/backend go mod tidy ✓ | failed ✗]
  [if Flutter frontend: apps/frontend flutter pub get ✓ | failed ✗]
```

- [ ] **Step 3: Update Init terminal summary next steps paths**

Edit `skills/nob/SKILL.md`:

Old:
```
  1. Copy .env.example → .env in frontend/ and backend/ and fill in values
```

New:
```
  1. Copy .env.example → .env in apps/frontend/ and apps/backend/ and fill in values
```

- [ ] **Step 4: Verify**

```bash
grep -n "apps/frontend\|apps/backend\|pnpm install (root)" skills/nob/SKILL.md
```
Expected: updated paths and new install format appear in terminal summary.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: update hub terminal summary to apps/ structure and unified pnpm install"
```

---

### Task 5: Init-agent — migrate all app paths

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Count occurrences to migrate**

```bash
grep -c "mkdir -p frontend\|mkdir -p backend\|Write \`frontend\|Write \`backend\|cd frontend\|cd backend\|from \`frontend\|from \`backend\|Frontend directory: frontend\|Backend directory: backend" skills/nob/init-agent/SKILL.md
```
Note the count — verify same count disappears after edits.

- [ ] **Step 2: Replace all frontend/ mkdir references**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `mkdir -p frontend/`
New: `mkdir -p apps/frontend/`

- [ ] **Step 3: Replace all backend/ mkdir references**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `mkdir -p backend/`
New: `mkdir -p apps/backend/`

- [ ] **Step 4: Replace all frontend/ Write paths**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `` Write `frontend/ ``
New: `` Write `apps/frontend/ ``

- [ ] **Step 5: Replace all backend/ Write paths**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `` Write `backend/ ``
New: `` Write `apps/backend/ ``

- [ ] **Step 6: Replace run-from references**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `` Run from `frontend/` ``
New: `` Run from `apps/frontend/` ``

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `` Run from `backend/` ``
New: `` Run from `apps/backend/` ``

- [ ] **Step 7: Replace cd references**

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `cd frontend && `
New: `cd apps/frontend && `

Edit `skills/nob/init-agent/SKILL.md` with `replace_all: true`:

Old: `cd backend && `
New: `cd apps/backend && `

- [ ] **Step 8: Replace output block directory fields**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
Frontend directory: frontend/
Backend directory: backend/
```

New:
```
Frontend directory: apps/frontend/
Backend directory: apps/backend/
```

- [ ] **Step 9: Verify no bare frontend/ or backend/ paths remain**

```bash
grep -n "frontend/" skills/nob/init-agent/SKILL.md | grep -v "apps/frontend/"
grep -n "backend/" skills/nob/init-agent/SKILL.md | grep -v "apps/backend/"
```
Expected: no output (all occurrences now use `apps/` prefix).

- [ ] **Step 10: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: migrate init-agent all app paths to apps/frontend and apps/backend"
```

---

### Task 6: Init-agent — add ORM detection to Step 3

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Find where DATABASE_TYPE is stored in Step 3**

```bash
grep -n "DATABASE_TYPE\|FRONTEND_TYPE\|BACKEND_TYPE" skills/nob/init-agent/SKILL.md | tail -10
```
Expected: lines storing confirmed stack values near the end of Step 3.

- [ ] **Step 2: Add ORM_TYPE storage after DATABASE_TYPE**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
Store confirmed values:
- FRONTEND_TYPE: `next` | `react-vite` | `vue` | `flutter`
- BACKEND_TYPE: `express` | `fastapi` | `go`
- DATABASE_TYPE: `postgres` | `sqlite`
```

New:
```
Store confirmed values:
- FRONTEND_TYPE: `next` | `react-vite` | `vue` | `flutter`
- BACKEND_TYPE: `express` | `fastapi` | `go`
- DATABASE_TYPE: `postgres` | `sqlite`
- ORM_TYPE: determined by rules below

Determine ORM_TYPE from confirmed stack:
- BACKEND_TYPE = `express` (any DATABASE_TYPE) → `prisma` (default). If user says "use Drizzle" → `drizzle`. If user says "use Kysely" → `kysely`. Any other Node ORM override → `other-node-orm`.
- BACKEND_TYPE = `fastapi` → `alembic`
- BACKEND_TYPE = `go` → `goose`
```

- [ ] **Step 3: Add Packages line to the recommendation format**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
Frontend:  [framework + version + styling]
Backend:   [language + framework]
Database:  [database]

Why: [2–3 sentences tying the recommendation to what the user described]

Does this stack work for you? Or would you like to change any layer?
(e.g. "use Python for backend", "use SQLite instead of PostgreSQL")
```

New:
```
Frontend:  [framework + version + styling]
Backend:   [language + framework]
Database:  [database + ORM, e.g. "PostgreSQL + Prisma ORM" or "PostgreSQL + Alembic"]
Packages:  shared/core ([ORM name] schema + [TypeScript contracts | OpenAPI spec])

Why: [2–3 sentences tying the recommendation to what the user described]

Does this stack work for you? Or would you like to change any layer?
(e.g. "use Python for backend", "use SQLite instead of PostgreSQL", "use Drizzle instead of Prisma")
```

- [ ] **Step 4: Verify**

```bash
grep -n "ORM_TYPE\|Packages:\|Drizzle\|alembic\|goose" skills/nob/init-agent/SKILL.md | head -15
```
Expected: `ORM_TYPE` storage and determination rules, `Packages:` line in recommendation format, and ORM names all appear.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: add ORM detection and Packages line to init-agent Step 3"
```

---

### Task 7: Init-agent — scaffold shared/core (new section in Step 4)

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Find the end of the backend scaffold sections**

```bash
grep -n "### If BACKEND_TYPE\|go mod tidy\|After writing all Go" skills/nob/init-agent/SKILL.md | tail -5
```
Note the line number of the last backend section's closing content (the `go mod tidy` line).

- [ ] **Step 2: Add shared/core scaffold section after the backend sections**

Find this text in `skills/nob/init-agent/SKILL.md`:

Old:
```
After writing all Go files, run from `apps/backend/`: `go mod tidy`

---

## Step 5: Generate CLAUDE.md
```

New:
```
After writing all Go files, run from `apps/backend/`: `go mod tidy`

---

### shared/core (always created)

Run: `mkdir -p shared/core/contracts shared/core/schema`

**If FRONTEND_TYPE is `next`, `react-vite`, or `vue`, OR BACKEND_TYPE is `express`** (any JS/TS app):

Write `pnpm-workspace.yaml`:
```yaml
packages:
  - 'apps/*'
  - 'shared/*'
```

Derive PROJECT_SLUG from PROJECT_NAME: lowercase, spaces replaced with hyphens (e.g. "Task Tracker" → "task-tracker").

Write `package.json` (root):
```json
{
  "name": "[PROJECT_SLUG]",
  "private": true,
  "scripts": {
    "dev:frontend": "pnpm --filter frontend dev",
    "dev:backend": "pnpm --filter backend dev"
  }
}
```

Write `shared/core/package.json`:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts"
}
```

Write `shared/core/contracts/index.ts`:
```typescript
export interface ApiResponse<T> {
  data: T
  error?: { code: string; message: string }
}

export interface Item {
  id: string
  name: string
}
```

**If BACKEND_TYPE = `fastapi` or `go`:**

Write `shared/core/contracts/openapi.yml`:
```yaml
openapi: 3.0.0
info:
  title: [PROJECT_NAME] API
  version: 0.1.0
paths:
  /health:
    get:
      summary: Health check
      responses:
        '200':
          description: OK
  /api/v1/items:
    get:
      summary: List items
      responses:
        '200':
          description: OK
```

**If ORM_TYPE = `prisma`:**

Determine Prisma provider: DATABASE_TYPE = `postgres` → `postgresql`; DATABASE_TYPE = `sqlite` → `sqlite`.

Write `shared/core/schema/schema.prisma`:
```prisma
datasource db {
  provider = "[postgresql | sqlite]"
  url      = env("DATABASE_URL")
}

generator client {
  provider        = "prisma-client-js"
  output          = "../../../node_modules/.prisma/client"
}

model Item {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
}
```

Update `shared/core/package.json` to add Prisma dependency:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts",
  "dependencies": {
    "@prisma/client": "^5.0.0"
  },
  "devDependencies": {
    "prisma": "^5.0.0"
  }
}
```

**If ORM_TYPE = `drizzle`:**

Write `shared/core/schema/schema.ts`:
```typescript
import { pgTable, text, timestamp } from 'drizzle-orm/pg-core'

export const items = pgTable('items', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
})
```

Write `shared/core/schema/drizzle.config.ts`:
```typescript
import type { Config } from 'drizzle-kit'

export default {
  schema: './shared/core/schema/schema.ts',
  out: './shared/core/schema/migrations',
  driver: 'pg',
} satisfies Config
```

Update `shared/core/package.json` to add Drizzle dependency:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts",
  "dependencies": {
    "drizzle-orm": "^0.30.0"
  },
  "devDependencies": {
    "drizzle-kit": "^0.20.0"
  }
}
```

**If ORM_TYPE = `alembic` (FastAPI):**

Run: `mkdir -p shared/core/schema/migrations`

Write `shared/core/schema/migrations/README.md`:
```markdown
# Database Migrations

Managed by Alembic. Initialize from apps/backend/:

    alembic init alembic
    alembic revision --autogenerate -m "initial"
    alembic upgrade head
```

Write `shared/core/__init__.py`:
(empty file — makes this a Python package)

Write `shared/core/pyproject.toml`:
```toml
[build-system]
requires = ["setuptools"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "core"
version = "0.1.0"
```

**If ORM_TYPE = `goose` (Go):**

Run: `mkdir -p shared/core/schema/migrations`

Write `shared/core/schema/migrations/README.md`:
```markdown
# Database Migrations

Managed by goose. Run from the repo root:

    goose -dir shared/core/schema/migrations postgres "$DATABASE_URL" up
    goose -dir shared/core/schema/migrations postgres "$DATABASE_URL" create migration_name sql
```

**If BACKEND_TYPE = `go`:**

Write `go.work`:
```
go 1.22

use (
	./apps/backend
)
```

---

## Step 5: Generate CLAUDE.md
```

- [ ] **Step 3: Verify shared/core section is present**

```bash
grep -n "shared/core\|pnpm-workspace\|PROJECT_SLUG\|ORM_TYPE = \`prisma\`\|ORM_TYPE = \`drizzle\`\|ORM_TYPE = \`alembic\`\|ORM_TYPE = \`goose\`" skills/nob/init-agent/SKILL.md | head -20
```
Expected: all six patterns appear.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: add shared/core scaffold section to init-agent with conditional ORM and workspace files"
```

---

### Task 8: Init-agent — update CLAUDE.md and .nob.yml generation (Steps 5 and 6)

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Find the CLAUDE.md write section**

```bash
grep -n "## Step 5\|Folder Structure\|/frontend\|/backend" skills/nob/init-agent/SKILL.md | head -20
```
Expected: Step 5 header and the Folder Structure template content.

- [ ] **Step 2: Replace CLAUDE.md folder structure and add AI Agent Rules**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
## Folder Structure
- /frontend — [framework] app
- /backend — [framework] API
```

New:
```
## Folder Structure
- apps/frontend/ — [framework] app. Deployable target. No business logic.
- apps/backend/ — [framework] API. Deployable target. No shared contracts here.
- shared/core/contracts/ — Source of truth for types and API shapes.
- shared/core/schema/ — Source of truth for database schema and migrations.

## AI Agent Rules
- Feature work → edit apps/
- Shared types or API shape changes → edit shared/core/contracts/
- Database changes → edit shared/core/schema/
- Adding a new domain → create shared/[domain]/contracts/ and shared/[domain]/schema/
- Never put app-specific logic in shared/
- Never put shared contracts inside apps/
```

- [ ] **Step 3: Find the .nob.yml write section (Step 6)**

```bash
grep -n "## Step 6\|path: frontend\|path: backend" skills/nob/init-agent/SKILL.md | head -10
```

- [ ] **Step 4: Replace .nob.yml path values**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
    path: frontend/
  backend:
    type: [node | python | go]
    enabled: true
    path: backend/
```

New:
```
    path: apps/frontend/
  backend:
    type: [node | python | go]
    enabled: true
    path: apps/backend/
  shared:
    core: shared/core/
```

- [ ] **Step 5: Verify**

```bash
grep -n "AI Agent Rules\|apps/frontend/\|apps/backend/\|shared/core/contracts\|shared.core\|shared:" skills/nob/init-agent/SKILL.md | head -20
```
Expected: AI Agent Rules section present, updated paths in both CLAUDE.md and .nob.yml templates.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: update init-agent CLAUDE.md and .nob.yml templates with apps/shared structure"
```

---

### Task 9: Init-agent — update install step (Step 7)

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Find the install step**

```bash
grep -n "## Step 7\|npm install\|pnpm install\|flutter pub get\|pip install\|go mod tidy" skills/nob/init-agent/SKILL.md | head -15
```

- [ ] **Step 2: Replace the install step content**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
## Step 7: Install dependencies

Run the install command for each layer. Capture exit codes. Continue on failure — do not stop.

**If FRONTEND_TYPE = `next`, `react-vite`, or `vue`:**
Run from `apps/frontend/`: `npm install`

**If FRONTEND_TYPE = `flutter`:**
Run from `apps/frontend/`: `flutter pub get`

**If BACKEND_TYPE = `express`:**
Run from `apps/backend/`: `npm install`

**If BACKEND_TYPE = `fastapi`:**
Run from `apps/backend/`: `python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`

**If BACKEND_TYPE = `go`:**
Run from `apps/backend/`: `go mod tidy` (already run in Step 4; skip if already done)

For each command that fails (non-zero exit code): record `{layer}: FAILED — {error summary}`. Collect all failures for the output block.
```

New:
```
## Step 7: Install dependencies

Run the install commands below. Capture exit codes. Continue on failure — do not stop.

**If any JS/TS app exists (FRONTEND_TYPE is `next`, `react-vite`, or `vue`, OR BACKEND_TYPE is `express`):**
Run from repo root: `pnpm install`
This installs all `apps/*` and `shared/*` workspaces in one command.

**If FRONTEND_TYPE = `flutter`:**
Run from `apps/frontend/`: `flutter pub get`

**If BACKEND_TYPE = `fastapi`:**
Run from `apps/backend/`: `python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`

**If BACKEND_TYPE = `go`:**
Run from `apps/backend/`: `go mod tidy` (already run in Step 4; skip if already done)

For each command that fails (non-zero exit code): record `{layer}: FAILED — {error summary}`. Collect all failures for the output block.
```

- [ ] **Step 3: Verify**

```bash
grep -n "pnpm install\|npm install\|flutter pub get\|pip install\|go mod tidy" skills/nob/init-agent/SKILL.md
```
Expected: `pnpm install` from root present, no bare `npm install` remaining for Node layers, Flutter/Python/Go installs still present.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: update init-agent install step to unified pnpm install from root"
```

---

### Task 10: Init-agent — update output block (Step 8)

**Files:**
- Modify: `skills/nob/init-agent/SKILL.md`

- [ ] **Step 1: Find the output block**

```bash
grep -n "## Step 8\|INIT-AGENT OUTPUT\|Installs:" skills/nob/init-agent/SKILL.md | tail -10
```

- [ ] **Step 2: Replace the output block installs and directory fields**

Edit `skills/nob/init-agent/SKILL.md`:

Old:
```
Installs:
  frontend: [command ✓ | command ✗]
  backend:  [command ✓ | command ✗]

[if any failures:]
Install errors — run manually:
  [cd <dir> && <exact command>]

Frontend start command: [command]
Frontend directory: apps/frontend/
Backend start command: [command]
Backend directory: apps/backend/
```

New:
```
Installs:
  [if JS/TS stack: pnpm install (root) ✓ | pnpm install (root) ✗]
  [if Python backend: apps/backend pip install ✓ | apps/backend pip install ✗]
  [if Go backend: apps/backend go mod tidy ✓ | apps/backend go mod tidy ✗]
  [if Flutter frontend: apps/frontend flutter pub get ✓ | apps/frontend flutter pub get ✗]

[if any failures:]
Install errors — run manually:
  [exact retry command with correct directory]

Frontend start command: [command]
Frontend directory: apps/frontend/
Backend start command: [command]
Backend directory: apps/backend/
```

- [ ] **Step 3: Verify the full output block**

```bash
grep -n "pnpm install (root)\|apps/frontend\|apps/backend\|Install errors" skills/nob/init-agent/SKILL.md | tail -10
```
Expected: updated install lines and correct directory fields.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/init-agent/SKILL.md
git commit -m "feat: update init-agent output block with new install format and apps/ paths"
```

---

### Task 11: End-to-end verification

**Files:** read-only

- [ ] **Step 1: No bare frontend/ or backend/ paths remain in init-agent**

```bash
grep -n "frontend/" skills/nob/init-agent/SKILL.md | grep -v "apps/frontend/"
grep -n "backend/" skills/nob/init-agent/SKILL.md | grep -v "apps/backend/"
```
Expected: no output.

- [ ] **Step 2: All shared/core scaffold triggers present**

```bash
grep -n "pnpm-workspace.yaml\|go\.work\|shared/core/package\.json\|shared/core/contracts/index\.ts\|shared/core/contracts/openapi\.yml\|schema\.prisma\|drizzle\.config\|alembic\|goose" skills/nob/init-agent/SKILL.md | head -20
```
Expected: all 9 patterns appear.

- [ ] **Step 3: Template files updated**

```bash
grep "apps/" skills/nob/templates/.nob.yml.template
grep "apps/" skills/nob/templates/CLAUDE.md.template
grep "AI Agent Rules" skills/nob/templates/CLAUDE.md.template
```
Expected: `apps/frontend/` and `apps/backend/` in both; `AI Agent Rules` in CLAUDE.md template.

- [ ] **Step 4: Hub updated**

```bash
grep "apps/frontend\|apps/backend\|pnpm install (root)" skills/nob/SKILL.md | head -10
```
Expected: auto-detection and terminal summary both show updated paths.

- [ ] **Step 5: ORM_TYPE and PROJECT_SLUG defined before use**

```bash
grep -n "ORM_TYPE\|PROJECT_SLUG" skills/nob/init-agent/SKILL.md
```
Expected: `ORM_TYPE` first defined in Step 3 section, used in Step 4 scaffold section. `PROJECT_SLUG` first defined in shared/core section (Task 7 Step 2).

- [ ] **Step 6: Commit if any fixes were needed**

```bash
git status
```
If clean: done. If changes were made during verification: `git add -p && git commit -m "fix: verification corrections to monorepo structure implementation"`
