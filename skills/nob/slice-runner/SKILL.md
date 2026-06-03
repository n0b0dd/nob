---
name: slice-runner
description: Slice agent for fan-out mode — executes PM → (Backend+Frontend concurrent) for one spec slice. Dispatched by the Nob hub.
---

# Slice Runner

Execute a complete PM → (Backend + Frontend concurrent) pipeline for one slice of a larger feature. The Agent tool is available — use it to dispatch Backend and Frontend as concurrent sub-agents.

## Step 0 — Read skill files

Using the Read tool, read each path from your [INPUTS]:
1. Read `PM Agent skill path` → store as PM_SKILL
2. Read `Backend Agent skill path` → store as BACKEND_SKILL
3. Read `Frontend Agent skill path` → store as FRONTEND_SKILL

## Step 1 — PM Agent (in-session)

Follow PM_SKILL instructions in this session. Emit `[PM-AGENT OUTPUT]` before continuing. Store the extracted block as PM_OUTPUT.

## Step 2 — Backend Agent + Frontend Agent (concurrent)

After PM completes, dispatch both in the same response — do not await one before dispatching the other.

**Backend Agent** prompt:

```
[INSTRUCTIONS]
{full contents of BACKEND_SKILL}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from your [INPUTS]}
.nob.yml contents: {.nob.yml contents from your [INPUTS]}
CLAUDE.md contents: {CLAUDE.md contents from your [INPUTS]}
Stack guidance path: {Backend Agent stack guidance path from your [INPUTS]}
Requirements from PM Agent:
{PM_OUTPUT}
{if Clarifications: Clarifications from user: {Clarifications from your [INPUTS]}}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first. Stop before reaching the limit. List remaining work under Deferred items:.
[/INPUTS]
```

**Frontend Agent** prompt:

```
[INSTRUCTIONS]
{full contents of FRONTEND_SKILL}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from your [INPUTS]}
.nob.yml contents: {.nob.yml contents from your [INPUTS]}
CLAUDE.md contents: {CLAUDE.md contents from your [INPUTS]}
Stack guidance path: {Frontend Agent stack guidance path from your [INPUTS]}
Requirements from PM Agent:
{PM_OUTPUT}
Backend Agent is running in parallel — use API contracts from PM Agent output above. No [BACKEND-AGENT OUTPUT] will be provided.
{if Clarifications: Clarifications from user: {Clarifications from your [INPUTS]}}

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first. Stop before reaching the limit. List remaining work under Deferred items:.
[/INPUTS]
```

## Stack skip rules

Read from `.nob.yml contents` in your [INPUTS]:
- If `stack.backend.enabled: false` or workflow is `API→Sync`: skip Backend; emit `[BACKEND-AGENT OUTPUT]Backend agent was skipped (disabled in config)[/BACKEND-AGENT OUTPUT]`.
- If `stack.frontend.enabled: false`: skip Frontend; emit `[FRONTEND-AGENT OUTPUT]Frontend agent was skipped (disabled in config)[/FRONTEND-AGENT OUTPUT]`.

## Step 2.5 — Validate output blocks

After both sub-agents return, validate required fields before wrapping. This mirrors the hub's Output Block Validation Procedure so fan-out runs have the same guarantees as single-slice runs.

**Backend Agent required fields:** `Files changed:`, `New API contracts:`, `Items not implemented (needs human):`, `Deferred items:`, `Test results:`, `Test output:`

**Frontend Agent required fields:** `Files changed:`, `API endpoints consumed:`, `Items not implemented (needs human):`, `Deferred items:`, `Test results:`, `Test output:`

For each non-skipped agent output block:
1. Check that every required field appears as `FieldName:` on its own line within the extracted block.
2. If all required fields are present: proceed to Output section.
3. If any required field is missing: re-dispatch that agent once with the same prompt prepended by:
   > "Your previous response was missing these required fields: [list the missing fields].
   > Re-emit the complete [X-AGENT OUTPUT] block with ALL required fields present.
   > Do not omit any field even if its value is 'none' or 'n/a'."
4. If still missing after re-dispatch: use the output as-is. Prepend a comment line `# WARNING: missing fields: [list]` immediately inside the output block (before the first field line).

## Output

After both agents return and output blocks are validated, extract their output blocks and wrap everything inside:

```
[SLICE OUTPUT: {Slice name from your [INPUTS]}]
{[PM-AGENT OUTPUT] block}
{[BACKEND-AGENT OUTPUT] block}
{[FRONTEND-AGENT OUTPUT] block}
[/SLICE OUTPUT: {Slice name from your [INPUTS]}]
```
