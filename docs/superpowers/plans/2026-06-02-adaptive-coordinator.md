# Adaptive Coordinator with Shared Exploration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Backend and Frontend agents scale to large codebases and complex specs by adding an adaptive coordinator mode — in-session for simple specs, exploration + sequential sub-agents for complex ones.

**Architecture:** The Planner gains a per-layer complexity score (`simple | complex`). When `complex`, Backend/Frontend agents become coordinators: one Haiku exploration agent reads the codebase once and emits a compact summary, then sequential Sonnet task sub-agents each receive only that summary and the previous task's output. Simple specs run in-session unchanged.

**Tech Stack:** Markdown skill files only — no code, no test runner. "Tests" are spec-coverage reviews.

---

## File Map

| File | Change |
|---|---|
| `skills/nob/planner/SKILL.md` | Add Step 3.6 (complexity scoring) + `Complexity:` fields to output format |
| `skills/nob/backend-agent/SKILL.md` | Add Step 3.5 (complexity branch) + coordinator mode (Steps 4-C through 7-C) |
| `skills/nob/frontend-agent/SKILL.md` | Add Step 3.5 (complexity branch) + coordinator mode (Steps 4-C through 7-C, frontend task order) |

---

### Task 1: Update Planner — Complexity Scoring

**Files:**
- Modify: `skills/nob/planner/SKILL.md`

- [ ] **Step 1: Add Step 3.6 after Step 3.5**

In `skills/nob/planner/SKILL.md`, find this line:

```
When in doubt: `Mode: single`. Do not force fan-out on ambiguous specs.
```

Insert the following **immediately after** that line (after the blank line closing Step 3.5):

```markdown

### Step 3.6: Score per-layer complexity

For each enabled layer (backend, frontend), assign a complexity score based on AFFECTED_FILES and the Risks identified in Step 5.

**`complex`** if any of these apply to that layer:
- 3 or more files in AFFECTED_FILES for that layer
- Any `[MIGRATION]`, `[AUTH]`, `[BREAKING]`, or `[SHARED]` risk applies to that layer
- The spec involves multiple independent concerns within the same layer (e.g. two unrelated models, or a component and a routing change that touch different parts of the codebase)

**`simple`** otherwise: 1–2 files, no risk flags, single concern.

Store as COMPLEXITY = `{ backend: "simple" | "complex", frontend: "simple" | "complex" }`. If only one layer is enabled, set the disabled layer's score to `"simple"`.
```

- [ ] **Step 2: Add `Complexity:` fields to the output format**

In `skills/nob/planner/SKILL.md`, find this exact block inside the output format:

```
Affected files:
  Backend:  [list of file paths from AFFECTED_FILES.backend, or: none detected]
  Schema:   [list of file paths from AFFECTED_FILES.schema, or: none detected]
  Frontend: [list of file paths from AFFECTED_FILES.frontend, or: none detected]
```

Replace it with:

```
Affected files:
  Backend:  [list of file paths from AFFECTED_FILES.backend, or: none detected]
  Schema:   [list of file paths from AFFECTED_FILES.schema, or: none detected]
  Frontend: [list of file paths from AFFECTED_FILES.frontend, or: none detected]

Complexity:
  Backend: simple | complex
  Frontend: simple | complex
```

- [ ] **Step 3: Review against spec**

Verify:
- Step 3.6 criteria match the spec exactly (`[MIGRATION]`, `[AUTH]`, `[BREAKING]`, `[SHARED]` → complex; 1–2 files no flags → simple)
- `Complexity:` fields appear in `[PLAN OUTPUT]` after `Affected files:` and before `Slices:`
- No other changes made to the planner file

- [ ] **Step 4: Commit**

```bash
git add skills/nob/planner/SKILL.md
git commit -m "feat: planner scores per-layer complexity (simple | complex)"
```

---

### Task 2: Update Backend Agent — Coordinator Mode

**Files:**
- Modify: `skills/nob/backend-agent/SKILL.md`

- [ ] **Step 1: Add Step 3.5 — complexity branch**

In `skills/nob/backend-agent/SKILL.md`, find this exact line:

```
2. Find and read `[PLAN OUTPUT]` if present — extract "Affected files: Backend", "Affected files: Schema", and "Risks:". Store as PLAN_RISKS. If not found, set PLAN_RISKS to empty.
```

Insert the following **immediately after** that line (after the blank line ending Step 3):

```markdown

### Step 3.5: Select execution path

From `[PLAN OUTPUT]`, read `Complexity: Backend:`.

- If `simple` (or if `[PLAN OUTPUT]` is not present): proceed with the **in-session path** — continue to Step 4 as normal.
- If `complex`: enter **coordinator mode** — skip Steps 4, 5, and 5.5 entirely. Continue to **Coordinator Mode** section below.
```

- [ ] **Step 2: Add the Coordinator Mode section**

In `skills/nob/backend-agent/SKILL.md`, find this exact line:

```
### Step 4: Explore existing backend codebase
```

Insert the following **immediately before** that line:

````markdown
---

## Coordinator Mode (complex path only)

Enter this section only when `Complexity: Backend: complex` from Step 3.5. This replaces Steps 4, 5, and 5.5. After completing Step 7-C, skip to Step 6 (Output).

### Step 4-C: Dispatch Exploration Agent

Dispatch a sub-agent with `model: haiku` and this prompt:

```
You are a backend codebase exploration agent. Read the relevant files and emit a compact summary. Do NOT implement anything.

Read every file in this list:
{every path from "Affected files: Backend" and "Affected files: Schema" in [PLAN OUTPUT]}

Also read one representative example of each:
- A route/handler file (to capture route structure, middleware usage, error response format)
- A service or business-logic file
- A test file (to capture test style, assertion patterns, setup approach)
{if [AUTH] in PLAN_RISKS: - The auth middleware file}
{if [MIGRATION] in PLAN_RISKS: - An existing schema file and an existing migration file}

Emit this block:

[BACKEND-EXPLORATION CONTEXT]
Affected files:
  - [path]: [one-sentence role]

Patterns observed:
  Route structure: [handler signature, how router is mounted]
  Error format: [exact error response shape]
  Test style: [file structure, assertion style, setup pattern]
  Auth wiring: [how middleware is applied to routes, or: none detected]
  Migration pattern: [how migrations are created and run, or: none detected]

Relevant snippets:
  [Function signatures, type shapes, and key lines only. No full file dumps. Keep this section under 1500 tokens.]
[/BACKEND-EXPLORATION CONTEXT]
```

Extract `[BACKEND-EXPLORATION CONTEXT]...[/BACKEND-EXPLORATION CONTEXT]`. Store as EXPLORATION_CONTEXT.

### Step 5-C: Determine Task List (in-session, no dispatch)

Based on EXPLORATION_CONTEXT and PM_OUTPUT "Backend changes needed", decide which tasks are needed. Only include tasks that have actual work to do.

Evaluate in this order:

1. **schema** — create/update schema and migration file. Include if `[MIGRATION]` in PLAN_RISKS or PM_OUTPUT requires new or changed model fields.
2. **service** — implement business logic and data access. Include if new service methods or data layer changes are needed.
3. **routes** — implement HTTP handlers and register routes. Include if new or changed endpoints are required.
4. **tests** — write tests for all new or changed endpoints and service methods. Always include.

Store as TASK_LIST = ordered array of objects: `{ name: string, description: string, target_files: string[] }`.

### Step 6-C: Dispatch Sequential Task Sub-Agents

For each task in TASK_LIST **in order** (do not dispatch the next until the previous returns):

Dispatch a sub-agent with the `backend-agent` model from `.nob.yml` (default: `sonnet`) and this prompt:

```
You are a focused backend implementation agent. Implement exactly one task. Do not read additional files — all context you need is provided below.

Task: {task.name}
Description: {task.description}
Target files (implement only these): {task.target_files}

[BACKEND-EXPLORATION CONTEXT]
{EXPLORATION_CONTEXT}
[/BACKEND-EXPLORATION CONTEXT]

Backend changes needed (from PM Agent):
{PM_OUTPUT "Backend changes needed" section}

{if this is not the first task:
Previous task output:
{previous task's [TASK OUTPUT] block}
}

{if PM_API_CONTRACTS is non-null:
API contracts (implement exactly — method, path, and shapes are non-negotiable):
{PM_API_CONTRACTS}
}

Follow the patterns in [BACKEND-EXPLORATION CONTEXT] exactly. Emit:

[TASK OUTPUT: {task.name}]
Files changed:
  - [path]: [reason]
Files created:
  - [path]: [reason]
New API contracts (routes task only):
  - [METHOD] [/path]: request: [shape] → response: [shape]
Test results (tests task only):
  Command: [exact command run]
  New tests: [PASS | FAIL — N failed]
  Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]
Items not implemented (needs human):
  - [item and reason, or: none]
[/TASK OUTPUT: {task.name}]
```

Store each result as TASK_OUTPUT_{task.name}. Pass it as "Previous task output" to the next sub-agent.

### Step 7-C: Assemble Final Output

Merge all TASK_OUTPUT blocks into the standard `[BACKEND-AGENT OUTPUT]` format. Combine across all tasks:
- All `Files changed` entries
- All `Files created` entries
- All `New API contracts` and `Updated API contracts` entries (from routes task)
- Test results from the tests task (if not present, write: `SKIPPED — run by coordinator task sub-agent`)
- All `Items not implemented` entries (deduplicated)

Then emit the `[BACKEND-AGENT OUTPUT]` block as defined in **## Output Format** below and stop. Do not continue to Steps 4, 5, or 5.5.

---

````

- [ ] **Step 3: Review against spec**

Check each requirement from the spec against what was written:
- Exploration agent uses `haiku` model ✓
- Exploration context target is under 2k tokens (1500 snippets + overhead) ✓
- Coordinator task breakdown runs in-session (no sub-agent dispatched) ✓
- Task sub-agents use `sonnet` / backend-agent model ✓
- Each task sub-agent receives: EXPLORATION_CONTEXT + task description + target files + previous task output only (not full chain) + PM_OUTPUT backend section ✓
- Sequential dispatch (not parallel) ✓
- Step 7-C assembles into standard `[BACKEND-AGENT OUTPUT]` format that Reviewer already expects ✓
- Simple path unchanged (Step 3.5 branches to Step 4 as before) ✓

- [ ] **Step 4: Commit**

```bash
git add skills/nob/backend-agent/SKILL.md
git commit -m "feat: backend-agent gains adaptive coordinator mode with shared exploration"
```

---

### Task 3: Update Frontend Agent — Coordinator Mode

**Files:**
- Modify: `skills/nob/frontend-agent/SKILL.md`

- [ ] **Step 1: Add Step 3.5 — complexity branch**

In `skills/nob/frontend-agent/SKILL.md`, find this exact line:

```
3. Find and read `[PLAN OUTPUT]` if present — extract "Affected files: Frontend" and "Risks:". Store as PLAN_RISKS. If not found, set PLAN_RISKS to empty.
```

Insert the following **immediately after** that line (after the blank line ending Step 3):

```markdown

### Step 3.5: Select execution path

From `[PLAN OUTPUT]`, read `Complexity: Frontend:`.

- If `simple` (or if `[PLAN OUTPUT]` is not present): proceed with the **in-session path** — continue to Step 4 as normal.
- If `complex`: enter **coordinator mode** — skip Steps 4, 5, and 5.5 entirely. Continue to **Coordinator Mode** section below.
```

- [ ] **Step 2: Add the Coordinator Mode section**

In `skills/nob/frontend-agent/SKILL.md`, find this exact line:

```
### Step 4: Explore existing frontend codebase
```

Insert the following **immediately before** that line:

````markdown
---

## Coordinator Mode (complex path only)

Enter this section only when `Complexity: Frontend: complex` from Step 3.5. This replaces Steps 4, 5, and 5.5. After completing Step 7-C, skip to **## Output Format**.

### Step 4-C: Dispatch Exploration Agent

Dispatch a sub-agent with `model: haiku` and this prompt:

```
You are a frontend codebase exploration agent. Read the relevant files and emit a compact summary. Do NOT implement anything.

Read every file in this list:
{every path from "Affected files: Frontend" in [PLAN OUTPUT]}

Also read one representative example of each:
- An existing component or screen similar in complexity to what the spec requires
- The API client or service file (to capture how API calls are made)
- The routing/navigation file (to capture how routes are registered)
{if [AUTH] in PLAN_RISKS: - How an existing protected route or screen enforces auth}
{if [SHARED] in PLAN_RISKS: - Shared components or utilities being touched}

Emit this block:

[FRONTEND-EXPLORATION CONTEXT]
Affected files:
  - [path]: [one-sentence role]

Patterns observed:
  Component structure: [file structure, props pattern, naming convention]
  API client usage: [how API calls are made — axios instance, fetch wrapper, etc.]
  State management: [useState/zustand/Pinia/Provider/etc. — how it is used in existing components]
  Routing pattern: [how routes are registered, file-based vs config-based]
  Auth pattern: [how protected screens enforce auth, or: none detected]
  Test style: [file structure, render pattern, assertion style]

Relevant snippets:
  [Function signatures, type shapes, component skeletons, and key lines only. No full file dumps. Keep this section under 1500 tokens.]
[/FRONTEND-EXPLORATION CONTEXT]
```

Extract `[FRONTEND-EXPLORATION CONTEXT]...[/FRONTEND-EXPLORATION CONTEXT]`. Store as EXPLORATION_CONTEXT.

### Step 5-C: Determine Task List (in-session, no dispatch)

Based on EXPLORATION_CONTEXT and PM_OUTPUT "Frontend changes needed", decide which tasks are needed. Only include tasks that have actual work to do.

Evaluate in this order:

1. **types** — define TypeScript interfaces/types for all API response shapes consumed. Include if stack is TypeScript (react, next, vue, react-native) and new API shapes are introduced.
2. **api-service** — implement API client functions for all endpoints consumed. Include if new endpoints are called.
3. **component** — implement UI components, screens, or pages. Include if new or changed UI is required.
4. **tests** — write tests for all new or changed components and service functions. Always include.

Store as TASK_LIST = ordered array of objects: `{ name: string, description: string, target_files: string[] }`.

### Step 6-C: Dispatch Sequential Task Sub-Agents

For each task in TASK_LIST **in order** (do not dispatch the next until the previous returns):

Dispatch a sub-agent with the `frontend-agent` model from `.nob.yml` (default: `sonnet`) and this prompt:

```
You are a focused frontend implementation agent. Implement exactly one task. Do not read additional files — all context you need is provided below.

Task: {task.name}
Description: {task.description}
Target files (implement only these): {task.target_files}

[FRONTEND-EXPLORATION CONTEXT]
{EXPLORATION_CONTEXT}
[/FRONTEND-EXPLORATION CONTEXT]

Frontend changes needed (from PM Agent):
{PM_OUTPUT "Frontend changes needed" section}

{if [BACKEND-AGENT OUTPUT] is available and this is the component or api-service task:
API contracts from Backend Agent (use these — they take precedence over PM contracts):
{BACKEND_OUTPUT "New API contracts" and "Updated API contracts" sections}
}

{if PM_API_CONTRACTS is non-null and no [BACKEND-AGENT OUTPUT] is available:
API contracts from PM Agent:
{PM_API_CONTRACTS}
}

{if this is not the first task:
Previous task output:
{previous task's [TASK OUTPUT] block}
}

Follow the patterns in [FRONTEND-EXPLORATION CONTEXT] exactly. Implement all states: loading, error, empty, and success. Emit:

[TASK OUTPUT: {task.name}]
Files changed:
  - [path]: [reason]
Files created:
  - [path]: [reason]
API endpoints consumed (component/api-service task only):
  - [METHOD] [/path]: [how used in the UI]
Test results (tests task only):
  Command: [exact command run]
  New tests: [PASS | FAIL — N failed]
  Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]
Items not implemented (needs human):
  - [item and reason, or: none]
[/TASK OUTPUT: {task.name}]
```

Store each result as TASK_OUTPUT_{task.name}. Pass it as "Previous task output" to the next sub-agent.

### Step 7-C: Assemble Final Output

Merge all TASK_OUTPUT blocks into the standard `[FRONTEND-AGENT OUTPUT]` format. Combine across all tasks:
- All `Files changed` entries
- All `Files created` entries
- All `API endpoints consumed` entries (from component and api-service tasks)
- Test results from the tests task (if not present, write: `SKIPPED — run by coordinator task sub-agent`)
- All `Items not implemented` entries (deduplicated)

Then emit the `[FRONTEND-AGENT OUTPUT]` block as defined in **## Output Format** below and stop. Do not continue to Steps 4, 5, or 5.5.

---

````

- [ ] **Step 3: Review against spec**

Check each requirement from the spec:
- Exploration agent uses `haiku` model ✓
- Frontend task order: types → api-service → component → tests ✓
- Backend API contracts sourced from `[BACKEND-AGENT OUTPUT]` when available (takes precedence), PM_API_CONTRACTS otherwise ✓
- Each task sub-agent receives: EXPLORATION_CONTEXT + task + target files + previous task output + relevant PM section ✓
- Sequential dispatch ✓
- Step 7-C assembles into standard `[FRONTEND-AGENT OUTPUT]` format Reviewer expects ✓
- Simple path unchanged ✓

- [ ] **Step 4: Commit**

```bash
git add skills/nob/frontend-agent/SKILL.md
git commit -m "feat: frontend-agent gains adaptive coordinator mode with shared exploration"
```

---

## Final Verification

- [ ] **Check all three files are consistent**

Verify:
1. `[PLAN OUTPUT]` in `planner/SKILL.md` has `Complexity:` fields
2. `backend-agent/SKILL.md` Step 3.5 reads `Complexity: Backend:` (matches planner output field exactly)
3. `frontend-agent/SKILL.md` Step 3.5 reads `Complexity: Frontend:` (matches planner output field exactly)
4. Both coordinators reference `[BACKEND-EXPLORATION CONTEXT]` / `[FRONTEND-EXPLORATION CONTEXT]` consistently across Steps 4-C and 6-C
5. Both assemblers in Step 7-C reference `[BACKEND-AGENT OUTPUT]` / `[FRONTEND-AGENT OUTPUT]` — the format the Reviewer reads

- [ ] **Final commit**

```bash
git log --oneline -4
```

Expected: three new commits on top of baseline — planner, backend-agent, frontend-agent.
