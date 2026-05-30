# Nob Scaffolding Support — Design Spec

**Date:** 2026-05-30
**Status:** Approved

## Overview

Add a `/nob init` command that scaffolds a complete, runnable fullstack project from scratch. When run in an empty directory, it asks the user to describe what they're building, recommends a tech stack with reasoning, generates working boilerplate, runs dependency installation, and writes `CLAUDE.md` + `.nob.yml` so the project is immediately ready for `/nob implement`.

---

## Architecture

### Hub changes

The hub's Step 2 workflow identification table gains a 4th entry:

| Intent pattern | Workflow |
|---|---|
| `"nob init"`, `"initialize project"`, `"scaffold project"` | `Init` |

When `Init` is detected, the hub skips Phase 1 (Planner), Phase 2 (PM/Backend/Frontend/QA), and Phase 3 (Reviewer) entirely. It dispatches a single `init-agent` sub-skill at `{SKILL_BASE_DIR}/init-agent/SKILL.md`.

The hub still runs:
- **Step 0** — git branch safety (creates `nob/init` branch if on main)
- **Step 1** — reads `.nob.yml` and `CLAUDE.md`; treats both missing as normal for init
- **Dispatches init-agent** with working directory and user intent

After init-agent returns, the hub prints an Init-specific terminal summary and exits. No checkpoint is written — init is a one-shot, non-resumable operation.

### New file

```
skills/nob/init-agent/SKILL.md
```

---

## Init Agent Flow

### Step 1 — Understand the project

Ask the user one open-ended question:

> "Describe what you're building in a few sentences — what it does, who uses it, and any scale or performance requirements you have in mind."

Wait for the answer. This is the only question asked before recommending a stack.

### Step 2 — Recommend a stack

Based on the description, reason through the best stack per layer and present:

```
Recommended stack for your project:

Frontend:  Next.js 14 (App Router) + TypeScript + Tailwind CSS
Backend:   Node.js + Express + TypeScript
Database:  PostgreSQL + Prisma ORM
Auth:      JWT (stateless, easy to extend)

Why: [2-3 sentence reasoning tied to what the user described]

Accept this stack? Or override any layer?
```

Accept freeform overrides per layer. Resolve final confirmed stack before proceeding.

### Step 3 — Scaffold

Generate all files for the confirmed stack (see Stack Support Matrix and File Structure). Run dependency installs. Write `CLAUDE.md` and `.nob.yml`.

### Step 4 — Output

Emit `[INIT-AGENT OUTPUT]` listing every file created, every install command run, and the confirmed stack. The hub uses this for the terminal summary.

---

## Stack Support Matrix

### Frontend

| Framework | Language | Styling |
|---|---|---|
| Next.js 14 (App Router) | TypeScript | Tailwind CSS |
| React + Vite | TypeScript | Tailwind CSS |
| Vue 3 + Vite | TypeScript | Tailwind CSS |
| Flutter | Dart | Material 3 |

### Backend

| Framework | Language | DB layer |
|---|---|---|
| Express | TypeScript | Prisma + PostgreSQL |
| FastAPI | Python | SQLAlchemy + PostgreSQL |
| Go (net/http or Gin) | Go | pgx + PostgreSQL |

### Database

PostgreSQL is the default. SQLite is offered as an alternative for local-only / simple tools with no external DB requirement.

### What "runnable boilerplate" means

- Working HTTP server with `GET /health`
- One example resource route (`GET /api/v1/items`) with a stub response
- Frontend renders a page that calls the example route and displays the result
- Environment config (`.env.example`, loaded via dotenv / os.environ / godotenv)
- Correct `package.json` / `pyproject.toml` / `go.mod`
- Dependency install runs automatically after scaffold

### Out of scope (v1)

Monorepo tooling, auth implementation, Docker, CI config. These are intentionally deferred — the goal is a foundation Nob can build features on, not a full platform.

---

## Generated Files

Example structure for Next.js + Express:

```
my-project/
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx          ← renders example API call
│   │   │   └── globals.css
│   │   └── lib/
│   │       └── api.ts            ← fetch client pointing to backend
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   └── .env.example
├── backend/
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   │   ├── index.ts
│   │   │   ├── health.ts
│   │   │   └── items.ts
│   │   └── middleware/
│   │       └── errorHandler.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
├── CLAUDE.md
├── .nob.yml
└── .gitignore
```

Structure adapts per stack (e.g., `backend/main.py` + `backend/routes/` for FastAPI, `backend/main.go` + `backend/handlers/` for Go).

---

## CLAUDE.md Generation

Generated with real values (not template placeholders) based on the confirmed stack:

```markdown
# Project: [name derived from user description]

## Stack
- Frontend: [confirmed frontend stack]
- Backend: [confirmed backend stack]

## Folder Structure
- /frontend — [framework] app
- /backend — [framework] API

## API Conventions
- Base URL: /api/v1
- Error format: { "error": { "code": "string", "message": "string" } }

## Frontend Conventions
- Components: functional, hooks only
- API client: /frontend/src/lib/api.ts

## Backend Conventions
- Routes: /backend/src/routes/ (or equivalent for stack)
- Error handler: /backend/src/middleware/errorHandler.ts
- Tests: [test command for the stack]
```

---

## .nob.yml Generation

Generated with `stack.frontend.type`, `stack.frontend.path`, `stack.backend.type`, and `stack.backend.path` pre-filled based on the confirmed stack. No manual editing required before running `/nob implement`.

---

## Error Handling

| Condition | Behaviour |
|---|---|
| Working directory is not empty | Stop immediately with message directing user to `/nob implement` |
| Dependency install fails | Print error, keep generated files, explain how to retry manually, still write `CLAUDE.md` + `.nob.yml` |
| User requests unsupported stack | Offer closest supported alternative or proceed with scaffold + manual setup |
| Description too vague to recommend | Ask one follow-up question before recommending |

---

## Terminal Summary (Init workflow)

```
Nob init complete.

Project:   [name]
Stack:     [frontend] + [backend] + [database]

Files created: [N]
Installs run:
  frontend: npm install ✓
  backend:  npm install ✓

Config written:
  CLAUDE.md
  .nob.yml

Next steps:
  1. Copy .env.example → .env in frontend/ and backend/ and fill in values
  2. Start backend:  cd backend && npm run dev
  3. Start frontend: cd frontend && npm run dev
  4. Write a spec in docs/specs/ and run: /nob implement docs/specs/your-spec.md
```
