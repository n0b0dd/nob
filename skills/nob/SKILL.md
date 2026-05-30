---
name: nob
description: 'Use when asked to implement a feature spec, fix a bug, or sync clients after an API change across a fullstack monorepo. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob [intent]". Orchestrates Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer in sequence.'
---

# Nob — Hub Orchestrator

## Overview
Nob automates cross-layer development workflows in a fullstack monorepo. This hub reads the user's intent, identifies the workflow type, and invokes sub-skills in the correct sequence. Every run starts with the Planner and ends with the Reviewer.

## Agent Dispatch Model

Each sub-skill runs as an **isolated Agent tool call** — a fresh context with only its required inputs. The hub reads each sub-skill's SKILL.md file, constructs a focused prompt, dispatches via the Agent tool, and extracts only the labeled output block from the result. The hub's own context stays under ~10k tokens regardless of codebase size.

## Setup: Resolve skill base directory

Read the system context for a line starting with `Base directory for this skill:`. Extract the path and store it as SKILL_BASE_DIR. Every sub-skill path in this document is written as `{SKILL_BASE_DIR}/X/SKILL.md` — replace `{SKILL_BASE_DIR}` with the extracted path before using the Read tool.

Example: if the system context shows `Base directory for this skill: /home/user/.claude/plugins/cache/n0b0dd/nob/1.0.0/skills/nob`, then SKILL_BASE_DIR is `/home/user/.claude/plugins/cache/n0b0dd/nob/1.0.0/skills/nob`.

---

## Step 0: Git branch safety

Run `git branch --show-current` to get the current branch name.

If the current branch is `main` or `master`:
- Derive a branch name from the source file: `nob/<spec-or-bug-filename-without-extension>` (e.g. `nob/user-profile` from `test-spec-user-profile.md`). If no source file exists in the intent (e.g., intent is `nob init`), use `nob/init`.
- Run `git checkout -b <branch-name>` to create and switch to the branch
- Confirm to the user: "Created branch `<branch-name>`"

If already on a non-main branch, proceed without creating a new branch.

If git is not available or the working directory is not a git repo, skip this step and note it in the terminal summary.

## Step 1: Read project config

Read `CLAUDE.md` at the repo root. If not found, note it and continue.

Read `.nob.yml` at the repo root using the Read tool.

If `.nob.yml` is found: use its contents as RESOLVED_CONFIG. Skip to **Extract from RESOLVED_CONFIG** below.

If `.nob.yml` is NOT found: run auto-detection to build RESOLVED_CONFIG.

### Auto-detection

**Frontend detection** (first match wins):
1. Scan for `package.json` in `frontend/`, `web/`, `client/`, `app/` (in that order). If found, read it and check `dependencies`:
   - Contains `next` → type `next`
   - Contains `vue` → type `vue`
   - Contains `react` or `react-dom` → type `react`
   - Framework not recognised → ask: "Found `package.json` in `[dir]` but couldn't identify the framework. What frontend type should I use? (react / vue / next / other)" Wait for answer.
   - Path = the directory containing the matched `package.json`
2. `pubspec.yaml` exists → type `flutter`, path = that directory
3. `android/` directory exists → type `android`, path = `android/`
4. `ios/Podfile` exists → type `ios`, path = `ios/`
5. Multiple candidates found → ask: "I found possible frontend directories: [list]. Which one should Nob use?" Wait for answer.
6. None found → `stack.frontend.enabled: false`

**Backend detection** (first match wins):
1. Scan for `package.json` in `backend/`, `server/`, `api/` (in that order). Check `dependencies` for `express`, `fastify`, `koa`, `hapi` → type `node`. Path = that directory.
2. `requirements.txt` or `pyproject.toml` in `backend/` → type `python`, path = `backend/`
3. `go.mod` in `backend/` → type `go`, path = `backend/`
4. `pom.xml` in `backend/` → type `java`, path = `backend/`
5. Multiple matches across steps 1–4 → ask: "I found possible backend directories: [list]. Which one should Nob use?" Wait for answer. (If only one match, use it. Skip steps 6–9.)
6. No match in steps 1–4: check root `requirements.txt` or `pyproject.toml` → type `python`, path = `.`
7. No match in steps 1–4: root `go.mod` → type `go`, path = `.`
8. No match in steps 1–4: root `pom.xml` → type `java`, path = `.`
9. No match in steps 1–4: root `package.json` contains `express`, `fastify`, `koa`, or `hapi` in `dependencies` → type `node`, path = `.`
10. None found → `stack.backend.enabled: false`

**If both frontend and backend are undetectable:**
Ask: "Could not detect your stack. What is your frontend directory? (or 'none' to skip)"
Then: "What is your backend directory? (or 'none' to skip)"
Proceed once answered.

**Build RESOLVED_CONFIG** as a YAML string using detected values plus these defaults:

```yaml
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

Print: "No `.nob.yml` found — using auto-detected config. Create `.nob.yml` to override."

### Extract from RESOLVED_CONFIG

Extract the model for each agent under `agents.models`. If an agent has no entry, default to `haiku`. Use this model value as the `model:` parameter when dispatching each Agent tool call.

Also extract:
- `agents.max_parallel_slices` (default: 3 if not present)
- `agents.checkpoint.enabled` (default: true if not present)
- `agents.checkpoint.path` (default: `.nob/` if not present)

## Step 2: Identify workflow type

| Intent pattern | Workflow |
|---|---|
| "implement [file]", "build [feature]", "add [feature] from [spec]" | Spec → Code |
| "fix [file]", "there's a bug in [area]", "bug report [file]" | Bug → Fix |
| "sync clients", "api changed", "update clients after [change]" | API → Sync |
| "nob init", "initialize project", "scaffold project", "init" | Init |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
> "Is this a new feature to implement, a bug to fix, or an API contract sync?"

Do NOT guess the workflow type. If ambiguous, ask.

## Init workflow early exit

If the identified workflow is `Init`:
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Do not read or check for a checkpoint file.
- Read `{SKILL_BASE_DIR}/init-agent/SKILL.md`.
- Dispatch an Agent with `model: agents.models["init-agent"] ?? "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/init-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
User intent: {user's original message}
[/INPUTS]
```

- Extract `[INIT-AGENT OUTPUT]...[/INIT-AGENT OUTPUT]` from the result. Store as INIT_OUTPUT.
- Jump directly to Step 4 (Print terminal summary) using the Init terminal summary format below.

## Phase 0: Resume scan

If `agents.checkpoint.enabled` is false, skip this phase entirely and proceed to Phase 1.

Check whether `{checkpoint.path}checkpoint.json` exists using the Read tool.

If the file does not exist or cannot be read: proceed to Phase 1 as a fresh run.

If the file exists and is valid JSON:
1. If `reviewer_output` is non-null → run is already complete. Print the terminal summary using stored outputs and exit. Do not re-run any agents.
2. If `"phase1"` is in `phases_completed` → skip Phase 1 dispatch. Restore the slice list from the checkpoint `slices` keys. For each slice:
   - `status: completed` → inject its outputs: add it to SLICE_RESULTS as {name: slice-name, slice_output: checkpoint.slices[name].slice_output}; skip its mini-pipeline in Phase 2
   - `status: in_progress` → treat as pending; re-run its full mini-pipeline in Phase 2 (partial output not trusted)
   - `status: pending` → run normally in Phase 2
3. If `phases_completed` is empty → proceed to Phase 1 as normal.

If the file exists but cannot be parsed as valid JSON: print "Warning: checkpoint file is corrupted — starting fresh run." Proceed to Phase 1 without resume.

---

## Phase 1: Slice plan

Skip this phase if Phase 0 restored a completed `phase1` checkpoint (go directly to Phase 2 using the restored slice list).

**Dispatch Planner agent:**

Read `{SKILL_BASE_DIR}/planner/SKILL.md`. Dispatch an Agent with `model: agents.models["planner"] ?? "haiku"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/planner/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
User intent: {user's original message}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

.nob.yml contents:
{.nob.yml content}

Spec file path: {spec file path}
Spec file contents:
{spec file content}
[/INPUTS]
```

Extract `[PLAN OUTPUT]...[/PLAN OUTPUT]` from the result. Store as PLAN_OUTPUT.

If PLAN_OUTPUT ambiguities section contains anything other than "none": present them to the user as a numbered list and wait for answers before proceeding. Store answers for inclusion in subsequent agent prompts.

**Determine mode from PLAN_OUTPUT:**
- `Mode: single` → set SLICES = [{name: "main", scope: "full spec"}]
- `Mode: fan-out` → parse each `Slice N — slug-name` / `Scope:` pair; set SLICES = array of {name, scope} objects

**Write Phase 1 checkpoint** (if checkpoint.enabled is true):

Ensure `.nob/` appears in `.gitignore` at the repo root. If the line is absent, append it using the Edit tool.

Create the checkpoint directory if it does not exist: run `mkdir -p {checkpoint.path}` using the Bash tool.

Using the Write tool, write `{checkpoint.path}checkpoint.json`:
```json
{
  "run_id": "{current-branch}-{source-filename-without-extension}",
  "workflow": "{workflow value from PLAN_OUTPUT}",
  "source": "{source file path}",
  "phases_completed": ["phase1"],
  "slices": {
    "{slice-name}": { "status": "pending", "pm_output": null, "backend_output": null, "frontend_output": null, "qa_output": null }
  },
  "reviewer_output": null
}
```
One entry per slice in the `slices` object.

---

## Phase 2: Parallel pipelines

### Single-slice path (Mode: single)

Run PM Agent first (sequential), then Backend Agent and Frontend Agent concurrently, then QA Agent. Skip conditions for each agent are unchanged.

**Agent 1 — PM Agent**

Read `{SKILL_BASE_DIR}/../pm-agent/SKILL.md`. Dispatch with `model: agents.models["pm-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

Plan context:
{PLAN_OUTPUT}
[/INPUTS]
```

Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT.

---

**Agents 2 & 3 — Backend Agent and Frontend Agent (concurrent)**

Dispatch both in the same assistant turn — one Agent call for Backend, one for Frontend. Do not await Backend's result before dispatching Frontend.

**Backend Agent**

Skip if `stack.backend.enabled: false`. Store BACKEND_OUTPUT as "Backend agent was skipped (disabled in config)."

For `API→Sync` workflow: skip. Store BACKEND_OUTPUT as "Backend agent was skipped (API→Sync workflow — backend already changed)."

Otherwise read `{SKILL_BASE_DIR}/backend-agent/SKILL.md`. Dispatch with `model: agents.models["backend-agent"] ?? "haiku"`:

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

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]`. Store as BACKEND_OUTPUT.

---

**Frontend Agent**

Skip if `stack.frontend.enabled: false`. Store FRONTEND_OUTPUT as "Frontend agent was skipped (disabled in config)."

For `API→Sync` workflow: do NOT skip — frontend still runs to consume the changed API contracts.

Otherwise read `{SKILL_BASE_DIR}/frontend-agent/SKILL.md`. Dispatch with `model: agents.models["frontend-agent"] ?? "haiku"`:

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

Backend Agent is running in parallel — use API contracts from PM Agent output above.
No [BACKEND-AGENT OUTPUT] will be provided.

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Store as FRONTEND_OUTPUT.

---

**Agent 4 — QA Agent**

Skip if both `stack.backend.enabled: false` and `stack.frontend.enabled: false`. Store QA_OUTPUT as "QA agent was skipped (both backend and frontend disabled in config)."

If only one agent was skipped, QA still runs. It receives skip-message strings verbatim as inputs; the QA sub-skill handles them gracefully.

Otherwise read `{SKILL_BASE_DIR}/qa-agent/SKILL.md`. Dispatch with `model: agents.models["qa-agent"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/qa-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Backend implementation:
{BACKEND_OUTPUT}

Frontend implementation:
{FRONTEND_OUTPUT}
[/INPUTS]
```

Extract `[QA-AGENT OUTPUT]...[/QA-AGENT OUTPUT]`. Store as QA_OUTPUT.

Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT, qa_output: QA_OUTPUT}]

Proceed to Phase 3.

---

### Fan-out path (Mode: fan-out)

Read these sub-skill files once and store their full contents:
- `{SKILL_BASE_DIR}/../pm-agent/SKILL.md` → PM_SKILL
- `{SKILL_BASE_DIR}/backend-agent/SKILL.md` → BACKEND_SKILL
- `{SKILL_BASE_DIR}/frontend-agent/SKILL.md` → FRONTEND_SKILL
- `{SKILL_BASE_DIR}/qa-agent/SKILL.md` → QA_SKILL

Filter SLICES to only those with `status: pending` or `status: in_progress` (skip `status: completed` — their outputs are already in the checkpoint).

Group pending SLICES into batches of `max_parallel_slices`. For each batch:

**Dispatch all slices in the batch by calling the Agent tool once per slice, all within the same assistant turn — do not await any Agent call result before making the next Agent call.** All N Agent calls for the batch must appear in the same response. This is what enables parallel execution. Each slice gets this prompt (use `model: agents.models["backend-agent"] ?? "sonnet"` — slice agents do implementation work):

```
[INSTRUCTIONS]
You are a Nob slice runner. Execute a complete PM → (Backend+Frontend concurrent) → QA pipeline for one slice of a larger feature. The Agent tool is available to you — use it to dispatch Backend and Frontend as concurrent sub-agents.

Run the pipeline in this order:

**Step 1 — PM Agent (in-session)**
Follow the PM Agent instructions below using this session. Emit `[PM-AGENT OUTPUT]` before continuing. Store the extracted block as PM_OUTPUT.

**Step 2 — Backend Agent + Frontend Agent (concurrent Agent dispatch)**
After PM completes, dispatch both as Agent tool calls in the same response — do not await one before dispatching the other.

Backend Agent call prompt:
```
[INSTRUCTIONS]
{full contents of the BACKEND AGENT INSTRUCTIONS section embedded below}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from your [INPUTS]}
.nob.yml contents: {.nob.yml contents from your [INPUTS]}
CLAUDE.md contents: {CLAUDE.md contents from your [INPUTS]}
Requirements from PM Agent:
{PM_OUTPUT}
{if clarifications: Clarifications from user: {answers}}
[/INPUTS]
```

Frontend Agent call prompt:
```
[INSTRUCTIONS]
{full contents of the FRONTEND AGENT INSTRUCTIONS section embedded below}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory from your [INPUTS]}
.nob.yml contents: {.nob.yml contents from your [INPUTS]}
CLAUDE.md contents: {CLAUDE.md contents from your [INPUTS]}
Requirements from PM Agent:
{PM_OUTPUT}
Backend Agent is running in parallel — use API contracts from PM Agent output above.
No [BACKEND-AGENT OUTPUT] will be provided.
{if clarifications: Clarifications from user: {answers}}
[/INPUTS]
```

After both Agent calls return:
- Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]` from Backend's response. Store as BACKEND_OUTPUT.
- Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]` from Frontend's response. Store as FRONTEND_OUTPUT.

**Step 3 — QA Agent (in-session)**
Follow the QA Agent instructions below using this session. Pass BACKEND_OUTPUT and FRONTEND_OUTPUT. Emit `[QA-AGENT OUTPUT]`.

After all steps complete, wrap all four output blocks in `[SLICE OUTPUT: {slice-name}]...[/SLICE OUTPUT: {slice-name}]`.

Stack skip rules (from the `.nob.yml contents` field in your [INPUTS]) apply:
- If `stack.backend.enabled: false`: skip Backend Agent dispatch; set BACKEND_OUTPUT = `"Backend agent was skipped (disabled in config)"`; emit `[BACKEND-AGENT OUTPUT]Backend agent was skipped (disabled in config)[/BACKEND-AGENT OUTPUT]`.
- If workflow is `API→Sync`: skip Backend Agent dispatch; set BACKEND_OUTPUT = `"Backend agent was skipped (API→Sync workflow — backend already changed)"`; emit `[BACKEND-AGENT OUTPUT]Backend agent was skipped (API→Sync workflow — backend already changed)[/BACKEND-AGENT OUTPUT]`.
- If `stack.frontend.enabled: false`: skip Frontend Agent dispatch; set FRONTEND_OUTPUT = `"Frontend agent was skipped (disabled in config)"`; emit `[FRONTEND-AGENT OUTPUT]Frontend agent was skipped (disabled in config)[/FRONTEND-AGENT OUTPUT]`.
- If both are disabled: skip QA Agent; emit `[QA-AGENT OUTPUT]QA agent was skipped (both backend and frontend disabled in config)[/QA-AGENT OUTPUT]`. Wrap all four blocks in `[SLICE OUTPUT]` and stop.

--- PM AGENT INSTRUCTIONS ---
{PM_SKILL}
--- END PM AGENT INSTRUCTIONS ---

--- BACKEND AGENT INSTRUCTIONS ---
{BACKEND_SKILL}
--- END BACKEND AGENT INSTRUCTIONS ---

--- FRONTEND AGENT INSTRUCTIONS ---
{FRONTEND_SKILL}
--- END FRONTEND AGENT INSTRUCTIONS ---

--- QA AGENT INSTRUCTIONS ---
{QA_SKILL}
--- END QA AGENT INSTRUCTIONS ---

After all four agents complete, wrap all four output blocks inside:
[SLICE OUTPUT: {slice-name}]
...all four output blocks concatenated here...
[/SLICE OUTPUT: {slice-name}]
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory path}
Slice name: {slice-name}
Slice scope: {slice scope from PLAN_OUTPUT}

Spec file path: {spec file path}
Spec file contents: {full spec file contents}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

.nob.yml contents:
{.nob.yml content}

Plan context:
{PLAN_OUTPUT}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]
```

Before dispatching each slice agent, update this slice's checkpoint status to `in_progress`: read checkpoint.json, set `slices[slice-name].status = 'in_progress'`, write back.

**After each slice agent returns:**
1. Extract `[SLICE OUTPUT: {slice-name}]...[/SLICE OUTPUT: {slice-name}]`
2. If block is missing: re-dispatch the slice agent once with the same prompt. If still missing: mark `status: failed` in checkpoint; add to failed list; continue remaining slices.
3. If extraction succeeds: Read the current checkpoint.json into memory, update only the relevant slice object (set `status: completed`, add `slice_output` field), then write the complete checkpoint object back using the Write tool. Also add this slice to SLICE_RESULTS in memory: {name: slice-name, slice_output: [the extracted block]}.

After all batches complete:
- If SLICE_RESULTS is empty (all slices failed): stop. Print terminal summary listing all failures. Do not dispatch Reviewer.
- Otherwise: SLICE_RESULTS is now fully populated from in-memory accumulation during dispatch. Proceed to Phase 3.

---

## Phase 3: Merge review

**Prepare Reviewer input:**

If Mode: single — pass outputs directly as individual labeled blocks (PM_OUTPUT, BACKEND_OUTPUT, FRONTEND_OUTPUT, QA_OUTPUT).

If Mode: fan-out — construct a merged context:
```
[MERGED SLICE OUTPUTS]
--- Slice: {slice-name-1} ---
{slice 1 full SLICE OUTPUT contents}

--- Slice: {slice-name-2} ---
{slice 2 full SLICE OUTPUT contents}
[/MERGED SLICE OUTPUTS]
```

**Dispatch Reviewer agent:**

Read `{SKILL_BASE_DIR}/reviewer/SKILL.md`. Dispatch with `model: agents.models["reviewer"] ?? "haiku"`:

**For Mode: single**, use this [INPUTS] block ending:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

All agent outputs for review:

{PLAN_OUTPUT}

{PM_OUTPUT}

{BACKEND_OUTPUT}

{FRONTEND_OUTPUT}

{QA_OUTPUT}
[/INPUTS]
```

**For Mode: fan-out**, use this [INPUTS] block ending:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

All agent outputs for review:

{PLAN_OUTPUT}

{MERGED SLICE OUTPUTS block constructed above}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT.

**Write final checkpoint** (if checkpoint.enabled):
Update `{checkpoint.path}checkpoint.json` — set `reviewer_output` to the full REVIEWER_OUTPUT string. Write using the Write tool.

---

## Step 4: Print terminal summary

**If workflow is `Init`, use this summary:**

```
Nob init complete.

Project:   [project-name from INIT_OUTPUT]
Stack:     [frontend-type] + [backend-type] + [database]

Files created: [N]
Installs:
  frontend: [npm install ✓ | flutter pub get ✓ | failed ✗]
  backend:  [npm install ✓ | pip install ✓ | go mod tidy ✓ | failed ✗]

[if any install failed:]
Install errors — run manually:
  [exact retry command with correct working directory]

Config written:
  CLAUDE.md
  .nob.yml

Next steps:
  1. Copy .env.example → .env in frontend/ and backend/ and fill in values
  2. Start backend:  [backend start command from INIT_OUTPUT]
  3. Start frontend: [frontend start command from INIT_OUTPUT]
  4. Write a spec:   docs/specs/your-feature.md
  5. Then run:       /nob implement docs/specs/your-feature.md
```

**For all other workflows:**

```
Nob complete.

Workflow:  [Spec→Code | Bug→Fix | API→Sync]
Source:    [spec/bug file path]
Mode:      [single | fan-out (N slices)]
Agents:    [comma-separated list of agents that ran]

[if Mode: fan-out:]
Slices:
  [slice-name]: [PASS | FAIL | SKIPPED]
  ...

Tests:     Backend [PASS | FAIL | SKIPPED] · Frontend [PASS | FAIL | SKIPPED]
Review status: [PASS | NEEDS REVIEW | FAIL]
[if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]

[if checkpoint.enabled:]
Checkpoint: {checkpoint.path}checkpoint.json
When done: rm {checkpoint.path}checkpoint.json

Next steps:
- Review the changes above
- If items need human review, address them before committing
- When satisfied: git add -p && git commit -m "feat: <spec name>"
- Then: git push -u origin <branch-name>
```

---

## Error Handling

- **.nob.yml not found**: run auto-detection (Step 1)
- **Checkpoint file corrupted/unparseable**: warn user, start fresh run (Phase 0)
- **Sub-skill file not found**: warn "sub-skill file {SKILL_BASE_DIR}/[name]/SKILL.md not found — ensure the nob plugin is installed correctly"
- **Planner output has ambiguities**: pause and ask user before proceeding (Phase 1)
- **Slice agent returns no [SLICE OUTPUT] block**: re-dispatch that slice once; if still missing, mark `status: failed`, continue other slices, report in terminal summary (Phase 2)
- **All slices failed**: stop before Phase 3; list all failures prominently; do NOT dispatch Reviewer
- **Some slices failed, others succeeded**: Reviewer runs on successful outputs; failed slices listed prominently in terminal summary
- **Reviewer status is FAIL**: print all failing items prominently; do NOT auto-retry or attempt to fix automatically
- **Non-slice agent result missing expected output block**: re-dispatch once; if still missing, report raw agent output and stop
