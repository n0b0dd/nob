# Nob MCP Commercial Product — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cloud SaaS MCP server that drives Nob's spec-driven pipeline (PM → Tech Lead → Backend + Frontend → Reviewer) with subscription billing, API key auth, and a minimal web dashboard.

**Architecture:** A Fastify MCP server stores pipeline state in Postgres and returns phase prompts to Claude; all file I/O executes locally on the user's machine. A Next.js dashboard handles API key management and Stripe billing. A shared types package ties them together.

**Tech Stack:** TypeScript 5, Node.js 22, Fastify, `@modelcontextprotocol/sdk`, Drizzle ORM, Postgres 16, Stripe, Resend, Next.js 14, Tailwind, shadcn/ui, Vitest, pnpm workspaces, Railway (server), Vercel (dashboard), Supabase (DB).

---

## File Map

```
nob-mcp/
  package.json                          — pnpm workspace root
  pnpm-workspace.yaml
  docker-compose.yml                    — local Postgres for dev

  shared/
    package.json
    src/types.ts                        — all shared types: Run, Phase, Plan, tool I/O

  server/
    package.json
    tsconfig.json
    vitest.config.ts
    drizzle.config.ts
    src/
      index.ts                          — Fastify entry point + MCP transport
      db/
        schema.ts                       — Drizzle schema (5 tables)
        client.ts                       — Drizzle client singleton
      auth/
        apiKey.ts                       — validateApiKey, createApiKey, revokeApiKey
        magicLink.ts                    — sendMagicLink, verifyToken
      pipeline/
        specValidator.ts                — validateSpec → { valid, acceptanceCriteria }
        verdictParser.ts                — parseVerdict → PASS | NEEDS_REVIEW | FAIL
        stateMachine.ts                 — advance(run, result) → nextPhase + nextPrompt
        promptBuilder.ts               — buildPrompt(phase, run, previousPhases)
      prompts/
        pm.ts                           — PM agent prompt template function
        techLead.ts                     — Tech Lead prompt template function
        backend.ts                      — Backend prompt template function
        frontend.ts                     — Frontend prompt template function
        reviewer.ts                     — Reviewer prompt template function
      billing/
        plans.ts                        — PLAN_LIMITS, checkRunLimit, recordBillingEvent
        stripeWebhook.ts               — handleStripeWebhook(event)
      tools/
        nobStart.ts                     — nob_start tool handler
        nobAdvance.ts                   — nob_advance tool handler
        nobStatus.ts                    — nob_status tool handler
        nobListRuns.ts                  — nob_list_runs tool handler
      routes/
        webhook.ts                      — POST /webhook/stripe
        api.ts                          — REST routes for dashboard
    test/
      pipeline/
        specValidator.test.ts
        verdictParser.test.ts
        stateMachine.test.ts
      auth/
        apiKey.test.ts
      billing/
        plans.test.ts
      tools/
        nobStart.test.ts
        nobAdvance.test.ts

  dashboard/
    package.json
    app/
      page.tsx                          — redirect to /login or /dashboard/keys
      login/page.tsx                    — magic link login form
      dashboard/
        layout.tsx                      — session guard
        keys/page.tsx                   — create/revoke API keys
        runs/page.tsx                   — run history list
        billing/page.tsx               — plan + usage + Stripe Checkout button
      api/
        auth/[...nextauth]/route.ts    — next-auth Resend magic link
        keys/route.ts                  — proxy to server REST API
        runs/route.ts                  — proxy to server REST API
        billing/checkout/route.ts      — create Stripe Checkout session
```

---

## Task 1: Monorepo Scaffold

**Files:**
- Create: `nob-mcp/package.json`
- Create: `nob-mcp/pnpm-workspace.yaml`
- Create: `nob-mcp/docker-compose.yml`
- Create: `nob-mcp/shared/package.json`
- Create: `nob-mcp/shared/src/types.ts`
- Create: `nob-mcp/server/package.json`
- Create: `nob-mcp/server/tsconfig.json`
- Create: `nob-mcp/server/vitest.config.ts`

- [ ] **Step 1: Create the repo directory and workspace root**

```bash
mkdir nob-mcp && cd nob-mcp
git init
```

- [ ] **Step 2: Write `package.json` (workspace root)**

```json
{
  "name": "nob-mcp",
  "private": true,
  "scripts": {
    "dev": "pnpm --filter server dev",
    "build": "pnpm --filter server build",
    "test": "pnpm --filter server test"
  }
}
```

- [ ] **Step 3: Write `pnpm-workspace.yaml`**

```yaml
packages:
  - 'shared'
  - 'server'
  - 'dashboard'
```

- [ ] **Step 4: Write `docker-compose.yml`**

```yaml
version: '3.9'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: nob
      POSTGRES_USER: nob
      POSTGRES_PASSWORD: nob
    ports:
      - '5432:5432'
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

- [ ] **Step 5: Write `shared/package.json`**

```json
{
  "name": "@nob/shared",
  "version": "0.0.1",
  "main": "./src/types.ts",
  "exports": {
    ".": "./src/types.ts"
  }
}
```

- [ ] **Step 6: Write `shared/src/types.ts`**

```typescript
export type Plan = 'free' | 'solo' | 'team'

export type RunPhase =
  | 'pm'
  | 'tech_lead'
  | 'dev'
  | 'reviewer'
  | 'done'
  | 'failed'

export type Verdict = 'PASS' | 'NEEDS_REVIEW' | 'FAIL'

export interface Run {
  id: string
  userId: string
  specTitle: string
  specContent: string
  acceptanceCriteria: string[]
  currentPhase: RunPhase
  verdict: Verdict | null
  retryCount: number
  createdAt: Date
  updatedAt: Date
}

export interface PhaseRecord {
  id: string
  runId: string
  phase: string
  promptSent: string
  result: string
  completedAt: Date
}

// MCP tool I/O shapes
export interface NobStartInput {
  spec_content: string
  codebase_context: string
}

export interface NobStartOutput {
  run_id: string
  phase: 'pm'
  prompt: string
  acceptance_criteria: string[]
}

export interface NobAdvanceInput {
  run_id: string
  phase_result: string
}

export interface NobAdvanceOutput {
  phase: RunPhase
  prompt: string | { backend: string; frontend: string }
  verdict?: Verdict
  retry_count?: number
}

export interface NobStatusOutput {
  run_id: string
  phase: RunPhase
  verdict: Verdict | null
  created_at: string
  updated_at: string
  phases_completed: string[]
  error?: string
}

export interface NobListRunsOutput {
  runs: Array<{
    run_id: string
    spec_title: string
    phase: RunPhase
    verdict: Verdict | null
    created_at: string
  }>
}

export interface PlanLimits {
  runsPerMonth: number
  maxRetries: number
  parallelDev: boolean
}

export const PLAN_LIMITS: Record<Plan, PlanLimits> = {
  free:  { runsPerMonth: 5,   maxRetries: 0, parallelDev: false },
  solo:  { runsPerMonth: 50,  maxRetries: 3, parallelDev: true },
  team:  { runsPerMonth: 200, maxRetries: 5, parallelDev: true },
}
```

- [ ] **Step 7: Write `server/package.json`**

```json
{
  "name": "@nob/server",
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest run",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "@nob/shared": "workspace:*",
    "bcryptjs": "^2.4.3",
    "drizzle-orm": "^0.30.0",
    "fastify": "^4.27.0",
    "pg": "^8.11.0",
    "resend": "^3.0.0",
    "stripe": "^14.0.0",
    "uuid": "^9.0.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/node": "^20.0.0",
    "@types/pg": "^8.11.0",
    "@types/uuid": "^9.0.0",
    "drizzle-kit": "^0.20.0",
    "tsx": "^4.7.0",
    "typescript": "^5.4.0",
    "vitest": "^1.4.0"
  }
}
```

- [ ] **Step 8: Write `server/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

- [ ] **Step 9: Write `server/vitest.config.ts`**

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
  },
})
```

- [ ] **Step 10: Install dependencies**

```bash
cd nob-mcp && pnpm install
```

Expected: packages installed with no errors.

- [ ] **Step 11: Commit**

```bash
git add .
git commit -m "chore: scaffold nob-mcp monorepo with shared types"
```

---

## Task 2: Database Schema + Drizzle Client

**Files:**
- Create: `server/src/db/schema.ts`
- Create: `server/src/db/client.ts`
- Create: `server/drizzle.config.ts`
- Create: `server/.env.example`

- [ ] **Step 1: Write `server/src/db/schema.ts`**

```typescript
import {
  pgTable, uuid, text, timestamp, integer, jsonb, pgEnum
} from 'drizzle-orm/pg-core'

export const planEnum = pgEnum('plan', ['free', 'solo', 'team'])
export const runPhaseEnum = pgEnum('run_phase', [
  'pm', 'tech_lead', 'dev', 'reviewer', 'done', 'failed'
])
export const verdictEnum = pgEnum('verdict', ['PASS', 'NEEDS_REVIEW', 'FAIL'])

export const users = pgTable('users', {
  id:               uuid('id').primaryKey().defaultRandom(),
  email:            text('email').notNull().unique(),
  stripeCustomerId: text('stripe_customer_id'),
  plan:             planEnum('plan').notNull().default('free'),
  createdAt:        timestamp('created_at').notNull().defaultNow(),
})

export const apiKeys = pgTable('api_keys', {
  id:          uuid('id').primaryKey().defaultRandom(),
  userId:      uuid('user_id').notNull().references(() => users.id),
  keyHash:     text('key_hash').notNull().unique(),
  label:       text('label').notNull(),
  lastUsedAt:  timestamp('last_used_at'),
  createdAt:   timestamp('created_at').notNull().defaultNow(),
})

export const runs = pgTable('runs', {
  id:                  uuid('id').primaryKey().defaultRandom(),
  userId:              uuid('user_id').notNull().references(() => users.id),
  specTitle:           text('spec_title').notNull(),
  specContent:         text('spec_content').notNull(),
  acceptanceCriteria:  jsonb('acceptance_criteria').notNull().$type<string[]>(),
  currentPhase:        runPhaseEnum('current_phase').notNull().default('pm'),
  verdict:             verdictEnum('verdict'),
  retryCount:          integer('retry_count').notNull().default(0),
  createdAt:           timestamp('created_at').notNull().defaultNow(),
  updatedAt:           timestamp('updated_at').notNull().defaultNow(),
})

export const phases = pgTable('phases', {
  id:          uuid('id').primaryKey().defaultRandom(),
  runId:       uuid('run_id').notNull().references(() => runs.id),
  phase:       text('phase').notNull(),
  promptSent:  text('prompt_sent').notNull(),
  result:      text('result').notNull().default(''),
  completedAt: timestamp('completed_at'),
})

export const billingEvents = pgTable('billing_events', {
  id:        uuid('id').primaryKey().defaultRandom(),
  userId:    uuid('user_id').notNull().references(() => users.id),
  runId:     uuid('run_id').references(() => runs.id),
  event:     text('event').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})
```

- [ ] **Step 2: Write `server/src/db/client.ts`**

```typescript
import { drizzle } from 'drizzle-orm/node-postgres'
import pg from 'pg'
import * as schema from './schema.js'

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL!,
})

export const db = drizzle(pool, { schema })
export type DB = typeof db
```

- [ ] **Step 3: Write `server/drizzle.config.ts`**

```typescript
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: './src/db/schema.ts',
  out:    './src/db/migrations',
  driver: 'pg',
  dbCredentials: {
    connectionString: process.env.DATABASE_URL!,
  },
})
```

- [ ] **Step 4: Write `server/.env.example`**

```
DATABASE_URL=postgres://nob:nob@localhost:5432/nob
API_KEY_SECRET=change-me-32-chars-minimum
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
RESEND_API_KEY=re_...
MAGIC_LINK_SECRET=change-me-32-chars-minimum
APP_URL=http://localhost:3000
```

- [ ] **Step 5: Start Postgres and generate migration**

```bash
docker compose up -d
cp server/.env.example server/.env
# Edit server/.env with real values
cd server && pnpm db:generate
```

Expected: `src/db/migrations/0000_initial.sql` created.

- [ ] **Step 6: Run migration**

```bash
pnpm db:migrate
```

Expected: "Migration applied" with no errors.

- [ ] **Step 7: Commit**

```bash
git add server/src/db server/drizzle.config.ts server/.env.example
git commit -m "feat: add drizzle schema and postgres client"
```

---

## Task 3: Spec Validator

**Files:**
- Create: `server/src/pipeline/specValidator.ts`
- Create: `server/test/pipeline/specValidator.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/pipeline/specValidator.test.ts
import { describe, it, expect } from 'vitest'
import { validateSpec } from '../../src/pipeline/specValidator.js'

describe('validateSpec', () => {
  it('returns valid=true and extracts criteria when section exists', () => {
    const spec = `# My Feature\n\n## Acceptance criteria\n\n- [ ] Users can login\n- [ ] Session persists`
    const result = validateSpec(spec)
    expect(result.valid).toBe(true)
    expect(result.acceptanceCriteria).toEqual([
      'Users can login',
      'Session persists',
    ])
  })

  it('returns valid=false when ## Acceptance criteria section is missing', () => {
    const spec = `# My Feature\n\nSome description without criteria.`
    const result = validateSpec(spec)
    expect(result.valid).toBe(false)
    expect(result.acceptanceCriteria).toEqual([])
  })

  it('returns valid=false when spec is empty', () => {
    const result = validateSpec('')
    expect(result.valid).toBe(false)
  })

  it('extracts criteria ignoring checkbox prefix', () => {
    const spec = `## Acceptance criteria\n\n- [ ] First item\n- [x] Second item\n- Third item`
    const result = validateSpec(spec)
    expect(result.acceptanceCriteria).toEqual([
      'First item',
      'Second item',
      'Third item',
    ])
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd server && pnpm test test/pipeline/specValidator.test.ts
```

Expected: FAIL — "Cannot find module specValidator"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/pipeline/specValidator.ts
export interface SpecValidationResult {
  valid: boolean
  acceptanceCriteria: string[]
}

export function validateSpec(specContent: string): SpecValidationResult {
  if (!specContent.trim()) return { valid: false, acceptanceCriteria: [] }

  const criteriaMatch = specContent.match(
    /##\s+Acceptance criteria\s*\n([\s\S]*?)(?=\n##|\s*$)/i
  )
  if (!criteriaMatch) return { valid: false, acceptanceCriteria: [] }

  const criteriaBlock = criteriaMatch[1]
  const criteria = criteriaBlock
    .split('\n')
    .map(line => line.replace(/^-\s+\[[ x]\]\s+/, '').replace(/^-\s+/, '').trim())
    .filter(line => line.length > 0)

  return { valid: criteria.length > 0, acceptanceCriteria: criteria }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/pipeline/specValidator.test.ts
```

Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/pipeline/specValidator.ts server/test/pipeline/specValidator.test.ts
git commit -m "feat: add spec validator with acceptance criteria extraction"
```

---

## Task 4: Verdict Parser

**Files:**
- Create: `server/src/pipeline/verdictParser.ts`
- Create: `server/test/pipeline/verdictParser.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/pipeline/verdictParser.test.ts
import { describe, it, expect } from 'vitest'
import { parseVerdict } from '../../src/pipeline/verdictParser.js'

describe('parseVerdict', () => {
  it('detects PASS', () => {
    expect(parseVerdict('All criteria met.\n\n**VERDICT: PASS**')).toBe('PASS')
  })

  it('detects FAIL', () => {
    expect(parseVerdict('Auth missing.\n\n**VERDICT: FAIL**')).toBe('FAIL')
  })

  it('detects NEEDS_REVIEW', () => {
    expect(parseVerdict('Some concerns.\n\n**VERDICT: NEEDS REVIEW**')).toBe('NEEDS_REVIEW')
  })

  it('is case-insensitive', () => {
    expect(parseVerdict('verdict: pass')).toBe('PASS')
    expect(parseVerdict('Verdict: Fail')).toBe('FAIL')
  })

  it('defaults to NEEDS_REVIEW when no verdict keyword found', () => {
    expect(parseVerdict('The implementation looks okay but I am not sure.')).toBe('NEEDS_REVIEW')
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/pipeline/verdictParser.test.ts
```

Expected: FAIL — "Cannot find module verdictParser"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/pipeline/verdictParser.ts
import type { Verdict } from '@nob/shared'

export function parseVerdict(reviewerResult: string): Verdict {
  const text = reviewerResult.toLowerCase()
  if (text.includes('verdict: pass') || text.includes('verdict:**pass') || text.match(/verdict[:\s]+pass/)) {
    return 'PASS'
  }
  if (text.includes('verdict: fail') || text.match(/verdict[:\s]+fail/)) {
    return 'FAIL'
  }
  if (text.includes('needs review') || text.includes('needs_review')) {
    return 'NEEDS_REVIEW'
  }
  // PASS wins if the word "pass" appears prominently and "fail" does not
  if (text.includes('pass') && !text.includes('fail')) return 'PASS'
  return 'NEEDS_REVIEW'
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/pipeline/verdictParser.test.ts
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/pipeline/verdictParser.ts server/test/pipeline/verdictParser.test.ts
git commit -m "feat: add reviewer verdict parser"
```

---

## Task 5: Prompt Templates

**Files:**
- Create: `server/src/prompts/pm.ts`
- Create: `server/src/prompts/techLead.ts`
- Create: `server/src/prompts/backend.ts`
- Create: `server/src/prompts/frontend.ts`
- Create: `server/src/prompts/reviewer.ts`

These port the logic from the existing SKILL.md files in `skills/` into TypeScript template functions. Open each SKILL.md, copy the agent instructions, and wrap them as a template string function that injects spec + context + previous phase results.

- [ ] **Step 1: Port PM prompt from `skills/pm/SKILL.md`**

```typescript
// server/src/prompts/pm.ts
export interface PromptContext {
  specContent: string
  codembaseContext: string
  previousPhaseResults?: string
  acceptanceCriteria: string[]
  diagnostic?: string
}

export function buildPmPrompt(ctx: PromptContext): string {
  return `You are a Product Manager agent in the Nob pipeline.

## Your task
Extract structured requirements from the spec below and clarify any ambiguities before implementation begins.

## Spec
${ctx.specContent}

## Codebase context
${ctx.codembaseContext}

## Instructions
1. Read the spec carefully.
2. List any ambiguities or missing requirements that would block implementation.
3. If ambiguities exist, ask up to 3 clarifying questions (numbered). Wait for answers before proceeding.
4. Once requirements are clear, output a structured [PM OUTPUT] block:
   - Feature summary (2-3 sentences)
   - Acceptance criteria (copied verbatim from spec)
   - Out of scope items
   - Suggested implementation order

## Output format
End your response with:
[PM OUTPUT]
...structured requirements...
[/PM OUTPUT]

The next agent (Tech Lead) will receive your [PM OUTPUT] block.`
}
```

- [ ] **Step 2: Port Tech Lead prompt from `skills/tech-lead/SKILL.md`**

```typescript
// server/src/prompts/techLead.ts
import type { PromptContext } from './pm.js'

export function buildTechLeadPrompt(ctx: PromptContext): string {
  return `You are the Tech Lead agent in the Nob pipeline.

## Your task
Write API contracts and cross-layer coordination instructions for the Backend and Frontend agents.

## PM Output (requirements)
${ctx.previousPhaseResults}

## Codebase context
${ctx.codembaseContext}

## Instructions
1. Identify all API endpoints or data contracts needed between backend and frontend.
2. For each endpoint, specify: method, path, request shape, response shape, auth requirements.
3. Identify shared types.
4. Write Backend and Frontend agent briefs — what each must implement.

## Output format
End your response with:
[TECH LEAD OUTPUT]
### API Contracts
...endpoint specs...

### Backend Brief
...what backend must implement...

### Frontend Brief
...what frontend must consume...

### Shared Types
...TypeScript types...
[/TECH LEAD OUTPUT]`
}
```

- [ ] **Step 3: Port Backend prompt from `skills/backend/SKILL.md`**

```typescript
// server/src/prompts/backend.ts
import type { PromptContext } from './pm.js'

export function buildBackendPrompt(ctx: PromptContext): string {
  return `You are the Backend agent in the Nob pipeline.

## Your task
Implement the backend changes described in the Tech Lead brief.

## Tech Lead Output
${ctx.previousPhaseResults}

## Codebase context
${ctx.codembaseContext}

${ctx.diagnostic ? `## Reviewer Diagnostic (from failed review)\n${ctx.diagnostic}\n` : ''}

## Instructions
1. Implement ONLY what is in the Backend Brief. Do not touch frontend files.
2. Write or update all relevant backend files.
3. Run existing tests and fix any failures.
4. Output a summary of every file changed and why.

## Output format
End with:
[BACKEND OUTPUT]
### Files changed
- path/to/file.ts — reason
### Summary
...what was implemented...
[/BACKEND OUTPUT]`
}
```

- [ ] **Step 4: Port Frontend prompt from `skills/frontend/SKILL.md`**

```typescript
// server/src/prompts/frontend.ts
import type { PromptContext } from './pm.js'

export function buildFrontendPrompt(ctx: PromptContext): string {
  return `You are the Frontend agent in the Nob pipeline.

## Your task
Implement the frontend changes described in the Tech Lead brief.

## Tech Lead Output
${ctx.previousPhaseResults}

## Codebase context
${ctx.codembaseContext}

${ctx.diagnostic ? `## Reviewer Diagnostic (from failed review)\n${ctx.diagnostic}\n` : ''}

## Instructions
1. Implement ONLY what is in the Frontend Brief. Do not touch backend files.
2. Consume the API contracts exactly as specified — do not deviate from the specified endpoints or types.
3. Write or update all relevant frontend files.
4. Output a summary of every file changed and why.

## Output format
End with:
[FRONTEND OUTPUT]
### Files changed
- path/to/file.tsx — reason
### Summary
...what was implemented...
[/FRONTEND OUTPUT]`
}
```

- [ ] **Step 5: Port Reviewer prompt from `skills/reviewer/SKILL.md`**

```typescript
// server/src/prompts/reviewer.ts
import type { PromptContext } from './pm.js'

export function buildReviewerPrompt(ctx: PromptContext): string {
  return `You are the Reviewer agent in the Nob pipeline.

## Your task
Review the implementation against the acceptance criteria. Run a security scan. Return a structured verdict.

## Acceptance Criteria
${ctx.acceptanceCriteria.map((c, i) => `${i + 1}. ${c}`).join('\n')}

## Backend Output
${ctx.previousPhaseResults?.split('[FRONTEND OUTPUT]')[0] ?? ''}

## Frontend Output
${ctx.previousPhaseResults?.split('[FRONTEND OUTPUT]')[1] ?? ''}

## Codebase context
${ctx.codembaseContext}

## Instructions
1. Check each acceptance criterion: PASS or FAIL with reason.
2. Security scan: check for SQL injection, XSS, missing auth, exposed secrets, insecure direct object references.
3. Check API contract compliance: does frontend consume the exact endpoints the backend exposes?
4. Assign a verdict:
   - PASS: all criteria met, no security issues
   - NEEDS REVIEW: minor issues only, no blockers
   - FAIL: one or more criteria unmet or security issue found

## Output format
[REVIEWER OUTPUT]
### Acceptance Criteria Check
1. [criterion] — PASS/FAIL: reason

### Security Scan
- [issue or "No issues found"]

### Contract Compliance
- [compliant or list violations]

### Verdict
**VERDICT: PASS | NEEDS REVIEW | FAIL**

### Failure Details (if FAIL)
- [itemized list of what must be fixed]
[/REVIEWER OUTPUT]`
}
```

- [ ] **Step 6: Commit**

```bash
git add server/src/prompts/
git commit -m "feat: add pipeline prompt templates (PM, TechLead, Backend, Frontend, Reviewer)"
```

---

## Task 6: Prompt Builder

**Files:**
- Create: `server/src/pipeline/promptBuilder.ts`

No separate test needed — the prompt builder is pure composition of already-tested pieces. It will be covered by the tool-level integration tests.

- [ ] **Step 1: Write `server/src/pipeline/promptBuilder.ts`**

```typescript
import type { Run, PhaseRecord } from '@nob/shared'
import { buildPmPrompt } from '../prompts/pm.js'
import { buildTechLeadPrompt } from '../prompts/techLead.js'
import { buildBackendPrompt } from '../prompts/backend.js'
import { buildFrontendPrompt } from '../prompts/frontend.js'
import { buildReviewerPrompt } from '../prompts/reviewer.js'
import type { PromptContext } from '../prompts/pm.js'

export function buildPrompt(
  phase: 'pm' | 'tech_lead' | 'backend' | 'frontend' | 'reviewer',
  run: Run,
  previousPhases: PhaseRecord[],
  diagnostic?: string,
): string {
  const lastResult = previousPhases
    .filter(p => p.result)
    .map(p => p.result)
    .join('\n\n')

  const ctx: PromptContext = {
    specContent:           run.specContent,
    codembaseContext:      '',   // injected from run metadata — added in Task 8
    previousPhaseResults:  lastResult,
    acceptanceCriteria:    run.acceptanceCriteria,
    diagnostic,
  }

  switch (phase) {
    case 'pm':        return buildPmPrompt(ctx)
    case 'tech_lead': return buildTechLeadPrompt(ctx)
    case 'backend':   return buildBackendPrompt(ctx)
    case 'frontend':  return buildFrontendPrompt(ctx)
    case 'reviewer':  return buildReviewerPrompt(ctx)
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add server/src/pipeline/promptBuilder.ts
git commit -m "feat: add prompt builder — assembles phase prompts from templates + run context"
```

---

## Task 7: Pipeline State Machine

**Files:**
- Create: `server/src/pipeline/stateMachine.ts`
- Create: `server/test/pipeline/stateMachine.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/pipeline/stateMachine.test.ts
import { describe, it, expect } from 'vitest'
import { nextPhase, PHASE_ORDER } from '../../src/pipeline/stateMachine.js'

describe('nextPhase', () => {
  it('pm → tech_lead', () => {
    expect(nextPhase('pm')).toBe('tech_lead')
  })

  it('tech_lead → dev', () => {
    expect(nextPhase('tech_lead')).toBe('dev')
  })

  it('dev → reviewer', () => {
    expect(nextPhase('dev')).toBe('reviewer')
  })

  it('reviewer → done', () => {
    expect(nextPhase('reviewer')).toBe('done')
  })

  it('done → throws', () => {
    expect(() => nextPhase('done')).toThrow('invalid_phase_transition')
  })

  it('failed → throws', () => {
    expect(() => nextPhase('failed')).toThrow('invalid_phase_transition')
  })
})

describe('PHASE_ORDER', () => {
  it('has correct sequence', () => {
    expect(PHASE_ORDER).toEqual(['pm', 'tech_lead', 'dev', 'reviewer'])
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/pipeline/stateMachine.test.ts
```

Expected: FAIL — "Cannot find module stateMachine"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/pipeline/stateMachine.ts
import type { RunPhase } from '@nob/shared'

export const PHASE_ORDER: RunPhase[] = ['pm', 'tech_lead', 'dev', 'reviewer']

export function nextPhase(current: RunPhase): RunPhase {
  const idx = PHASE_ORDER.indexOf(current)
  if (idx === -1 || idx === PHASE_ORDER.length - 1) {
    throw new Error('invalid_phase_transition')
  }
  return PHASE_ORDER[idx + 1]
}

export function isTerminal(phase: RunPhase): boolean {
  return phase === 'done' || phase === 'failed'
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/pipeline/stateMachine.test.ts
```

Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/pipeline/stateMachine.ts server/test/pipeline/stateMachine.test.ts
git commit -m "feat: add pipeline state machine"
```

---

## Task 8: API Key Auth

**Files:**
- Create: `server/src/auth/apiKey.ts`
- Create: `server/test/auth/apiKey.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/auth/apiKey.test.ts
import { describe, it, expect } from 'vitest'
import { generateApiKey, hashApiKey, verifyApiKey } from '../../src/auth/apiKey.js'

describe('generateApiKey', () => {
  it('returns a nob_ prefixed key', () => {
    const key = generateApiKey()
    expect(key.startsWith('nob_')).toBe(true)
    expect(key.length).toBeGreaterThan(20)
  })

  it('returns unique keys on each call', () => {
    expect(generateApiKey()).not.toBe(generateApiKey())
  })
})

describe('hashApiKey + verifyApiKey', () => {
  it('verifies a valid key against its hash', async () => {
    const key = generateApiKey()
    const hash = await hashApiKey(key)
    expect(await verifyApiKey(key, hash)).toBe(true)
  })

  it('rejects wrong key against a hash', async () => {
    const key = generateApiKey()
    const hash = await hashApiKey(key)
    expect(await verifyApiKey('nob_wrongkey', hash)).toBe(false)
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/auth/apiKey.test.ts
```

Expected: FAIL — "Cannot find module apiKey"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/auth/apiKey.ts
import bcrypt from 'bcryptjs'
import { randomBytes } from 'crypto'

export function generateApiKey(): string {
  return `nob_${randomBytes(24).toString('base64url')}`
}

export async function hashApiKey(key: string): Promise<string> {
  return bcrypt.hash(key, 10)
}

export async function verifyApiKey(key: string, hash: string): Promise<boolean> {
  return bcrypt.compare(key, hash)
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/auth/apiKey.test.ts
```

Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/auth/apiKey.ts server/test/auth/apiKey.test.ts
git commit -m "feat: add API key generation and bcrypt hashing"
```

---

## Task 9: Plan Limits + Billing Check

**Files:**
- Create: `server/src/billing/plans.ts`
- Create: `server/test/billing/plans.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/billing/plans.test.ts
import { describe, it, expect } from 'vitest'
import { getMaxRetries, isOverRunLimit } from '../../src/billing/plans.js'

describe('getMaxRetries', () => {
  it('free plan has 0 retries', () => {
    expect(getMaxRetries('free')).toBe(0)
  })
  it('solo plan has 3 retries', () => {
    expect(getMaxRetries('solo')).toBe(3)
  })
  it('team plan has 5 retries', () => {
    expect(getMaxRetries('team')).toBe(5)
  })
})

describe('isOverRunLimit', () => {
  it('returns true when runsThisMonth >= plan limit', () => {
    expect(isOverRunLimit('free', 5)).toBe(true)
    expect(isOverRunLimit('free', 6)).toBe(true)
  })
  it('returns false when under limit', () => {
    expect(isOverRunLimit('free', 4)).toBe(false)
    expect(isOverRunLimit('solo', 49)).toBe(false)
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/billing/plans.test.ts
```

Expected: FAIL — "Cannot find module plans"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/billing/plans.ts
import { PLAN_LIMITS } from '@nob/shared'
import type { Plan } from '@nob/shared'
import { db } from '../db/client.js'
import { billingEvents } from '../db/schema.js'
import { eq, and, gte, count } from 'drizzle-orm'

export function getMaxRetries(plan: Plan): number {
  return PLAN_LIMITS[plan].maxRetries
}

export function isOverRunLimit(plan: Plan, runsThisMonth: number): boolean {
  return runsThisMonth >= PLAN_LIMITS[plan].runsPerMonth
}

export async function countRunsThisMonth(userId: string): Promise<number> {
  const startOfMonth = new Date()
  startOfMonth.setDate(1)
  startOfMonth.setHours(0, 0, 0, 0)

  const result = await db
    .select({ value: count() })
    .from(billingEvents)
    .where(
      and(
        eq(billingEvents.userId, userId),
        eq(billingEvents.event, 'run_started'),
        gte(billingEvents.createdAt, startOfMonth)
      )
    )
  return result[0]?.value ?? 0
}

export async function recordBillingEvent(
  userId: string,
  event: string,
  runId?: string
): Promise<void> {
  await db.insert(billingEvents).values({ userId, event, runId })
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/billing/plans.test.ts
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/billing/plans.ts server/test/billing/plans.test.ts
git commit -m "feat: add plan limits and billing event helpers"
```

---

## Task 10: `nob_start` Tool

**Files:**
- Create: `server/src/tools/nobStart.ts`
- Create: `server/test/tools/nobStart.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/tools/nobStart.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock db and billing before importing the tool
vi.mock('../../src/db/client.js', () => ({
  db: {
    select: vi.fn().mockReturnThis(),
    from:   vi.fn().mockReturnThis(),
    where:  vi.fn().mockResolvedValue([{ userId: 'user-1', plan: 'solo', keyHash: 'hash' }]),
    insert: vi.fn().mockReturnThis(),
    values: vi.fn().mockResolvedValue([{ id: 'run-1' }]),
  },
}))
vi.mock('../../src/billing/plans.js', () => ({
  countRunsThisMonth: vi.fn().mockResolvedValue(0),
  isOverRunLimit:     vi.fn().mockReturnValue(false),
  recordBillingEvent: vi.fn().mockResolvedValue(undefined),
  getMaxRetries:      vi.fn().mockReturnValue(3),
}))
vi.mock('../../src/auth/apiKey.js', () => ({
  verifyApiKey: vi.fn().mockResolvedValue(true),
}))

import { handleNobStart } from '../../src/tools/nobStart.js'

describe('handleNobStart', () => {
  it('returns error when spec has no acceptance criteria', async () => {
    const result = await handleNobStart(
      { spec_content: '# Feature\n\nNo criteria here.', codebase_context: '{}' },
      'user-1',
      'solo'
    )
    expect(result.error).toBe('missing_acceptance_criteria')
  })

  it('returns run_id and pm prompt on valid spec', async () => {
    const spec = '# Feature\n\n## Acceptance criteria\n\n- [ ] Users can login'
    const result = await handleNobStart(
      { spec_content: spec, codebase_context: '{}' },
      'user-1',
      'solo'
    )
    expect(result.run_id).toBeDefined()
    expect(result.phase).toBe('pm')
    expect(result.prompt).toContain('Product Manager')
    expect(result.acceptance_criteria).toEqual(['Users can login'])
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/tools/nobStart.test.ts
```

Expected: FAIL — "Cannot find module nobStart"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/tools/nobStart.ts
import { randomUUID } from 'crypto'
import type { Plan, NobStartInput, NobStartOutput } from '@nob/shared'
import { db } from '../db/client.js'
import { runs, phases } from '../db/schema.js'
import { validateSpec } from '../pipeline/specValidator.js'
import { buildPrompt } from '../pipeline/promptBuilder.js'
import { countRunsThisMonth, isOverRunLimit, recordBillingEvent } from '../billing/plans.js'

export async function handleNobStart(
  input: NobStartInput,
  userId: string,
  plan: Plan,
): Promise<NobStartOutput & { error?: string }> {
  const { valid, acceptanceCriteria } = validateSpec(input.spec_content)
  if (!valid) return { error: 'missing_acceptance_criteria' } as any

  const runsThisMonth = await countRunsThisMonth(userId)
  if (isOverRunLimit(plan, runsThisMonth)) {
    return { error: 'run_limit_reached', upgrade_url: 'https://nob.run/upgrade' } as any
  }

  const specTitle = input.spec_content.match(/^#\s+(.+)/m)?.[1] ?? 'Untitled'

  const [run] = await db.insert(runs).values({
    id:                 randomUUID(),
    userId,
    specTitle,
    specContent:        input.spec_content,
    acceptanceCriteria,
    currentPhase:       'pm',
  }).returning()

  const prompt = buildPrompt('pm', {
    id:                 run.id,
    userId:             run.userId,
    specTitle:          run.specTitle,
    specContent:        run.specContent,
    acceptanceCriteria: run.acceptanceCriteria,
    currentPhase:       'pm',
    verdict:            null,
    retryCount:         0,
    createdAt:          run.createdAt,
    updatedAt:          run.updatedAt,
  }, [])

  await db.insert(phases).values({
    id:         randomUUID(),
    runId:      run.id,
    phase:      'pm',
    promptSent: prompt,
  })

  await recordBillingEvent(userId, 'run_started', run.id)

  return {
    run_id:               run.id,
    phase:                'pm',
    prompt,
    acceptance_criteria:  acceptanceCriteria,
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/tools/nobStart.test.ts
```

Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/tools/nobStart.ts server/test/tools/nobStart.test.ts
git commit -m "feat: implement nob_start tool handler"
```

---

## Task 11: `nob_advance` Tool

**Files:**
- Create: `server/src/tools/nobAdvance.ts`
- Create: `server/test/tools/nobAdvance.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// server/test/tools/nobAdvance.test.ts
import { describe, it, expect, vi } from 'vitest'
import type { Run } from '@nob/shared'

const mockRun: Run = {
  id:                 'run-1',
  userId:             'user-1',
  specTitle:          'Test Feature',
  specContent:        '# Test\n\n## Acceptance criteria\n\n- [ ] Works',
  acceptanceCriteria: ['Works'],
  currentPhase:       'pm',
  verdict:            null,
  retryCount:         0,
  createdAt:          new Date(),
  updatedAt:          new Date(),
}

vi.mock('../../src/db/client.js', () => ({
  db: {
    query: {
      runs: {
        findFirst: vi.fn().mockResolvedValue(mockRun),
      },
    },
    update:  vi.fn().mockReturnThis(),
    set:     vi.fn().mockReturnThis(),
    where:   vi.fn().mockResolvedValue(undefined),
    insert:  vi.fn().mockReturnThis(),
    values:  vi.fn().mockResolvedValue(undefined),
    select:  vi.fn().mockReturnThis(),
    from:    vi.fn().mockReturnThis(),
    orderBy: vi.fn().mockResolvedValue([]),
  },
}))

import { handleNobAdvance } from '../../src/tools/nobAdvance.js'

describe('handleNobAdvance', () => {
  it('returns error when phase_result is too short', async () => {
    const result = await handleNobAdvance({ run_id: 'run-1', phase_result: 'ok' }, 'user-1', 'solo')
    expect(result.error).toBe('empty_result')
  })

  it('advances phase from pm to tech_lead', async () => {
    const result = await handleNobAdvance(
      { run_id: 'run-1', phase_result: 'A'.repeat(60) },
      'user-1',
      'solo',
    )
    expect(result.phase).toBe('tech_lead')
    expect(result.prompt).toBeTruthy()
  })

  it('returns error for unknown run', async () => {
    vi.mocked((await import('../../src/db/client.js')).db.query.runs.findFirst)
      .mockResolvedValueOnce(undefined)
    const result = await handleNobAdvance(
      { run_id: 'nonexistent', phase_result: 'A'.repeat(60) },
      'user-1',
      'solo',
    )
    expect(result.error).toBe('run_not_found')
  })
})
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test test/tools/nobAdvance.test.ts
```

Expected: FAIL — "Cannot find module nobAdvance"

- [ ] **Step 3: Write the implementation**

```typescript
// server/src/tools/nobAdvance.ts
import { randomUUID } from 'crypto'
import type { Plan, NobAdvanceInput, NobAdvanceOutput, Run } from '@nob/shared'
import { db } from '../db/client.js'
import { runs, phases } from '../db/schema.js'
import { eq, asc } from 'drizzle-orm'
import { nextPhase, isTerminal } from '../pipeline/stateMachine.js'
import { buildPrompt } from '../pipeline/promptBuilder.js'
import { parseVerdict } from '../pipeline/verdictParser.js'
import { getMaxRetries, recordBillingEvent } from '../billing/plans.js'

export async function handleNobAdvance(
  input: NobAdvanceInput,
  userId: string,
  plan: Plan,
): Promise<NobAdvanceOutput & { error?: string }> {
  if (!input.phase_result || input.phase_result.trim().length < 50) {
    return { error: 'empty_result' } as any
  }

  const run = await db.query.runs.findFirst({ where: eq(runs.id, input.run_id) })
  if (!run || run.userId !== userId) return { error: 'run_not_found' } as any
  if (isTerminal(run.currentPhase)) return { error: 'invalid_phase_transition' } as any

  // Save result for current phase
  await db.update(phases)
    .set({ result: input.phase_result, completedAt: new Date() })
    .where(eq(phases.runId, run.id))

  const previousPhases = await db.select().from(phases)
    .where(eq(phases.runId, run.id))
    .orderBy(asc(phases.completedAt))

  // Handle reviewer verdict
  if (run.currentPhase === 'reviewer') {
    const verdict = parseVerdict(input.phase_result)
    const maxRetries = getMaxRetries(plan)

    if (verdict === 'FAIL' && run.retryCount < maxRetries) {
      const diagnostic = extractFailureDetails(input.phase_result)
      await db.update(runs).set({ retryCount: run.retryCount + 1 }).where(eq(runs.id, run.id))

      const runForPrompt: Run = { ...run, retryCount: run.retryCount + 1 }
      return {
        phase: 'dev',
        prompt: {
          backend:  buildPrompt('backend',  runForPrompt, previousPhases, diagnostic),
          frontend: buildPrompt('frontend', runForPrompt, previousPhases, diagnostic),
        },
        retry_count: run.retryCount + 1,
      }
    }

    await db.update(runs).set({
      currentPhase: verdict === 'FAIL' ? 'failed' : 'done',
      verdict,
      updatedAt: new Date(),
    }).where(eq(runs.id, run.id))

    await recordBillingEvent(userId, 'run_completed', run.id)
    return { phase: 'done', prompt: '', verdict }
  }

  const next = nextPhase(run.currentPhase)
  await db.update(runs).set({ currentPhase: next, updatedAt: new Date() }).where(eq(runs.id, run.id))

  const runForPrompt: Run = { ...run, currentPhase: next }

  if (next === 'dev') {
    const backendPrompt  = buildPrompt('backend',  runForPrompt, previousPhases)
    const frontendPrompt = buildPrompt('frontend', runForPrompt, previousPhases)
    await db.insert(phases).values([
      { id: randomUUID(), runId: run.id, phase: 'backend',  promptSent: backendPrompt },
      { id: randomUUID(), runId: run.id, phase: 'frontend', promptSent: frontendPrompt },
    ])
    return { phase: 'dev', prompt: { backend: backendPrompt, frontend: frontendPrompt } }
  }

  const nextPrompt = buildPrompt(next as any, runForPrompt, previousPhases)
  await db.insert(phases).values({ id: randomUUID(), runId: run.id, phase: next, promptSent: nextPrompt })
  return { phase: next, prompt: nextPrompt }
}

function extractFailureDetails(reviewerResult: string): string {
  const match = reviewerResult.match(/###\s+Failure Details[\s\S]*?(?=\n###|\s*$)/i)
  return match ? match[0] : reviewerResult.slice(-500)
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test test/tools/nobAdvance.test.ts
```

Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add server/src/tools/nobAdvance.ts server/test/tools/nobAdvance.test.ts
git commit -m "feat: implement nob_advance tool handler with retry loop"
```

---

## Task 12: `nob_status` + `nob_list_runs` Tools

**Files:**
- Create: `server/src/tools/nobStatus.ts`
- Create: `server/src/tools/nobListRuns.ts`

- [ ] **Step 1: Write `server/src/tools/nobStatus.ts`**

```typescript
import type { NobStatusOutput } from '@nob/shared'
import { db } from '../db/client.js'
import { runs, phases } from '../db/schema.js'
import { eq, asc } from 'drizzle-orm'

export async function handleNobStatus(
  runId: string,
  userId: string,
): Promise<NobStatusOutput & { error?: string }> {
  const run = await db.query.runs.findFirst({ where: eq(runs.id, runId) })
  if (!run || run.userId !== userId) return { error: 'run_not_found' } as any

  const completedPhases = await db.select()
    .from(phases)
    .where(eq(phases.runId, runId))
    .orderBy(asc(phases.completedAt))

  return {
    run_id:           run.id,
    phase:            run.currentPhase,
    verdict:          run.verdict,
    created_at:       run.createdAt.toISOString(),
    updated_at:       run.updatedAt.toISOString(),
    phases_completed: completedPhases
      .filter(p => p.completedAt)
      .map(p => p.phase),
  }
}
```

- [ ] **Step 2: Write `server/src/tools/nobListRuns.ts`**

```typescript
import type { NobListRunsOutput } from '@nob/shared'
import { db } from '../db/client.js'
import { runs } from '../db/schema.js'
import { eq, desc } from 'drizzle-orm'

export async function handleNobListRuns(
  userId: string,
  limit = 10,
): Promise<NobListRunsOutput> {
  const rows = await db.select()
    .from(runs)
    .where(eq(runs.userId, userId))
    .orderBy(desc(runs.createdAt))
    .limit(limit)

  return {
    runs: rows.map(r => ({
      run_id:     r.id,
      spec_title: r.specTitle,
      phase:      r.currentPhase,
      verdict:    r.verdict,
      created_at: r.createdAt.toISOString(),
    })),
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add server/src/tools/nobStatus.ts server/src/tools/nobListRuns.ts
git commit -m "feat: implement nob_status and nob_list_runs tool handlers"
```

---

## Task 13: Fastify Server + MCP Wiring

**Files:**
- Create: `server/src/index.ts`
- Create: `server/src/routes/api.ts`

- [ ] **Step 1: Write `server/src/index.ts`**

```typescript
import Fastify from 'fastify'
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js'
import { z } from 'zod'
import { db } from './db/client.js'
import { apiKeys, users } from './db/schema.js'
import { eq } from 'drizzle-orm'
import { verifyApiKey } from './auth/apiKey.js'
import { handleNobStart }    from './tools/nobStart.js'
import { handleNobAdvance }  from './tools/nobAdvance.js'
import { handleNobStatus }   from './tools/nobStatus.js'
import { handleNobListRuns } from './tools/nobListRuns.js'
import { apiRoutes } from './routes/api.js'

const app = Fastify({ logger: true })

// REST routes for dashboard
app.register(apiRoutes, { prefix: '/api' })

// MCP endpoint — one transport per request (stateless HTTP)
app.post('/mcp', async (req, reply) => {
  const authHeader = req.headers.authorization ?? ''
  const rawKey = authHeader.replace('Bearer ', '').trim()

  // Resolve user from API key
  const allKeys = await db.select().from(apiKeys)
  let userId: string | null = null
  let plan: string = 'free'

  for (const k of allKeys) {
    if (await verifyApiKey(rawKey, k.keyHash)) {
      userId = k.userId
      const user = await db.query.users.findFirst({ where: eq(users.id, k.userId) })
      plan = user?.plan ?? 'free'
      await db.update(apiKeys).set({ lastUsedAt: new Date() }).where(eq(apiKeys.id, k.id))
      break
    }
  }

  if (!userId) {
    return reply.status(401).send({ error: 'unauthorized' })
  }

  const server = new McpServer({ name: 'nob', version: '1.0.0' })

  server.tool('nob_start', {
    spec_content:      z.string(),
    codebase_context:  z.string(),
  }, async (input) => {
    const result = await handleNobStart(input as any, userId!, plan as any)
    return { content: [{ type: 'text', text: JSON.stringify(result) }] }
  })

  server.tool('nob_advance', {
    run_id:       z.string(),
    phase_result: z.string(),
  }, async (input) => {
    const result = await handleNobAdvance(input as any, userId!, plan as any)
    return { content: [{ type: 'text', text: JSON.stringify(result) }] }
  })

  server.tool('nob_status', {
    run_id: z.string(),
  }, async (input) => {
    const result = await handleNobStatus(input.run_id, userId!)
    return { content: [{ type: 'text', text: JSON.stringify(result) }] }
  })

  server.tool('nob_list_runs', {
    limit: z.number().optional(),
  }, async (input) => {
    const result = await handleNobListRuns(userId!, input.limit)
    return { content: [{ type: 'text', text: JSON.stringify(result) }] }
  })

  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  })

  await server.connect(transport)
  await transport.handleRequest(req.raw, reply.raw, req.body)
})

app.listen({ port: Number(process.env.PORT ?? 3001), host: '0.0.0.0' })
```

- [ ] **Step 2: Write `server/src/routes/api.ts`** (REST endpoints for dashboard)

```typescript
import type { FastifyPluginAsync } from 'fastify'
import { randomUUID } from 'crypto'
import { db } from '../db/client.js'
import { users, apiKeys, runs } from '../db/schema.js'
import { eq, desc } from 'drizzle-orm'
import { generateApiKey, hashApiKey } from '../auth/apiKey.js'

export const apiRoutes: FastifyPluginAsync = async (app) => {
  // Create API key
  app.post('/keys', async (req, reply) => {
    const { userId, label } = req.body as { userId: string; label: string }
    const rawKey = generateApiKey()
    const keyHash = await hashApiKey(rawKey)
    await db.insert(apiKeys).values({ id: randomUUID(), userId, keyHash, label })
    // Return raw key ONCE — never stored
    return { key: rawKey, label }
  })

  // List API keys (label + id only, no hash)
  app.get('/keys/:userId', async (req) => {
    const { userId } = req.params as { userId: string }
    const rows = await db.select({
      id: apiKeys.id, label: apiKeys.label, lastUsedAt: apiKeys.lastUsedAt, createdAt: apiKeys.createdAt,
    }).from(apiKeys).where(eq(apiKeys.userId, userId))
    return { keys: rows }
  })

  // Revoke API key
  app.delete('/keys/:keyId', async (req) => {
    const { keyId } = req.params as { keyId: string }
    await db.delete(apiKeys).where(eq(apiKeys.id, keyId))
    return { ok: true }
  })

  // List runs
  app.get('/runs/:userId', async (req) => {
    const { userId } = req.params as { userId: string }
    const rows = await db.select().from(runs)
      .where(eq(runs.userId, userId)).orderBy(desc(runs.createdAt)).limit(20)
    return { runs: rows }
  })

  // Get/create user by email
  app.post('/users', async (req) => {
    const { email } = req.body as { email: string }
    let user = await db.query.users.findFirst({ where: eq(users.email, email) })
    if (!user) {
      const [created] = await db.insert(users).values({
        id: randomUUID(), email, plan: 'free',
      }).returning()
      user = created
    }
    return { user }
  })
}
```

- [ ] **Step 3: Start the server and verify it responds**

```bash
cd server && pnpm dev
```

In another terminal:
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Authorization: Bearer invalid" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: `{"error":"unauthorized"}`

- [ ] **Step 4: Commit**

```bash
git add server/src/index.ts server/src/routes/api.ts
git commit -m "feat: wire Fastify server with MCP transport and REST API routes"
```

---

## Task 14: Stripe Webhook Handler

**Files:**
- Create: `server/src/billing/stripeWebhook.ts`
- Create: `server/src/routes/webhook.ts`

- [ ] **Step 1: Write `server/src/billing/stripeWebhook.ts`**

```typescript
import Stripe from 'stripe'
import { db } from '../db/client.js'
import { users } from '../db/schema.js'
import { eq } from 'drizzle-orm'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function handleStripeWebhook(
  payload: Buffer,
  signature: string,
): Promise<void> {
  const event = stripe.webhooks.constructEvent(
    payload,
    signature,
    process.env.STRIPE_WEBHOOK_SECRET!,
  )

  if (event.type === 'customer.subscription.updated' ||
      event.type === 'customer.subscription.created') {
    const sub = event.data.object as Stripe.Subscription
    const customerId = sub.customer as string
    const priceId = sub.items.data[0]?.price.id

    const plan = priceIdToPlan(priceId)
    if (plan) {
      await db.update(users)
        .set({ plan })
        .where(eq(users.stripeCustomerId, customerId))
    }
  }

  if (event.type === 'customer.subscription.deleted') {
    const sub = event.data.object as Stripe.Subscription
    await db.update(users)
      .set({ plan: 'free' })
      .where(eq(users.stripeCustomerId, sub.customer as string))
  }
}

function priceIdToPlan(priceId: string | undefined) {
  const map: Record<string, 'solo' | 'team'> = {
    [process.env.STRIPE_SOLO_PRICE_ID!]: 'solo',
    [process.env.STRIPE_TEAM_PRICE_ID!]: 'team',
  }
  return priceId ? map[priceId] : undefined
}
```

- [ ] **Step 2: Write `server/src/routes/webhook.ts`**

```typescript
import type { FastifyPluginAsync } from 'fastify'
import { handleStripeWebhook } from '../billing/stripeWebhook.js'

export const webhookRoutes: FastifyPluginAsync = async (app) => {
  app.post(
    '/webhook/stripe',
    { config: { rawBody: true } },
    async (req, reply) => {
      const sig = req.headers['stripe-signature'] as string
      try {
        await handleStripeWebhook(req.rawBody as Buffer, sig)
        return { ok: true }
      } catch (err) {
        return reply.status(400).send({ error: 'webhook_error' })
      }
    }
  )
}
```

- [ ] **Step 3: Register webhook route in `server/src/index.ts`**

Add this line after the `apiRoutes` registration:

```typescript
import { webhookRoutes } from './routes/webhook.js'
// ...
app.register(webhookRoutes)
```

- [ ] **Step 4: Add `.env.example` entries for Stripe price IDs**

```
STRIPE_SOLO_PRICE_ID=price_...
STRIPE_TEAM_PRICE_ID=price_...
```

- [ ] **Step 5: Commit**

```bash
git add server/src/billing/stripeWebhook.ts server/src/routes/webhook.ts server/src/index.ts server/.env.example
git commit -m "feat: add Stripe webhook handler for plan updates"
```

---

## Task 15: Dashboard Scaffold + Login

**Files:**
- Create: `dashboard/package.json`
- Create: `dashboard/app/page.tsx`
- Create: `dashboard/app/login/page.tsx`
- Create: `dashboard/app/api/auth/[...nextauth]/route.ts`

- [ ] **Step 1: Write `dashboard/package.json`**

```json
{
  "name": "@nob/dashboard",
  "version": "0.0.1",
  "scripts": {
    "dev":   "next dev -p 3000",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@nob/shared":     "workspace:*",
    "next":            "14.2.0",
    "next-auth":       "^4.24.0",
    "react":           "^18.3.0",
    "react-dom":       "^18.3.0",
    "resend":          "^3.0.0",
    "stripe":          "^14.0.0"
  },
  "devDependencies": {
    "@types/node":     "^20.0.0",
    "@types/react":    "^18.3.0",
    "tailwindcss":     "^3.4.0",
    "typescript":      "^5.4.0"
  }
}
```

- [ ] **Step 2: Write `dashboard/app/page.tsx`**

```tsx
import { redirect } from 'next/navigation'
import { getServerSession } from 'next-auth'
import { authOptions } from './api/auth/[...nextauth]/route'

export default async function HomePage() {
  const session = await getServerSession(authOptions)
  if (session) redirect('/dashboard/keys')
  redirect('/login')
}
```

- [ ] **Step 3: Write `dashboard/app/api/auth/[...nextauth]/route.ts`**

```typescript
import NextAuth, { type NextAuthOptions } from 'next-auth'
import EmailProvider from 'next-auth/providers/email'
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export const authOptions: NextAuthOptions = {
  providers: [
    EmailProvider({
      from: 'nob@nob.run',
      sendVerificationRequest: async ({ identifier: email, url }) => {
        await resend.emails.send({
          from:    'nob@nob.run',
          to:      email,
          subject: 'Sign in to Nob',
          html:    `<p>Click <a href="${url}">here</a> to sign in.</p>`,
        })
      },
    }),
  ],
  callbacks: {
    async session({ session, token }) {
      if (token.sub) session.user.id = token.sub
      return session
    },
  },
  pages: { signIn: '/login' },
  secret: process.env.NEXTAUTH_SECRET,
}

const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }
```

- [ ] **Step 4: Write `dashboard/app/login/page.tsx`**

```tsx
'use client'
import { signIn } from 'next-auth/react'
import { useState } from 'react'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [sent, setSent]   = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    await signIn('email', { email, redirect: false })
    setSent(true)
  }

  if (sent) return (
    <div className="min-h-screen flex items-center justify-center">
      <p className="text-lg">Check your email for a sign-in link.</p>
    </div>
  )

  return (
    <div className="min-h-screen flex items-center justify-center">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-80">
        <h1 className="text-2xl font-bold">Sign in to Nob</h1>
        <input
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={e => setEmail(e.target.value)}
          className="border rounded px-3 py-2"
          required
        />
        <button type="submit" className="bg-black text-white rounded px-4 py-2">
          Send magic link
        </button>
      </form>
    </div>
  )
}
```

- [ ] **Step 5: Install dashboard dependencies**

```bash
cd dashboard && pnpm install
```

- [ ] **Step 6: Start dashboard and confirm login page renders**

```bash
pnpm dev
```

Open `http://localhost:3000` — should redirect to `/login` and show the magic link form.

- [ ] **Step 7: Commit**

```bash
git add dashboard/
git commit -m "feat: scaffold dashboard with Next.js and magic link login"
```

---

## Task 16: Dashboard — API Keys + Runs + Billing Pages

**Files:**
- Create: `dashboard/app/dashboard/layout.tsx`
- Create: `dashboard/app/dashboard/keys/page.tsx`
- Create: `dashboard/app/dashboard/runs/page.tsx`
- Create: `dashboard/app/dashboard/billing/page.tsx`
- Create: `dashboard/app/api/billing/checkout/route.ts`

- [ ] **Step 1: Write the auth-guard layout**

```tsx
// dashboard/app/dashboard/layout.tsx
import { getServerSession } from 'next-auth'
import { redirect } from 'next/navigation'
import { authOptions } from '../api/auth/[...nextauth]/route'

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions)
  if (!session) redirect('/login')
  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="border-b bg-white px-6 py-3 flex gap-6">
        <a href="/dashboard/keys"    className="font-medium">API Keys</a>
        <a href="/dashboard/runs"    className="font-medium">Runs</a>
        <a href="/dashboard/billing" className="font-medium">Billing</a>
      </nav>
      <main className="max-w-3xl mx-auto py-8 px-4">{children}</main>
    </div>
  )
}
```

- [ ] **Step 2: Write the API Keys page**

```tsx
// dashboard/app/dashboard/keys/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '../../api/auth/[...nextauth]/route'

async function getKeys(userId: string) {
  const res = await fetch(`${process.env.SERVER_URL}/api/keys/${userId}`, { cache: 'no-store' })
  return res.json()
}

export default async function KeysPage() {
  const session = await getServerSession(authOptions)
  const { keys } = await getKeys(session!.user!.id!)

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-xl font-bold">API Keys</h1>
        <form action="/api/keys" method="POST">
          <input type="hidden" name="userId" value={session!.user!.id!} />
          <input name="label" placeholder="Label (e.g. My Mac)" className="border rounded px-2 py-1 mr-2" required />
          <button type="submit" className="bg-black text-white rounded px-3 py-1">Create key</button>
        </form>
      </div>
      <table className="w-full text-sm border">
        <thead><tr className="bg-gray-100"><th className="p-2 text-left">Label</th><th className="p-2 text-left">Last used</th><th /></tr></thead>
        <tbody>
          {keys.map((k: any) => (
            <tr key={k.id} className="border-t">
              <td className="p-2">{k.label}</td>
              <td className="p-2 text-gray-500">{k.lastUsedAt ? new Date(k.lastUsedAt).toLocaleDateString() : 'Never'}</td>
              <td className="p-2">
                <form action={`/api/keys/${k.id}`} method="DELETE">
                  <button className="text-red-500 text-xs">Revoke</button>
                </form>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 3: Write the Runs page**

```tsx
// dashboard/app/dashboard/runs/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '../../api/auth/[...nextauth]/route'

async function getRuns(userId: string) {
  const res = await fetch(`${process.env.SERVER_URL}/api/runs/${userId}`, { cache: 'no-store' })
  return res.json()
}

const verdictColor: Record<string, string> = {
  PASS:         'text-green-600',
  NEEDS_REVIEW: 'text-yellow-600',
  FAIL:         'text-red-600',
}

export default async function RunsPage() {
  const session = await getServerSession(authOptions)
  const { runs } = await getRuns(session!.user!.id!)

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold">Recent Runs</h1>
      {runs.length === 0 && <p className="text-gray-500">No runs yet. Use <code>/nob</code> in Claude Code to start one.</p>}
      <div className="flex flex-col gap-2">
        {runs.map((r: any) => (
          <div key={r.id} className="border rounded p-4 bg-white flex justify-between items-center">
            <div>
              <p className="font-medium">{r.specTitle}</p>
              <p className="text-xs text-gray-500">{new Date(r.createdAt).toLocaleString()}</p>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-xs bg-gray-100 rounded px-2 py-1">{r.currentPhase}</span>
              {r.verdict && <span className={`text-sm font-bold ${verdictColor[r.verdict] ?? ''}`}>{r.verdict}</span>}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Write the Billing page + Stripe Checkout route**

```tsx
// dashboard/app/dashboard/billing/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '../../api/auth/[...nextauth]/route'
import { PLAN_LIMITS } from '@nob/shared'

export default async function BillingPage() {
  const session = await getServerSession(authOptions)
  const plan = (session as any)?.user?.plan ?? 'free'
  const limits = PLAN_LIMITS[plan as 'free' | 'solo' | 'team']

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-xl font-bold">Billing</h1>
      <div className="border rounded p-4 bg-white">
        <p className="font-medium capitalize">Current plan: {plan}</p>
        <p className="text-sm text-gray-500">{limits.runsPerMonth} runs/month · {limits.maxRetries} retries · {limits.parallelDev ? 'Parallel dev' : 'Sequential dev'}</p>
      </div>
      {plan === 'free' && (
        <div className="flex gap-4">
          <form action="/api/billing/checkout" method="POST">
            <input type="hidden" name="plan" value="solo" />
            <button className="bg-black text-white rounded px-4 py-2">Upgrade to Solo — $29/mo</button>
          </form>
          <form action="/api/billing/checkout" method="POST">
            <input type="hidden" name="plan" value="team" />
            <button className="border rounded px-4 py-2">Upgrade to Team — $99/mo</button>
          </form>
        </div>
      )}
      {plan !== 'free' && (
        <p className="text-sm text-gray-500">To manage your subscription, visit the Stripe customer portal.</p>
      )}
    </div>
  )
}
```

```typescript
// dashboard/app/api/billing/checkout/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { getServerSession } from 'next-auth'
import { authOptions } from '../../auth/[...nextauth]/route'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

const PRICE_IDS: Record<string, string> = {
  solo: process.env.STRIPE_SOLO_PRICE_ID!,
  team: process.env.STRIPE_TEAM_PRICE_ID!,
}

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session?.user?.email) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })

  const { plan } = await req.json()
  const priceId = PRICE_IDS[plan]
  if (!priceId) return NextResponse.json({ error: 'invalid_plan' }, { status: 400 })

  const checkout = await stripe.checkout.sessions.create({
    mode:                'subscription',
    customer_email:      session.user.email,
    line_items:          [{ price: priceId, quantity: 1 }],
    success_url:         `${process.env.NEXTAUTH_URL}/dashboard/billing?success=1`,
    cancel_url:          `${process.env.NEXTAUTH_URL}/dashboard/billing`,
  })

  return NextResponse.redirect(checkout.url!)
}
```

- [ ] **Step 5: Verify dashboard pages render**

```bash
pnpm dev
```

Visit `http://localhost:3000/dashboard/keys` — should show keys page (may redirect to login first).

- [ ] **Step 6: Commit**

```bash
git add dashboard/app/dashboard/ dashboard/app/api/billing/
git commit -m "feat: add dashboard pages — API keys, runs, billing with Stripe Checkout"
```

---

## Task 17: Deployment Config

**Files:**
- Create: `server/railway.json`
- Create: `dashboard/vercel.json`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write `server/railway.json`**

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build":  { "builder": "NIXPACKS" },
  "deploy": {
    "startCommand":  "pnpm start",
    "healthcheckPath": "/health",
    "restartPolicyType": "ON_FAILURE"
  }
}
```

- [ ] **Step 2: Add health endpoint to `server/src/index.ts`**

```typescript
app.get('/health', async () => ({ ok: true }))
```

- [ ] **Step 3: Write `dashboard/vercel.json`**

```json
{
  "framework": "nextjs",
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install"
}
```

- [ ] **Step 4: Write `.github/workflows/ci.yml`**

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: nob
          POSTGRES_USER: nob
          POSTGRES_PASSWORD: nob
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'pnpm' }
      - run: pnpm install
      - run: pnpm --filter server test
        env:
          DATABASE_URL: postgres://nob:nob@localhost:5432/nob
```

- [ ] **Step 5: Run full test suite locally**

```bash
cd nob-mcp && pnpm test
```

Expected: all tests pass.

- [ ] **Step 6: Final commit**

```bash
git add server/railway.json dashboard/vercel.json .github/ server/src/index.ts
git commit -m "chore: add Railway, Vercel, and GitHub Actions CI config"
```

---

## Self-Review

**Spec coverage check:**
- [x] `nob_start` rejects missing acceptance criteria — Task 3 + Task 10
- [x] Run limits enforced before `nob_start` creates run — Task 9 + Task 10
- [x] Phase ordering enforced in `nob_advance` — Task 11
- [x] `nob_advance` rejects results < 50 chars — Task 11
- [x] FAIL triggers retry with diagnostic injection — Task 11
- [x] FAIL at MAX_RETRIES → `failed` state — Task 11
- [x] API keys bcrypt-hashed, never stored plaintext — Task 8
- [x] API key shown once at creation — Task 13 (REST route returns raw key once)
- [x] Dashboard: create/revoke keys, view runs, upgrade plan — Tasks 15–16
- [x] Stripe webhooks update `users.plan` — Task 14
- [x] `nob_status` enables resume — Task 12
- [x] All four MCP tools work — Tasks 10–13

No gaps found.

---

Plan complete and saved to `docs/superpowers/plans/2026-06-04-nob-mcp-commercial.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast parallel iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
