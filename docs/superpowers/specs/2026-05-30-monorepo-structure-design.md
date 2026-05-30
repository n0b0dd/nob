# Nob Universal Monorepo Structure — Design Spec

**Date:** 2026-05-30
**Status:** Approved

## Overview

Replace the current flat `frontend/` + `backend/` scaffold with a universal, domain-organized monorepo structure: `apps/` (deployable targets) + `shared/` (shared by domain). This structure works across all supported stacks (Node, Python, Go, Flutter), scales without restructuring, and bakes AI agent boundary rules into every generated `CLAUDE.md`.

---

## Core Structure

```
my-project/
├── apps/
│   ├── backend/               ← API / orchestration service
│   └── frontend/              ← UI / dashboard
├── shared/
│   └── core/                  ← cross-cutting concerns (always scaffolded)
│       ├── contracts/         ← types, API shapes, interfaces
│       └── schema/            ← DB schema, migrations
├── pnpm-workspace.yaml        ← JS/TS stacks only
├── go.work                    ← Go stacks only
├── package.json               ← JS/TS stacks only (root orchestrator)
├── CLAUDE.md
├── .nob.yml
└── .gitignore
```

### Why `shared/[domain]/` not `shared/[type]/`

Organizing by type (`contracts/`, `schema/` at root of `shared/`) creates a dumping ground at scale. Organizing by domain means adding a new concern is always `shared/[domain]/` — no restructuring, no file moves, no path updates.

As a project grows:
```
shared/
  core/        ← always present from day one
  user/        ← added when user domain gets complex
  billing/     ← added when payments arrive
  game-state/  ← added for game-specific shared logic
```

---

## Stack Recommendation Step (Step 3)

The existing stack recommendation gains a "Packages" line:

```
Recommended stack for your project:

Frontend:  Next.js 14 + TypeScript + Tailwind CSS
Backend:   Node.js + Express + TypeScript
Database:  PostgreSQL + Prisma ORM
Packages:  shared/core (Prisma schema + TypeScript contracts)

Why: [2–3 sentences]

Does this stack work? Or override any layer?
(e.g. "use Drizzle instead of Prisma", "add a billing domain")
```

ORM defaults per backend type:
- `express` + `postgres` → Prisma
- `express` + `sqlite` → Prisma (SQLite provider)
- `fastapi` → shared SQL migrations (Alembic)
- `go` → shared SQL migrations (goose)

User can override the ORM at this step (e.g. "use Drizzle", "use Kysely").

---

## Scaffolded Files

### Always generated (all stacks)

- `.gitignore`
- `CLAUDE.md` — with explicit AI agent boundary rules
- `.nob.yml` — with updated paths (`apps/frontend/`, `apps/backend/`, `shared/core/`)
- `shared/core/contracts/` — directory always created
- `shared/core/schema/` — directory always created

### Conditional on stack

| File | Condition |
|---|---|
| `pnpm-workspace.yaml` | Any JS/TS app (Node frontend or backend) |
| Root `package.json` | Any JS/TS app |
| `go.work` | Backend is Go |
| `shared/core/package.json` | Any JS/TS app |
| `shared/core/pyproject.toml` | Backend is Python (minimal package: name, version, empty `__init__.py`) |
| `shared/core/contracts/index.ts` | Any JS/TS app |
| `shared/core/contracts/openapi.yml` | Backend is Python or Go |
| `shared/core/schema/schema.prisma` | Backend is Node + Prisma |
| `shared/core/schema/drizzle.config.ts` | Backend is Node + Drizzle |
| `shared/core/schema/migrations/` | Backend is Python or Go |

### `pnpm-workspace.yaml` (JS/TS stacks)

```yaml
packages:
  - 'apps/*'
  - 'shared/*'
```

### Root `package.json` (JS/TS stacks)

```json
{
  "name": "[project-slug]",
  "private": true,
  "scripts": {
    "dev:frontend": "pnpm --filter frontend dev",
    "dev:backend": "pnpm --filter backend dev"
  }
}
```

### `go.work` (Go stacks)

```
go 1.22

use (
    ./apps/backend
)
```

### `shared/core/package.json` (JS/TS stacks)

```json
{
  "name": "@[project-slug]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts"
}
```

### `shared/core/contracts/index.ts` (JS/TS stacks)

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

### `shared/core/contracts/openapi.yml` (Python/Go stacks)

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

---

## App File Paths

All app files move from `frontend/` → `apps/frontend/` and `backend/` → `apps/backend/`. Internal file structure within each app is unchanged.

---

## CLAUDE.md Generation

Generated with confirmed stack values and explicit AI agent boundary rules:

```markdown
# Project: [PROJECT_NAME]

## Stack
- Frontend: [confirmed frontend stack]
- Backend: [confirmed backend stack]
- Database: [confirmed database + ORM]

## Structure
- `apps/frontend/`  — UI layer. Deployable target. No business logic.
- `apps/backend/`   — API layer. Deployable target. No shared contracts here.
- `shared/core/contracts/` — Source of truth for types and API shapes. Edit here when the contract between frontend and backend changes.
- `shared/core/schema/`    — Source of truth for database schema. Edit here for all DB changes.

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

## Dev Commands
- Start backend:  [backend start command]
- Start frontend: [frontend start command]
```

---

## `.nob.yml` Generation

```yaml
stack:
  frontend:
    type: [FRONTEND_TYPE]
    enabled: true
    path: apps/frontend/
  backend:
    type: [node | python | go]
    enabled: true
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
    init-agent: sonnet
  max_parallel_slices: 3
  checkpoint:
    enabled: true
    path: .nob/
```

---

## Install Step

| Stack | Command | Run from |
|---|---|---|
| Any JS/TS app | `pnpm install` | root |
| Python backend | `python -m venv .venv && pip install -r requirements.txt` | `apps/backend/` |
| Go backend | `go mod tidy` | `apps/backend/` |
| Flutter frontend | `flutter pub get` | `apps/frontend/` |

For JS/TS stacks, a single `pnpm install` at root installs all `apps/*` and `shared/*` workspaces.

---

## Terminal Summary (updated paths)

```
Nob init complete.

Project:   [name]
Stack:     [frontend] + [backend] + [database]

Files created: [N]
Installs:
  [if JS/TS stack:]
  pnpm install (root) ✓         ← installs all apps/* and shared/*
  [if Python backend:]
  apps/backend: pip install ✓
  [if Go backend:]
  apps/backend: go mod tidy ✓
  [if Flutter frontend:]
  apps/frontend: flutter pub get ✓

Config written:
  CLAUDE.md
  .nob.yml

Next steps:
  1. Copy .env.example → .env in apps/frontend/ and apps/backend/
  2. Start backend:  [backend start command]
  3. Start frontend: [frontend start command]
  4. Write a spec:   docs/specs/your-feature.md
  5. Then run:       /nob implement docs/specs/your-feature.md
```

---

## Files Modified

- `skills/nob/init-agent/SKILL.md` — full rewrite: new structure, conditional workspace tooling, updated CLAUDE.md template, updated paths throughout
- `skills/nob/SKILL.md` — update terminal summary paths
- `skills/nob/templates/.nob.yml.template` — update paths to `apps/frontend/`, `apps/backend/`, add `shared.core`
- `skills/nob/templates/CLAUDE.md.template` — update folder structure section and add AI agent rules

---

## Out of Scope

- Multiple `shared/[domain]/` beyond `core/` — init scaffolds `core/` only; users add domains as needed
- Turborepo / Nx — not added; pnpm workspaces remain the only workspace tooling
- Docker, CI config — unchanged from v1 scope
