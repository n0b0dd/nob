# Adaptive Coordinator with Shared Exploration

**Date:** 2026-06-02
**Status:** Draft

## Problem

The current Backend and Frontend agents handle everything in a single in-session pass: explore the codebase, plan, implement, and test. This works for small specs but breaks down at scale:

- A single context window cannot hold a large codebase and all implementation work simultaneously
- Complex specs touching 5+ files cause agents to miss changes or implement in the wrong order
- Every agent re-reads the codebase independently, paying the exploration cost multiple times

## Goal

Make Backend and Frontend agents scale to large codebases and complex specs while keeping token cost proportional to actual work. Simple specs must remain as cheap as today.

## Non-Goals

- Changing the Hub, PM Agent, Reviewer, checkpoint system, or fan-out slice behavior
- Parallelizing tasks within a layer (dependencies between schema → service → routes → tests make this unsafe)
- Adding a new top-level orchestration agent above the Hub

## Architecture

### Overview

```
Hub → Planner (adds complexity score per layer)
    → PM Agent
    → Backend Coordinator           Frontend Coordinator
        ↓ (if complex)                  ↓ (if complex)
        Exploration Agent               Exploration Agent
        (one read pass → compact        (one read pass → compact
         CONTEXT block)                  CONTEXT block)
        ↓                               ↓
        schema agent                    types agent
        ↓                               ↓
        service agent                   api-service agent
        ↓                               ↓
        routes agent                    component agent
        ↓                               ↓
        tests agent                     tests agent
    → Reviewer
```

The simple path is unchanged: Backend/Frontend implement in-session exactly as today.

---

## Component Design

### 1. Planner — Complexity Scoring

The Planner gains one new responsibility: output a `Complexity:` score per layer alongside the existing `[PLAN OUTPUT]` block.

**Criteria for `complex`:**
- 3 or more files affected in that layer, OR
- Any `[MIGRATION]`, `[AUTH]`, `[BREAKING]`, or `[SHARED]` risk applies to that layer, OR
- The spec touches multiple independent concerns within the same layer (e.g. both user model and order model on the backend)

**Criteria for `simple`:**
- 1–2 files affected, no risk flags, single concern

**New fields in `[PLAN OUTPUT]`:**

```
Complexity:
  Backend: simple | complex
  Frontend: simple | complex
```

Model: Haiku (unchanged). The complexity decision adds negligible cost.

---

### 2. Exploration Agent

Dispatched once per layer when that layer is `complex`. Runs as a Haiku sub-agent. Reads the codebase and emits a compact summary — never implements anything.

**Reads:**
- Every file listed in `Affected files` from PLAN OUTPUT for this layer
- One existing pattern file per concern (one route file, one service file, one test file — representative examples only)
- Auth middleware if `[AUTH]` risk present
- Schema/migration files if `[MIGRATION]` risk present

**Emits a summary, not raw file dumps.** The output should capture:
- File paths and their roles
- Existing patterns (route structure, error format, test style, naming conventions)
- Relevant short snippets only (function signatures, type shapes — not full file contents)
- Auth wiring if relevant
- Schema shape if relevant

**Target output size:** under 2,000 tokens.

**Output block:**

```
[BACKEND-EXPLORATION CONTEXT]   (or [FRONTEND-EXPLORATION CONTEXT])
Affected files:
  - path/to/file.ts: [role]

Patterns observed:
  Route structure: [description]
  Error format: [example]
  Test style: [description]
  Auth wiring: [how middleware is applied, or: none]
  Schema shape: [relevant fields, or: none]

Relevant snippets:
  [short representative excerpts only]
[/BACKEND-EXPLORATION CONTEXT]
```

---

### 3. Coordinator — Task Breakdown

After the Exploration Agent returns, the coordinator decides the task list in-session (no sub-agent dispatch for this step — zero cost).

Tasks are only created for what the spec actually requires. Natural order:

**Backend task order:**
1. schema/migration — if `[MIGRATION]` risk or new model fields needed
2. model/service — business logic, data access
3. routes/handlers — HTTP layer
4. tests

**Frontend task order:**
1. types/interfaces — TypeScript types for API response shapes
2. api-service — API client functions
3. component/screen — UI implementation
4. tests

If a task is not needed (e.g. no migration), it is skipped. Fewer tasks = fewer tokens.

---

### 4. Task Sub-Agents

Each task runs as a focused Sonnet sub-agent. Context is strictly bounded:

**Each sub-agent receives:**
- Task description and target file paths
- `[EXPLORATION CONTEXT]` block (compact summary, ~2k tokens)
- The immediate previous task's compact output block only (not the full chain — just what the predecessor produced)
- PM_OUTPUT's relevant section (backend or frontend changes needed)

**Each sub-agent does not receive:**
- Full spec file
- CLAUDE.md (patterns are already in EXPLORATION CONTEXT)
- Earlier tasks' outputs beyond the immediate predecessor
- Raw codebase files (exploration already summarized them)

**Each sub-agent emits** a compact output block listing files changed/created and any new contracts produced.

**After all task sub-agents complete**, the coordinator assembles their outputs into a single `[BACKEND-AGENT OUTPUT]` (or `[FRONTEND-AGENT OUTPUT]`) block in the standard format the Reviewer expects — merging all `Files changed`, `Files created`, `New API contracts`, `Test results`, and `Items not implemented` fields across all tasks. The Reviewer receives this assembled block unchanged; it has no visibility into the internal task structure.

---

## Token Flow

| Scenario | Current | New (simple path) | New (complex path) |
|---|---|---|---|
| 1–2 file change | 1 agent, full read | Unchanged | Unchanged |
| 5+ file change | 1 agent, full read, risks context overflow | Unchanged | Exploration (1×, Haiku) + N focused Sonnet agents |
| Large codebase | May miss files, context strain | Unchanged | Exploration summarizes once; task agents stay bounded |

**Key property:** exploration cost is paid once per layer. As codebase size grows, only the exploration agent scales with it. Task agents receive a fixed-size summary and stay constant.

**Model assignments:**

| Agent | Model | Rationale |
|---|---|---|
| Planner (complexity scoring) | Haiku | Cheap decision |
| Exploration Agent | Haiku | Read + summarize, no implementation |
| Coordinator task breakdown | In-session (no dispatch) | Zero additional cost |
| Task sub-agents | Sonnet | Implementation requires capability |
| Simple path | Sonnet | Unchanged from today |

---

## Affected Files

| File | Change |
|---|---|
| `skills/nob/planner/SKILL.md` | Add complexity scoring logic and `Complexity:` fields to output format |
| `skills/nob/backend-agent/SKILL.md` | Add coordinator mode: check complexity, dispatch exploration agent, dispatch sequential task sub-agents |
| `skills/nob/frontend-agent/SKILL.md` | Same as backend-agent |

No changes to: Hub, PM Agent, Reviewer, checkpoint system, `.nob.yml` template.

---

## Acceptance Criteria

- Simple specs (1–2 file changes, no risk flags) run the existing in-session path with no added cost
- Complex specs dispatch an exploration agent (Haiku) once, then sequential task sub-agents (Sonnet)
- Each task sub-agent receives only EXPLORATION CONTEXT + previous task output + its specific task — no full codebase re-read
- Exploration context output is under 2,000 tokens
- Task order within a layer respects dependencies (schema before service before routes before tests)
- Reviewer receives the same output format as today — no changes needed downstream
