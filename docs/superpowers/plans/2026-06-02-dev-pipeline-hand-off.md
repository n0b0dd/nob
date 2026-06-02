# Dev Pipeline Hand-off Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three dev pipeline gaps: anchor concurrent Backend/Frontend agents to PM-defined API contracts, remove dead QA Agent code, and add a bounded user-gated retry after Reviewer failures.

**Architecture:** Six targeted edits across five Markdown skill files — no new files created. Changes flow in dependency order: PM Agent defines the `API contracts:` format → Backend/Frontend/Reviewer consume it → Hub adds retry orchestration around Reviewer. Each task is self-contained and commits cleanly.

**Tech Stack:** Markdown skill files only. No build system, no test runner. Verification is manual — read modified sections back and confirm cross-file label consistency (output labels in one file must match what downstream files expect to parse).

---

## File map

| File | What changes |
|---|---|
| `skills/pm-agent/SKILL.md` | Add extraction item 8 (API contracts) to Step 2; add `API contracts:` section to output format |
| `skills/nob/backend-agent/SKILL.md` | Step 3: extract PM_API_CONTRACTS; Step 5: enforce PM contracts as non-negotiable |
| `skills/nob/frontend-agent/SKILL.md` | Step 3: extract PM_API_CONTRACTS, clarify precedence; Step 5: enforce contract source of truth |
| `skills/nob/reviewer/SKILL.md` | Replace Step 3.5 with three-way contract check; expand output format `Contract check:` |
| `skills/nob/SKILL.md` | Add Phase 3.5 retry section after Write final checkpoint; add Retry line to terminal summary |
| `skills/nob/qa-agent/SKILL.md` | Delete |

---

## Task 1: PM Agent — add `API contracts:` to Requirements Extraction output

**Files:**
- Modify: `skills/pm-agent/SKILL.md`

- [ ] **Step 1: Add extraction item 8 to Step 2**

Find this line in `skills/pm-agent/SKILL.md` (it's the last item in Step 2's numbered list):

```
7. **Ambiguities** — requirements that could be interpreted two ways, phrased as questions
```

Add the following immediately after it (new line 8 in the numbered list):

```
8. **API contracts** — derive a structured contract list from `Backend changes needed:`. For each backend change, extract: exact HTTP method, exact path, request body shape (field names and types), and response shape. Use exact field names from the spec where given. For any field whose type is not specified, write `any` and add it as a `[non-blocking]` ambiguity. If there are no backend API changes in scope, write `none`.
```

- [ ] **Step 2: Add `API contracts:` section to output format**

Find this block in the output format section of `skills/pm-agent/SKILL.md`:

```
Frontend changes needed:
- [screen/component] in `[file from RELATED_FILES, or: new file to create]`: [what changes]
- [or: not specified in spec — frontend agent should infer from acceptance criteria]

Edge cases to handle:
```

Replace it with:

```
Frontend changes needed:
- [screen/component] in `[file from RELATED_FILES, or: new file to create]`: [what changes]
- [or: not specified in spec — frontend agent should infer from acceptance criteria]

API contracts:
- [METHOD] [/exact/path]: request: { field: type, ... } → response: { field: type, ... }
- [METHOD] [/exact/path]: request: none → response: { field: type, ... }
(or: none — no HTTP API changes in this feature)

Edge cases to handle:
```

- [ ] **Step 3: Verify**

Read the output format section of `skills/pm-agent/SKILL.md`. Confirm:
- `API contracts:` appears between `Frontend changes needed:` and `Edge cases to handle:`
- The format shows `[METHOD] [/exact/path]: request: ... → response: ...`
- The `(or: none ...)` fallback is present
- Item 8 in Step 2 matches the format (method, path, shapes, `any` for unknown types)

- [ ] **Step 4: Commit**

```bash
git add skills/pm-agent/SKILL.md
git commit -m "feat: add API contracts block to pm-agent output format"
```

---

## Task 2: Backend Agent — treat PM `API contracts:` as authoritative

**Files:**
- Modify: `skills/nob/backend-agent/SKILL.md`

- [ ] **Step 1: Add PM_API_CONTRACTS extraction to Step 3**

Find this text in `skills/nob/backend-agent/SKILL.md`:

```
1. Find and read `[PM-AGENT OUTPUT]` — extract "Backend changes needed" (includes specific file paths). If not found, stop: "Backend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context. Ensure pm-agent ran before backend-agent."
```

Replace it with:

```
1. Find and read `[PM-AGENT OUTPUT]` — extract "Backend changes needed" (includes specific file paths). If not found, stop: "Backend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context. Ensure pm-agent ran before backend-agent."
   Also extract `API contracts:` from `[PM-AGENT OUTPUT]`. Store as PM_API_CONTRACTS. If the field reads `none`, set PM_API_CONTRACTS to null.
```

- [ ] **Step 2: Add enforcement clause to Step 5**

Find this text in Step 5 of `skills/nob/backend-agent/SKILL.md`:

```
Write the minimum code to satisfy the "Backend changes needed" requirements from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:
```

Replace it with:

```
Write the minimum code to satisfy the "Backend changes needed" requirements from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:

**API contract enforcement**: when PM_API_CONTRACTS is non-null, implement each listed endpoint exactly — HTTP method, path, and request/response shapes are non-negotiable. Any necessary deviation (e.g. the path conflicts with an existing route, or a field name clashes with the schema) must be documented in `Items not implemented (needs human)` with: the PM-specified contract, what was implemented instead, and the reason.
```

- [ ] **Step 3: Verify**

Read Steps 3 and 5 of `skills/nob/backend-agent/SKILL.md`. Confirm:
- Step 3 item 1 extracts `API contracts:` and stores as PM_API_CONTRACTS
- Step 3 item 1 sets PM_API_CONTRACTS to null when value is `none`
- Step 5 has the enforcement clause referencing PM_API_CONTRACTS
- `Items not implemented (needs human)` is the correct output field name (matches the output format block in the same file)

- [ ] **Step 4: Commit**

```bash
git add skills/nob/backend-agent/SKILL.md
git commit -m "feat: backend-agent treats PM API contracts as authoritative endpoint spec"
```

---

## Task 3: Frontend Agent — treat PM `API contracts:` as authoritative

**Files:**
- Modify: `skills/nob/frontend-agent/SKILL.md`

- [ ] **Step 1: Add PM_API_CONTRACTS extraction to Step 3 item 1**

Find this text in `skills/nob/frontend-agent/SKILL.md`:

```
1. Find and read `[PM-AGENT OUTPUT]` — extract "Frontend changes needed" (includes specific file paths) and note any `## Error states` referenced. If not found, stop: "Frontend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context."
```

Replace it with:

```
1. Find and read `[PM-AGENT OUTPUT]` — extract "Frontend changes needed" (includes specific file paths) and note any `## Error states` referenced. If not found, stop: "Frontend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context."
   Also extract `API contracts:` from `[PM-AGENT OUTPUT]`. Store as PM_API_CONTRACTS. If the field reads `none`, set PM_API_CONTRACTS to null.
```

- [ ] **Step 2: Update Step 3 item 2 to clarify precedence**

Find this text in `skills/nob/frontend-agent/SKILL.md`:

```
2. Find and read `[BACKEND-AGENT OUTPUT]` — extract "New API contracts" and "Updated API contracts". Use these as the source of truth for endpoints. Do NOT assume or invent API contracts.
```

Replace it with:

```
2. Find and read `[BACKEND-AGENT OUTPUT]` — extract "New API contracts" and "Updated API contracts". If available, these take precedence over PM_API_CONTRACTS as the authoritative endpoint source — use them for all API calls. Do NOT assume or invent API contracts beyond what either source provides.
```

- [ ] **Step 3: Add enforcement clause to Step 5**

Find this text in Step 5 of `skills/nob/frontend-agent/SKILL.md`:

```
Write the minimum code to satisfy "Frontend changes needed" from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:
```

Replace it with:

```
Write the minimum code to satisfy "Frontend changes needed" from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:

**API endpoint source of truth**: when calling backend endpoints, use the contracts from `[BACKEND-AGENT OUTPUT]` if available (takes precedence). If `[BACKEND-AGENT OUTPUT]` is not available (running concurrently with Backend Agent), use PM_API_CONTRACTS — do not infer or adjust paths, methods, or shapes from the prose in "Frontend changes needed:". If PM_API_CONTRACTS is also null, infer from "Frontend changes needed:" and note "No API contracts available — endpoint inferred from spec" in `Items not implemented (needs human)`.
```

- [ ] **Step 4: Verify**

Read Steps 3 and 5 of `skills/nob/frontend-agent/SKILL.md`. Confirm:
- Step 3 item 1 extracts `API contracts:` and stores as PM_API_CONTRACTS with null fallback
- Step 3 item 2 says `[BACKEND-AGENT OUTPUT]` takes precedence over PM_API_CONTRACTS
- Step 5 enforcement clause covers three cases: backend output available → use it; not available → use PM_API_CONTRACTS; neither → infer and flag
- `Items not implemented (needs human)` matches the output format field name in the same file

- [ ] **Step 5: Commit**

```bash
git add skills/nob/frontend-agent/SKILL.md
git commit -m "feat: frontend-agent treats PM API contracts as endpoint source of truth"
```

---

## Task 4: Reviewer — three-way contract check

**Files:**
- Modify: `skills/nob/reviewer/SKILL.md`

- [ ] **Step 1: Replace Step 3.5**

Find this entire section in `skills/nob/reviewer/SKILL.md`:

```
### Step 3.5: Cross-layer contract check

Compare "New/Updated API contracts" from [BACKEND-AGENT OUTPUT] against "API endpoints consumed" from [FRONTEND-AGENT OUTPUT].

For each endpoint the frontend consumes:
- Find the matching contract in [BACKEND-AGENT OUTPUT]
- Verify HTTP method and path match exactly
- Verify the response shape the frontend expects matches what backend outputs

Flag any mismatch as a CONTRACT VIOLATION and add it to "Items for human review" regardless of criterion status.

Skip this step if [BACKEND-AGENT OUTPUT] is absent (API→Sync or backend disabled) or [FRONTEND-AGENT OUTPUT] is absent (frontend disabled).
```

Replace it with:

```
### Step 3.5: Cross-layer contract check

Extract `API contracts:` from `[PM-AGENT OUTPUT]`. Run three checks:

**1. PM → Backend** (skip if `API contracts: none` in PM output, or if `[BACKEND-AGENT OUTPUT]` is absent):
For each contract in PM `API contracts:`, find the matching entry in `[BACKEND-AGENT OUTPUT]` `New API contracts:`. Flag as CONTRACT VIOLATION if HTTP method, path, or response shape differs.

**2. PM → Frontend** (skip if `API contracts: none` in PM output, or if `[FRONTEND-AGENT OUTPUT]` is absent):
For each contract in PM `API contracts:`, find the matching entry in `[FRONTEND-AGENT OUTPUT]` `API endpoints consumed:`. Flag as CONTRACT VIOLATION if HTTP method or path differs.

**3. Backend → Frontend** (skip if `[BACKEND-AGENT OUTPUT]` or `[FRONTEND-AGENT OUTPUT]` is absent):
For each endpoint the frontend consumes, find the matching contract in `[BACKEND-AGENT OUTPUT]`. Verify HTTP method and path match exactly. Verify the response shape the frontend expects matches what backend outputs.

Add all CONTRACT VIOLATIONS to "Items for human review" regardless of criterion status.
```

- [ ] **Step 2: Update output format `Contract check:` line**

Find this line in the output format block of `skills/nob/reviewer/SKILL.md`:

```
Contract check: [PASS — all endpoints match | VIOLATIONS: list | SKIPPED — no cross-layer integration]
```

Replace it with:

```
Contract check:
  PM → Backend:       [PASS | VIOLATIONS: list | SKIPPED — reason]
  PM → Frontend:      [PASS | VIOLATIONS: list | SKIPPED — reason]
  Backend → Frontend: [PASS | VIOLATIONS: list | SKIPPED — reason]
```

- [ ] **Step 3: Verify**

Read Step 3.5 and the output format of `skills/nob/reviewer/SKILL.md`. Confirm:
- Three named checks: PM → Backend, PM → Frontend, Backend → Frontend
- Each check has its own skip condition
- CONTRACT VIOLATIONS all go to "Items for human review"
- Output format has three sub-lines under `Contract check:`
- Field names referenced in checks match what pm-agent, backend-agent, and frontend-agent output: `API contracts:`, `New API contracts:`, `API endpoints consumed:`

- [ ] **Step 4: Commit**

```bash
git add skills/nob/reviewer/SKILL.md
git commit -m "feat: reviewer performs three-way contract check against PM spec"
```

---

## Task 5: Delete QA Agent

**Files:**
- Delete: `skills/nob/qa-agent/SKILL.md`

- [ ] **Step 1: Confirm hub does not reference qa-agent in agents.enabled**

Read the `agents.enabled` default in `skills/nob/SKILL.md` (Step 1, Build RESOLVED_CONFIG section). Confirm the list is:
```
enabled: [planner, pm-agent, backend-agent, frontend-agent, reviewer]
```
`qa-agent` must not be present. If it is, remove it from the list before proceeding.

- [ ] **Step 2: Delete the file**

```bash
git rm skills/nob/qa-agent/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove orphaned qa-agent skill file"
```

---

## Task 6: Hub — Phase 3.5 targeted retry

**Files:**
- Modify: `skills/nob/SKILL.md`

This is the largest change. Two edits: insert Phase 3.5 section, update terminal summary.

- [ ] **Step 1: Insert Phase 3.5 after "Write final checkpoint"**

Find this block in `skills/nob/SKILL.md` (end of Phase 3):

```
**Write final checkpoint** (if checkpoint.enabled):
Update `{checkpoint.path}checkpoint.json` — set `reviewer_output` to the full REVIEWER_OUTPUT string. Write using the Write tool.

---

## Step 4: Print terminal summary
```

Replace it with:

```
**Write final checkpoint** (if checkpoint.enabled):
Update `{checkpoint.path}checkpoint.json` — set `reviewer_output` to the full REVIEWER_OUTPUT string. Write using the Write tool.

---

## Phase 3.5: Targeted retry

Read `Overall status:` from REVIEWER_OUTPUT. Set RETRY_RAN = false.

If `Overall status: PASS`: skip this phase entirely and proceed to Step 4.

If `Overall status: NEEDS REVIEW` or `Overall status: FAIL`:

**Determine which agents to re-dispatch:**

Extract from REVIEWER_OUTPUT:
- `Test results: Backend: FAIL` → set RETRY_BACKEND = true
- `Test results: Frontend: FAIL` → set RETRY_FRONTEND = true
- For each `✗` or `⚠` criterion line: cross-reference its text against PM_OUTPUT's `Backend changes needed:` and `Frontend changes needed:` sections
  - Found in `Backend changes needed:` → RETRY_BACKEND = true
  - Found in `Frontend changes needed:` → RETRY_FRONTEND = true
  - Found in both → set both to true
- Any CONTRACT VIOLATION in contract check → RETRY_FRONTEND = true; also set CONTRACT_RETRY = true

If RETRY_BACKEND and RETRY_FRONTEND are both false: no agent can auto-fix the remaining items. Skip retry (RETRY_RAN stays false). Proceed to Step 4.

Collect RETRY_ITEMS = all `✗` criterion lines, all `⚠` criterion lines, and all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

**Present and ask:**

```
Reviewer found N items:
  [RETRY_ITEMS listed one per line]

Attempt to auto-fix? (yes / no)
```

Wait for response.

**If no:** RETRY_RAN stays false. Proceed to Step 4.

**If yes:** Set RETRY_RAN = true. Dispatch flagged agents concurrently in the same assistant turn (do not await one before dispatching the other).

**Backend retry** (only if RETRY_BACKEND = true):

Read `{SKILL_BASE_DIR}/backend-agent/SKILL.md`. Dispatch with `model: agents.models["backend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/backend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Backend changes needed, plus backend test failures}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]`. Replace BACKEND_OUTPUT with this result.

**Frontend retry** (only if RETRY_FRONTEND = true):

Read `{SKILL_BASE_DIR}/frontend-agent/SKILL.md`. Dispatch with `model: agents.models["frontend-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/frontend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

{if CONTRACT_RETRY = true:
Backend Agent output (use these API contracts as the authoritative source of truth):
{BACKEND_OUTPUT}
}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Frontend changes needed, frontend test failures, and contract violations}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Replace FRONTEND_OUTPUT with this result.

**After retry agents return:**

Re-dispatch Reviewer with updated BACKEND_OUTPUT and FRONTEND_OUTPUT using the same prompt structure as Phase 3 (Mode: single path). Extract new REVIEWER_OUTPUT. This is the FINAL review — do not offer retry again regardless of status.

Write updated final checkpoint (if checkpoint.enabled): read checkpoint.json, update `reviewer_output` to the new REVIEWER_OUTPUT, write back.

**Fan-out mode:** When Mode is fan-out, REVIEWER_OUTPUT covers all slices in a single combined block. If retry is triggered, re-dispatch all slices as a new batch using the same batch structure and prompt as Phase 2 fan-out. After slices complete, merge their outputs and re-run Reviewer once. This is the FINAL review — do not offer retry again.

---

## Step 4: Print terminal summary
```

- [ ] **Step 2: Add Retry line to terminal summary**

Find this block in the terminal summary section of `skills/nob/SKILL.md` (the "For all other workflows" summary):

```
Tests:     Backend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT] · Frontend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT]
Review status: [PASS | NEEDS REVIEW | FAIL]
[if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]
```

Replace it with:

```
Tests:     Backend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT] · Frontend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT]
Review status: [PASS | NEEDS REVIEW | FAIL]
[if RETRY_RAN = true: "Retry:     ran  →  Final review: [Overall status from final REVIEWER_OUTPUT]"]
[if RETRY_RAN = false and first review was not PASS: "Retry:     skipped"]
[if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]
```

- [ ] **Step 3: Verify**

Read the Phase 3.5 section and terminal summary of `skills/nob/SKILL.md`. Confirm:
- Phase 3.5 comes between "Write final checkpoint" and "## Step 4:"
- RETRY_BACKEND, RETRY_FRONTEND, CONTRACT_RETRY, RETRY_ITEMS, RETRY_RAN are all defined before use
- If both RETRY_BACKEND and RETRY_FRONTEND are false → skip retry (no loop entered)
- Backend retry prompt structure matches Phase 2 single-slice Backend Agent prompt structure (same fields: Working directory, .nob.yml, CLAUDE.md, Requirements from PM Agent)
- Frontend retry prompt includes `{BACKEND_OUTPUT}` block only when CONTRACT_RETRY = true
- "This is the FINAL review" appears after the retry Reviewer dispatch — no further retry offered
- Fan-out note covers the different case
- Terminal summary Retry line appears between Review status and the human review items list

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Phase 3.5 targeted retry after reviewer failure"
```

---

## Self-review checklist

After all tasks are committed, run this cross-file consistency check:

- [ ] `[PM-AGENT OUTPUT]` label `API contracts:` exactly matches what backend-agent Step 3 and frontend-agent Step 3 extract (`API contracts:` — case-sensitive)
- [ ] Reviewer Step 3.5 check 1 references `New API contracts:` — this matches `[BACKEND-AGENT OUTPUT]` output format field name
- [ ] Reviewer Step 3.5 check 2 references `API endpoints consumed:` — this matches `[FRONTEND-AGENT OUTPUT]` output format field name
- [ ] Hub Phase 3.5 Backend retry prompt fields match Phase 2 single-slice Backend Agent prompt exactly (Working directory, .nob.yml, CLAUDE.md, Requirements from PM Agent, Clarifications)
- [ ] Hub Phase 3.5 Frontend retry prompt fields match Phase 2 single-slice Frontend Agent prompt exactly, plus the optional `{BACKEND_OUTPUT}` block
- [ ] `qa-agent/SKILL.md` is gone: `ls skills/nob/qa-agent/` returns "No such file"
- [ ] Hub `agents.enabled` default does not contain `qa-agent`
