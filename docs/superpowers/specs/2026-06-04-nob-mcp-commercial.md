# Nob MCP — Commercial Product Spec

**Date:** 2026-06-04  
**Status:** Approved  
**Author:** Ly Chaovirun

---

## Overview

Rebuild Nob as a commercial cloud SaaS MCP server. The current Claude Code plugin (Markdown skill files) is replaced by a hosted TypeScript MCP server that drives Nob's spec-driven pipeline (PM → Tech Lead → Backend + Frontend → Reviewer) remotely, while all file I/O executes locally on the user's machine via Claude Desktop or Claude Code.

This makes Nob available to any Claude Desktop or Claude Code user without installation — they configure the MCP server URL and API key once, then run `/nob` as before.

---

## Goals

- Ship a billable, hosted MCP server with subscription tiers
- Preserve Nob's core value props: enforced spec validation, multi-role pipeline, API contract enforcement, automated Reviewer with retry loop
- Zero codebase exposure — no code ever leaves the user's machine
- Support Claude Desktop + Claude Code on day one; extend to other MCP clients later

---

## Non-Goals (v1)

- Self-hosted deployment option
- GitHub/GitLab repo integration
- Visual/browser preview
- Design-to-code (Figma input)
- Async background execution
- MCP clients other than Claude Desktop / Claude Code

---

## System Architecture

```
User's Machine
┌─────────────────────────────────────────────────────┐
│  Claude Desktop / Claude Code                        │
│    │                                                 │
│    ├── calls local tools (file read/write, git)      │
│    └── MCP tool calls (HTTPS + API key)              │
└─────────────────────────────────────────────────────┘
                │
         MCP tool calls (HTTPS + API key)
                │
Nob Cloud (nob.run)
┌─────────────────────────────────────────────────────┐
│  MCP Server (TypeScript / Fastify)                   │
│    - Validates API key                               │
│    - Drives pipeline state machine                   │
│    - Returns phase prompts to Claude                 │
│    - Records billing events                          │
│                  │                                   │
│           Postgres                                   │
│           users, api_keys, runs, phases,             │
│           billing_events                             │
└─────────────────────────────────────────────────────┘
                │
Stripe (billing) │ Resend (email)
```

**Run flow:**
1. Claude calls `nob_start(spec_content, codebase_context)` — server validates spec, creates run, returns PM prompt
2. Claude executes PM locally, calls `nob_advance(run_id, pm_result)` — server returns Tech Lead prompt
3. Claude executes Tech Lead locally, calls `nob_advance(run_id, tech_lead_result)` — server returns Backend + Frontend prompts together
4. Claude executes both as parallel sub-agents locally, calls `nob_advance(run_id, dev_results)` — server returns Reviewer prompt
5. Claude executes Reviewer locally, calls `nob_advance(run_id, reviewer_result)` — server parses verdict, records billing event, returns final state
6. On FAIL + retries remaining: server injects diagnostic block, re-returns dev prompts

---

## MCP Tools

### `nob_start`
```
Input:
  spec_content: string          — full spec markdown
  codebase_context: string      — JSON-stringified { stack: string, file_tree: string,
                                   key_files: string[] } — Claude constructs this
                                   by reading the project before calling nob_start

Output:
  run_id: string
  phase: "pm"
  prompt: string                — full PM agent instructions
  acceptance_criteria: string[] — extracted from spec

Errors:
  missing_acceptance_criteria   — spec has no ## Acceptance criteria section
  run_limit_reached             — user has hit their plan's monthly run limit
```

### `nob_advance`
```
Input:
  run_id: string
  phase_result: string          — output from the just-completed phase.
                                  For the dev phase, Claude calls nob_advance ONCE
                                  with a combined result: backend and frontend outputs
                                  concatenated with a [BACKEND] / [FRONTEND] separator.

Output:
  phase: "tech_lead" | "dev" | "reviewer" | "done"
  prompt: string | { backend: string, frontend: string }
                                  When phase = "dev", the response contains both
                                  backend and frontend prompts. The PM prompt instructs
                                  Claude to dispatch both as parallel Agent tool calls
                                  and wait for both before calling nob_advance.
  verdict?: "PASS" | "NEEDS_REVIEW" | "FAIL"   — only when phase = "done"
  retry_count?: number

Errors:
  empty_result                  — phase_result under 50 chars
  invalid_phase_transition      — run is not in expected phase
  run_not_found
```

### `nob_status`
```
Input:
  run_id: string

Output:
  run_id, phase, verdict, created_at, updated_at
  phases_completed: string[]
  error?: string
```

### `nob_list_runs`
```
Input:
  limit?: number   (default 10)

Output:
  runs: Array<{ run_id, spec_title, phase, verdict, created_at }>
```

---

## Data Model

```sql
users
  id                  uuid PK
  email               text unique
  stripe_customer_id  text
  plan                enum('free', 'solo', 'team')
  created_at          timestamptz

api_keys
  id            uuid PK
  user_id       uuid FK → users
  key_hash      text unique     -- bcrypt hash, never store plaintext
  label         text            -- "My Mac", "Work laptop"
  last_used_at  timestamptz
  created_at    timestamptz

runs
  id                   uuid PK
  user_id              uuid FK → users
  spec_title           text
  spec_content         text
  acceptance_criteria  jsonb     -- string[]
  current_phase        enum('pm','tech_lead','dev','reviewer','done','failed')
  verdict              enum('PASS','NEEDS_REVIEW','FAIL') nullable
  retry_count          int default 0
  created_at           timestamptz
  updated_at           timestamptz

phases
  id            uuid PK
  run_id        uuid FK → runs
  phase         text            -- 'pm', 'tech_lead', 'backend', 'frontend', 'reviewer'
  prompt_sent   text
  result        text
  completed_at  timestamptz

billing_events
  id            uuid PK
  user_id       uuid FK → users
  run_id        uuid FK → runs
  event         text            -- 'run_started', 'run_completed', 'retry'
  created_at    timestamptz
```

---

## Auth & Billing

### API Key Auth
Every MCP tool call includes `Authorization: Bearer nob_<key>`. Server bcrypt-hashes the key and looks up `api_keys`. Key shown once at creation, never retrievable again.

### Dashboard Auth
Email + magic link via Resend. No passwords.

### Plans

| Plan | Price    | Runs/month | Retries | Parallel dev agents |
|------|----------|-----------|---------|-------------------|
| Free | $0       | 5         | 0       | No                |
| Solo | $29/mo   | 50        | 3       | Yes               |
| Team | $99/mo   | 200       | 5       | Yes               |

"Run" = one full pipeline execution. Retries do not count as new runs.

### Billing Flow
- Stripe Checkout for plan upgrades (redirect from dashboard)
- Stripe webhooks update `users.plan`
- `billing_events` tracks run usage; server checks count before allowing `nob_start`
- Limit hit → `nob_start` returns `{ error: "run_limit_reached", upgrade_url: "https://nob.run/upgrade" }`

---

## Pipeline State Machine

```
nob_start()
    │
    ▼
┌─────────┐
│   PM    │◄── spec validation gate (reject if no acceptance_criteria)
└────┬────┘
     │ nob_advance(pm_result)
     ▼
┌────────────┐
│ TECH LEAD  │
└─────┬──────┘
      │ nob_advance(tech_lead_result)
      ▼
┌─────────────────┐
│ BACKEND+FRONTEND│  ← both prompts returned together
│   (parallel)    │
└────────┬────────┘
         │ nob_advance(dev_results)
         ▼
   ┌──────────┐
   │ REVIEWER │
   └────┬─────┘
        │ nob_advance(reviewer_result)
        ▼
┌───────────────┐
│ Parse verdict │
└───────┬───────┘
    ┌───┴───┬────────┐
    ▼       ▼        ▼
  PASS  NEEDS_REVIEW FAIL
    │       │         │
  done    done   retry < MAX?
                  │        │
                 yes       no
                  │        │
             re-run dev  FAILED
             with diag   (done)
```

**Transition rules:**
- `nob_advance` rejects `phase_result` under 50 chars
- Phases must advance in order; calling on a `done` run returns an error
- On FAIL + retry: Reviewer's failure reasons prepended as `[DIAGNOSTIC]` block in dev prompt
- `MAX_RETRIES` is plan-gated: Free=0, Solo=3, Team=5
- If `retry_count >= MAX_RETRIES` on FAIL: run moves to `failed`, Claude surfaces Reviewer report to user

**Prompt construction (server-side):**
Each phase prompt assembled from:
1. Base template (PM / Tech Lead / Backend / Frontend / Reviewer — ported from current SKILL.md files)
2. Spec content (from `runs.spec_content`)
3. Previous phase results (from `phases` table, injected as context)
4. Stack-specific instructions (detected from `codebase_context`)

---

## Tech Stack

### Server
```
Runtime:     Node.js 22 (LTS)
Language:    TypeScript 5
Framework:   Fastify
MCP SDK:     @modelcontextprotocol/sdk
ORM:         Drizzle ORM
Database:    Postgres 16 (Supabase)
Email:       Resend (magic links)
Billing:     Stripe
Deployment:  Railway
```

### Dashboard
```
Framework:   Next.js 14 (App Router)
Styling:     Tailwind + shadcn/ui
Auth:        next-auth with Resend email provider
Hosting:     Vercel
```

### Repo Structure
```
nob-mcp/
  server/
    src/
      tools/        — nob_start, nob_advance, nob_status, nob_list_runs
      pipeline/     — state machine, phase transitions, prompt builder
      prompts/      — PM, tech-lead, backend, frontend, reviewer templates
      db/           — Drizzle schema + migrations
      billing/      — Stripe webhook handler, plan enforcement
      auth/         — API key validation, magic link
    index.ts
  dashboard/        — Next.js app
  shared/           — types shared between server and dashboard
```

### Local Dev
```bash
pnpm install
docker compose up -d   # Postgres
pnpm dev               # server + dashboard hot reload
```

### Deployment
- Server → Railway (auto-deploy on push to main)
- Dashboard → Vercel (auto-deploy on push to main)
- DB migrations run automatically on deploy via Drizzle Kit

---

## Acceptance Criteria

- [ ] `nob_start` rejects specs without `## Acceptance criteria` section
- [ ] `nob_start` enforces monthly run limits per plan before creating a run
- [ ] `nob_advance` enforces phase ordering — out-of-order calls return a structured error
- [ ] `nob_advance` rejects empty/trivial results (< 50 chars)
- [ ] FAIL verdict triggers retry loop up to plan MAX_RETRIES with diagnostic injection
- [ ] FAIL at MAX_RETRIES moves run to `failed` state, returns Reviewer report
- [ ] API keys are bcrypt-hashed at creation; plaintext never stored
- [ ] API key shown exactly once at creation; not retrievable after
- [ ] Dashboard: create/revoke API keys, view runs, upgrade plan via Stripe Checkout
- [ ] Stripe webhooks correctly update `users.plan` on subscription changes
- [ ] `nob_status` allows resume of interrupted runs
- [ ] All four MCP tools work from Claude Desktop and Claude Code
