---
name: nob
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, or migrate an existing project to nob''s monorepo structure. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [intent]". Orchestrates Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer in sequence. Also auto-detects structure mismatch on any run and offers refactor before proceeding.'
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
- Derive a branch name from the source file: `nob/<spec-or-bug-filename-without-extension>` (e.g. `nob/user-profile` from `test-spec-user-profile.md`). If no source file exists in the intent: use `nob/init` for Init workflows, use `nob/venture` for Venture workflows, use `nob/refactor` for Refactor workflows, otherwise use `nob/unnamed`.
- Run `git checkout -b <branch-name>` to create and switch to the branch
- Confirm to the user: "Created branch `<branch-name>`"

If already on a non-main branch, proceed without creating a new branch.

If git is not available or the working directory is not a git repo, skip this step and note it in the terminal summary.

### Step 0.1: Create worktree

After confirming the current branch (or creating a new one above):

1. Derive run-id by taking the branch name, replacing `/` with `-`, then appending `-` and the source filename without extension.
   - Example: branch `nob/user-profile` + spec `user-profile.md` → run-id `nob-user-profile-user-profile`
   - For workflows with no source file (Init, Venture, Refactor, Ideate): use `<branch-name-with-dashes>-<workflow-lowercase>`

2. Run: `git worktree add .nob/worktrees/<run-id> <current-branch-name>`
   - If the path `.nob/worktrees/<run-id>` already exists: this is a resumed run — reuse it, skip creation.
   - If a different collision: append `-2`, `-3`, etc. to run-id until unique.
   - If `git worktree add` fails for any other reason: print the error and exit.

3. Store `WORKTREE_PATH = .nob/worktrees/<run-id>` and `WORKTREE_BRANCH = <current-branch-name>`.

4. Ensure `.nob/` appears in `.gitignore` at the repo root. If absent, append it using the Edit tool.

5. From this point on, all agent dispatches must use `Working directory: {WORKTREE_PATH}` instead of the current directory path.

If git is not available or not a git repo: skip Step 0.1 entirely. Set WORKTREE_PATH = current working directory. Note "No worktree created — not a git repo" in the terminal summary.

## Step 0.5: Structure Check

Skip this step entirely if the user's intent clearly matches any of these patterns (checked against the user's original message, before workflow identification):
- Init patterns: "nob init", "initialize project", "scaffold project"
- Venture patterns: "startup idea", "business idea", "I have an idea", "nob venture", "build a startup", "build a product", "build a company", "validate my idea", "launch a startup", "launch a product", "launch a company", "bring to market"
- Refactor patterns: "nob refactor", "restructure project", "migrate to nob structure", "migrate project", "refactor project structure"
- Ideation patterns: "nob ideate", "ideate", "what should I build next", "suggest features for", "what feature should I add"

If the intent matches any of these patterns, skip this step entirely.

Check for structure mismatch in this order:

1. If `.nob.yml` exists and `stack.frontend.path` is `apps/frontend/` and `stack.backend.path` is `apps/backend/` → **no mismatch**. Skip this step.
2. If the working directory is empty (no files other than `.git`/`.gitignore`) → **no mismatch**. Skip this step.
3. If `apps/frontend/` or `apps/backend/` is missing AND a recognisable source directory exists elsewhere (`frontend/`, `web/`, `client/`, `src/`, `backend/`, `server/`, `api/`) → **mismatch**.
4. If `apps/` layout is correct but `shared/core/` is absent → **partial mismatch**.

When mismatch detected, store detected dir names as DETECTED_DIRS. Print:

```
Detected project structure doesn't match nob's layout:
  Found:    [DETECTED_DIRS]
  Expected: apps/frontend/  +  apps/backend/  +  shared/core/

Refactor now before proceeding? (yes / skip)
```

Wait for user response:
- `yes` → read `{SKILL_BASE_DIR}/refactor-agent/SKILL.md`. Dispatch an Agent with `model: "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/refactor-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Detected source paths: {DETECTED_DIRS}
Stack type: unknown
Original user intent: {user's original message}
Refactor mode: mid-run
[/INPUTS]
```

Extract `[REFACTOR-AGENT OUTPUT]...[/REFACTOR-AGENT OUTPUT]`. Store as REFACTOR_OUTPUT.

If `Status: complete` in REFACTOR_OUTPUT: print "Refactor complete. Continuing with your original request..." then proceed to Step 1.
If `Status: cancelled` or `Status: failed`: proceed to Step 1 without changes. Note the skip in the terminal summary.

- `skip` or any non-yes response → set STRUCTURE_CHECK_SKIPPED = true. Proceed to Step 1 unchanged. Do not offer again in this run.

## Step 1: Read project config

Read `CLAUDE.md` at the repo root. If not found, note it and continue.

Read `.nob.yml` at the repo root using the Read tool.

If `.nob.yml` is found: use its contents as RESOLVED_CONFIG. Skip to **Extract from RESOLVED_CONFIG** below.

If `.nob.yml` is NOT found: run auto-detection to build RESOLVED_CONFIG.

### Auto-detection

**Frontend detection** (first match wins):
1. Scan for `package.json` in `apps/frontend/`, `frontend/`, `web/`, `client/`, `app/` (in that order). If found, read it and check `dependencies`:
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
1. Scan for `package.json` in `apps/backend/`, `backend/`, `server/`, `api/` (in that order). Check `dependencies` for `express`, `fastify`, `koa`, `hapi` → type `node`. Path = that directory.
2. `requirements.txt` or `pyproject.toml` in `apps/backend/` or `backend/` → type `python`, path = that directory.
3. `go.mod` in `apps/backend/` or `backend/` → type `go`, path = that directory.
4. `pom.xml` in `apps/backend/` or `backend/` → type `java`, path = that directory.
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
  enabled: [planner, pm-agent, backend-agent, frontend-agent, security-agent, reviewer, ideation-agent]
  models:
    backend-agent: sonnet
    frontend-agent: sonnet
    planner: haiku
    pm-agent: haiku
    reviewer: haiku
    security-agent: haiku
    init-agent: sonnet
    idea-framer: haiku
    market-researcher: sonnet
    business-modeler: haiku
    gtm-strategist: haiku
    financial-modeler: haiku
    venture-reviewer: haiku
    refactor-agent: sonnet
    ideation-agent: haiku
  max_parallel_slices: 3
  venture:
    enabled: true
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
| "nob init", "initialize project", "scaffold project", "init" (standalone) | Init |
| "I want to build a startup", "I want to build a product", "I want to build a company", "I have an idea", "bring to market", "startup idea", "business idea", "validate my idea", "launch a startup", "launch a product", "launch a company", "nob venture" | Venture |
| "nob refactor", "restructure project", "migrate to nob structure", "migrate project", "refactor project structure" | Refactor |
| "nob ideate", "ideate [direction]", "what should I build next", "suggest features for", "I want to add [vague goal]", "what feature should I add" | Ideate |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
> "Is this a new feature to implement, a bug to fix, an API contract sync, a business idea you'd like to validate, a project to restructure, or feature ideation?"

Do NOT guess the workflow type. If ambiguous, ask.

If the identified workflow is `Init`, skip to the **Init workflow early exit** section immediately below before proceeding to Phase 0.

If the identified workflow is `Refactor`, skip to the **Refactor workflow early exit** section immediately below before proceeding to Phase 0.

If the identified workflow is `Ideate`, skip to the **Ideation workflow early exit** section immediately below before proceeding to Phase 0.

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

## Venture workflow early exit

If the identified workflow is `Venture`:
- Read `agents.venture.enabled` from RESOLVED_CONFIG. Default to `true` if absent.
- If `false`: print "Venture mode is disabled in `.nob.yml`. Set `agents.venture.enabled: true` to enable." and exit.
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Jump directly to the **Venture Workflow** section below.

---

## Venture Workflow

Run this section only when the identified workflow is `Venture` (routed here from the Venture early exit above).

Store the user's original message as VENTURE_IDEA.

### Checkpoint setup

Create `docs/venture/` if it does not exist: `mkdir -p docs/venture`

If `agents.checkpoint.enabled` is true:
- Run `mkdir -p {checkpoint.path}`
- Ensure `.nob/` appears in `.gitignore` at the repo root. If absent, append it using the Edit tool.
- Read `{checkpoint.path}venture-checkpoint.json` if it exists. Store as VENTURE_CHECKPOINT (null if not found or not parseable).

If `agents.checkpoint.enabled` is false: set VENTURE_CHECKPOINT to null and skip all checkpoint writes in this workflow.

Stage order: `[idea-framer, market-researcher, business-modeler, gtm-strategist, financial-modeler, venture-reviewer]`

For each stage in order: if VENTURE_CHECKPOINT has `stages.[stage-name].status: "completed"`, restore its output from `stages.[stage-name].output` and skip re-running it.

Helper — write venture checkpoint after each stage completes (only if `agents.checkpoint.enabled` is true): Read the current `{checkpoint.path}venture-checkpoint.json` (or start with `{}`), update only `stages.[stage-name]` to `{status: "completed", output: "[extracted output block]"}`, write back using the Write tool.

---

### Stage 1: Idea-Framer

Skip if VENTURE_CHECKPOINT shows `stages.idea-framer.status: "completed"`. Restore IDEA_FRAMER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/idea-framer/SKILL.md`. Dispatch with `model: agents.models["idea-framer"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/idea-framer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea: {VENTURE_IDEA}
[/INPUTS]
```

Extract `[IDEA-FRAMER OUTPUT]...[/IDEA-FRAMER OUTPUT]`. Store as IDEA_FRAMER_OUTPUT.

Write venture checkpoint for stage `idea-framer`.

---

### Stage 2: Market-Researcher

Skip if VENTURE_CHECKPOINT shows `stages.market-researcher.status: "completed"`. Restore MARKET_RESEARCHER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/market-researcher/SKILL.md`. Dispatch with `model: agents.models["market-researcher"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/market-researcher/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Problem: {Problem field from IDEA_FRAMER_OUTPUT}
[/INPUTS]
```

Extract `[MARKET-RESEARCHER OUTPUT]...[/MARKET-RESEARCHER OUTPUT]`. Store as MARKET_RESEARCHER_OUTPUT.

**Soft review**: if `Flag:` in MARKET_RESEARCHER_OUTPUT is not `none`, print the flag message to the user. Then print: "Research complete. Continuing to business modeling..."

Write venture checkpoint for stage `market-researcher`.

---

### Stage 3: Business-Modeler

Skip if VENTURE_CHECKPOINT shows `stages.business-modeler.status: "completed"`. Restore BUSINESS_MODELER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/business-modeler/SKILL.md`. Dispatch with `model: agents.models["business-modeler"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/business-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Market research summary: {MARKET_RESEARCHER_OUTPUT}
Chosen revenue model:
[/INPUTS]
```

Note: `Chosen revenue model:` is left blank — the Business-Modeler agent contains its own hard pause and will ask the founder.

Extract `[BUSINESS-MODELER OUTPUT]...[/BUSINESS-MODELER OUTPUT]`. Store as BUSINESS_MODELER_OUTPUT.

Write venture checkpoint for stage `business-modeler`.

---

### Stage 4: GTM-Strategist

Skip if VENTURE_CHECKPOINT shows `stages.gtm-strategist.status: "completed"`. Restore GTM_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/gtm-strategist/SKILL.md`. Dispatch with `model: agents.models["gtm-strategist"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/gtm-strategist/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Priority channels:
[/INPUTS]
```

Note: `Priority channels:` is left blank — the GTM-Strategist agent contains its own hard pause and will ask the founder.

Extract `[GTM-STRATEGIST OUTPUT]...[/GTM-STRATEGIST OUTPUT]`. Store as GTM_OUTPUT.

Write venture checkpoint for stage `gtm-strategist`.

---

### Stage 5: Financial-Modeler

Skip if VENTURE_CHECKPOINT shows `stages.financial-modeler.status: "completed"`. Restore FINANCIAL_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/financial-modeler/SKILL.md`. Dispatch with `model: agents.models["financial-modeler"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/financial-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Key assumptions: {Key assumptions field from BUSINESS_MODELER_OUTPUT}
North star metric: {North star metric field from GTM_OUTPUT}
Month 3 target: {Month 3 target field from GTM_OUTPUT}
[/INPUTS]
```

Extract `[FINANCIAL-MODELER OUTPUT]...[/FINANCIAL-MODELER OUTPUT]`. Store as FINANCIAL_OUTPUT.

**Soft review**: if `Flag:` in FINANCIAL_OUTPUT is not `none`, print the flag message to the user. Then print: "Financial modeling complete. Running venture review..."

Write venture checkpoint for stage `financial-modeler`.

---

### Stage 6: Venture-Reviewer

Skip if VENTURE_CHECKPOINT shows `stages.venture-reviewer.status: "completed"`. Restore REVIEWER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/venture-reviewer/SKILL.md`. Dispatch with `model: agents.models["venture-reviewer"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/venture-reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea framer output: {IDEA_FRAMER_OUTPUT}
Market researcher output: {MARKET_RESEARCHER_OUTPUT}
Business modeler output: {BUSINESS_MODELER_OUTPUT}
GTM strategist output: {GTM_OUTPUT}
Financial modeler output: {FINANCIAL_OUTPUT}
[/INPUTS]
```

Extract `[VENTURE-REVIEWER OUTPUT]...[/VENTURE-REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT.

Write venture checkpoint for stage `venture-reviewer`.

---

### Dev pipeline handoff

Read `needs_dev:` from REVIEWER_OUTPUT.

If reviewer `Status: FAIL`:
- Print: "Venture review found critical issues. Please address them before proceeding to technical implementation:"
- Print each item from the `Issues:` list in REVIEWER_OUTPUT.
- Jump to Venture terminal summary.

If `needs_dev: false`:
- Print: "No technical implementation needed for this venture type."
- Jump to Venture terminal summary.

If `needs_dev: true` and status is `PASS` or `NEEDS WORK`:
- Print: "Venture pipeline complete. Artifacts saved to `docs/venture/`. Ready to move into technical implementation? (yes / not yet)"
- Wait for response.
- If **yes**: Print: "Run `/nob docs/venture/venture-spec.md` to start technical implementation." Then jump to Venture terminal summary and exit. The user's next `/nob` invocation will detect `Spec → Code` workflow and run the full dev pipeline.
- If **not yet**: jump to Venture terminal summary and exit.

---

### Venture terminal summary

Print this block:

```
─────────────────────────────────────
  Nob Venture Pipeline — Complete
─────────────────────────────────────

Idea: {Problem field from IDEA_FRAMER_OUTPUT}

Stage results:
  Idea Frame       ✓  docs/venture/idea-frame.md
  Market Research  ✓  docs/venture/market-research.md
  Business Model   ✓  docs/venture/business-model.md
  GTM Strategy     ✓  docs/venture/gtm-strategy.md
  Financial Model  ✓  docs/venture/financial-model.md
  Venture Review   {Status from REVIEWER_OUTPUT}

Venture Spec: docs/venture/venture-spec.md
{if needs_dev: false: "No technical implementation needed."}
{if status FAIL: "Critical issues found — see above before continuing."}

Checkpoint: {checkpoint.path}venture-checkpoint.json
When done: rm {checkpoint.path}venture-checkpoint.json
─────────────────────────────────────
```

---

## Refactor workflow early exit

If the identified workflow is `Refactor`:
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Read `{SKILL_BASE_DIR}/refactor-agent/SKILL.md`.
- Dispatch an Agent with `model: agents.models["refactor-agent"] ?? "sonnet"` and this prompt:

    [INSTRUCTIONS]
    {full contents of {SKILL_BASE_DIR}/refactor-agent/SKILL.md}
    [/INSTRUCTIONS]

    [INPUTS]
    Working directory: {current working directory path}
    Detected source paths: unknown
    Stack type: unknown
    Original user intent: {user's original message}
    Refactor mode: explicit
    [/INPUTS]

- Extract `[REFACTOR-AGENT OUTPUT]...[/REFACTOR-AGENT OUTPUT]` from the result. Store as REFACTOR_OUTPUT.
- Jump directly to Step 4 (Print terminal summary) using the Refactor terminal summary format.

## Ideation workflow early exit

If the identified workflow is `Ideate`:
- Skip Phase 0, Phase 1, Phase 2, Phase 2.5, and Phase 3 entirely.
- Parse the user's direction from the message: strip trigger phrases like "nob ideate", "ideate", "what should I build next", "suggest features for", "what feature should I add". The remaining text is the direction. If nothing remains, direction = "general improvements".
- Parse constraints from the message (explicit flags `--simple`, `--no-new-deps`, `--mobile-first`, `--backend-only`, `--frontend-only`; natural language "keep it simple", "no new dependencies", "mobile only", "backend only", "frontend only"). Store as a plain string, empty if none.
- Read `{SKILL_BASE_DIR}/ideation-agent/SKILL.md`.
- Dispatch an Agent with `model: agents.models["ideation-agent"] ?? "haiku"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/ideation-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Direction: {parsed direction}
Constraints: {parsed constraints, or: none}
[/INPUTS]
```

- Extract `[IDEATION-AGENT OUTPUT]...[/IDEATION-AGENT OUTPUT]` from the result. Store as IDEATION_OUTPUT.
- If extraction fails: re-dispatch once with the same prompt. If still missing: print raw agent output and stop.
- Jump directly to Step 4 (Print terminal summary) using the Ideation terminal summary format.

---

## Output Block Validation Procedure

After extracting any `[X OUTPUT]...[/X OUTPUT]` block from an agent result, apply this procedure before passing the output to the next agent. The required fields per agent are:

| Agent | Required fields |
|---|---|
| Planner | `Workflow:`, `Mode:`, `Affected layers:`, `Risks:`, `Ambiguities:` |
| PM Agent | `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:` |
| Backend Agent | `Files changed:`, `New API contracts:`, `Items not implemented (needs human):`, `Deferred items:`, `Test results:`, `Test output:` |
| Frontend Agent | `Files changed:`, `API endpoints consumed:`, `Items not implemented (needs human):`, `Deferred items:`, `Test results:`, `Test output:` |
| Security Agent | `Status:`, `Findings:` |
| Reviewer | `Overall status:`, `Test results:`, `Criteria check:`, `Items for human review:` |

**Validation steps:**
1. Check that every required field for this agent appears as `FieldName:` on its own line within the extracted block.
2. If all required fields are present: proceed normally.
3. If any required field is missing:
   - Re-dispatch the agent once, prepending to the original prompt:
     > "Your previous response was missing these required fields: [list the missing fields].
     > Re-emit the complete [X OUTPUT] block with ALL required fields present.
     > Do not omit any field even if its value is 'none' or 'n/a'."
4. If still missing after re-dispatch: mark the agent/slice status as `malformed`. Do not pass a malformed block to downstream agents. Treat `malformed` the same as `failed` for all pipeline flow decisions.

Apply this procedure after every agent dispatch in Phases 1, 2, 2.5, and 3.

---

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
4. If `worktree_path` is set in the checkpoint: restore `WORKTREE_PATH` from it. If the path does not exist on disk, re-create the worktree: run `git worktree add {worktree_path} {worktree_branch}`.

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

Extract `[PLAN OUTPUT]...[/PLAN OUTPUT]` from the result. Store as PLAN_OUTPUT. Apply the **Output Block Validation Procedure** for Planner before proceeding.

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
  "run_id": "{run-id derived in Step 0.1}",
  "worktree_path": "{WORKTREE_PATH}",
  "worktree_branch": "{WORKTREE_BRANCH}",
  "workflow": "{workflow value from PLAN_OUTPUT}",
  "source": "{source file path}",
  "phases_completed": ["phase1"],
  "slices": {
    "{slice-name}": { "status": "pending", "timed_out_at": null, "pm_output": null, "backend_output": null, "frontend_output": null }
  },
  "reviewer_output": null
}
```
One entry per slice in the `slices` object.

---

## Phase 2: Parallel pipelines

### Single-slice path (Mode: single)

Run PM Agent first (sequential), then Backend Agent and Frontend Agent concurrently. Skip conditions for each agent are unchanged.

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

Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

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

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
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

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Store as FRONTEND_OUTPUT.

---

Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]

Proceed to Phase 2.5.

---

### Fan-out path (Mode: fan-out)

Read these sub-skill files once and store their full contents:
- `{SKILL_BASE_DIR}/../pm-agent/SKILL.md` → PM_SKILL
- `{SKILL_BASE_DIR}/backend-agent/SKILL.md` → BACKEND_SKILL
- `{SKILL_BASE_DIR}/frontend-agent/SKILL.md` → FRONTEND_SKILL

Filter SLICES to only those with `status: pending` or `status: in_progress` (skip `status: completed` — their outputs are already in the checkpoint).

Group pending SLICES into batches of `max_parallel_slices`. For each batch:

**Dispatch all slices in the batch by calling the Agent tool once per slice, all within the same assistant turn — do not await any Agent call result before making the next Agent call.** All N Agent calls for the batch must appear in the same response. This is what enables parallel execution. Each slice gets this prompt (use `model: agents.models["backend-agent"] ?? "sonnet"` — slice agents do implementation work):

```
[INSTRUCTIONS]
You are a Nob slice runner. Execute a complete PM → (Backend+Frontend concurrent) pipeline for one slice of a larger feature. The Agent tool is available to you — use it to dispatch Backend and Frontend as concurrent sub-agents.

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

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
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

SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
[/INPUTS]
```

After both Agent calls return:
- Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]` from Backend's response. Store as BACKEND_OUTPUT.
- Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]` from Frontend's response. Store as FRONTEND_OUTPUT.

After both steps complete, wrap all three output blocks in `[SLICE OUTPUT: {slice-name}]...[/SLICE OUTPUT: {slice-name}]`.

Stack skip rules (from the `.nob.yml contents` field in your [INPUTS]) apply:
- If `stack.backend.enabled: false`: skip Backend Agent dispatch; set BACKEND_OUTPUT = `"Backend agent was skipped (disabled in config)"`; emit `[BACKEND-AGENT OUTPUT]Backend agent was skipped (disabled in config)[/BACKEND-AGENT OUTPUT]`.
- If workflow is `API→Sync`: skip Backend Agent dispatch; set BACKEND_OUTPUT = `"Backend agent was skipped (API→Sync workflow — backend already changed)"`; emit `[BACKEND-AGENT OUTPUT]Backend agent was skipped (API→Sync workflow — backend already changed)[/BACKEND-AGENT OUTPUT]`.
- If `stack.frontend.enabled: false`: skip Frontend Agent dispatch; set FRONTEND_OUTPUT = `"Frontend agent was skipped (disabled in config)"`; emit `[FRONTEND-AGENT OUTPUT]Frontend agent was skipped (disabled in config)[/FRONTEND-AGENT OUTPUT]`.

--- PM AGENT INSTRUCTIONS ---
{PM_SKILL}
--- END PM AGENT INSTRUCTIONS ---

--- BACKEND AGENT INSTRUCTIONS ---
{BACKEND_SKILL}
--- END BACKEND AGENT INSTRUCTIONS ---

--- FRONTEND AGENT INSTRUCTIONS ---
{FRONTEND_SKILL}
--- END FRONTEND AGENT INSTRUCTIONS ---

After all agents complete, wrap all three output blocks inside:
[SLICE OUTPUT: {slice-name}]
...all three output blocks concatenated here...
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
- Otherwise: SLICE_RESULTS is now fully populated from in-memory accumulation during dispatch. Proceed to Phase 2.5.

---

## Phase 2.5: Security review

If `security-agent` is not in `agents.enabled`: set SECURITY_OUTPUT = "[SECURITY-DISABLED]" and skip the rest of this phase. Proceed to Phase 3.

**Prepare Security Agent input:**

If Mode: single — BACKEND_OUTPUT and FRONTEND_OUTPUT are already in context from Phase 2. Pass them directly.

If Mode: fan-out — construct MERGED_OUTPUTS by concatenating all SLICE OUTPUT blocks from SLICE_RESULTS:
```
[MERGED SLICE OUTPUTS]
{all SLICE OUTPUT blocks from SLICE_RESULTS concatenated}
[/MERGED SLICE OUTPUTS]
```

**Dispatch Security Agent:**

Read `{SKILL_BASE_DIR}/security-agent/SKILL.md`. Dispatch with `model: agents.models["security-agent"] ?? "haiku"`:

For Mode: single:
```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/security-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

[BACKEND-AGENT OUTPUT]
{BACKEND_OUTPUT}
[/BACKEND-AGENT OUTPUT]

[FRONTEND-AGENT OUTPUT]
{FRONTEND_OUTPUT}
[/FRONTEND-AGENT OUTPUT]
[/INPUTS]
```

For Mode: fan-out:
```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/security-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

{MERGED_OUTPUTS block}
[/INPUTS]
```

Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT. Apply the **Output Block Validation Procedure** for Security Agent before proceeding.

**Apply severity gate:**

Check SECURITY_OUTPUT for any `[CRITICAL]` lines.

If one or more `[CRITICAL]` lines are present:
1. Count them as N.
2. Print each critical finding to the user.
3. Print: "Security Agent found N critical issue(s) listed above. Fix and re-run, or skip security check? (fix / skip)"
4. Wait for user response.
   - `fix` or any non-skip response: exit. Print "Fix the issues above and re-run `/nob` to continue." Do not proceed to Phase 3.
   - `skip`: set SECURITY_OUTPUT = "[SECURITY-SKIPPED]". Print "Security check skipped — findings will be noted in the Reviewer report." Proceed to Phase 3.

If no `[CRITICAL]` lines: proceed to Phase 3 with SECURITY_OUTPUT as-is.

---

## Phase 3: Merge review

**Prepare Reviewer input:**

If Mode: single — pass outputs directly as individual labeled blocks (PM_OUTPUT, BACKEND_OUTPUT, FRONTEND_OUTPUT).

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

Security Agent output:
{SECURITY_OUTPUT}
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

Security Agent output:
{SECURITY_OUTPUT}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply the **Output Block Validation Procedure** for Reviewer before proceeding.

**Write final checkpoint** (if checkpoint.enabled):
Update `{checkpoint.path}checkpoint.json` — set `reviewer_output` to the full REVIEWER_OUTPUT string. Write using the Write tool.

---

## Phase 3.5: Targeted retry

Note: the Security Agent is not re-dispatched during retry. SECURITY_OUTPUT from Phase 2.5 carries through to the second Reviewer run unchanged — the retry fixes spec compliance failures, not security findings.

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

**If workflow is `Venture`**: summary is printed inline in the `## Venture Workflow` section above. This section is not reached for Venture runs.

**If workflow is `Ideate`**, use this summary:

```
Nob ideation complete.

Direction:   [Direction field from IDEATION_OUTPUT]
Constraints: [Constraints field from IDEATION_OUTPUT]
Ideas:       [Ideas generated field from IDEATION_OUTPUT]
Chosen:      [Chosen field from IDEATION_OUTPUT]
Spec:        [Spec saved field from IDEATION_OUTPUT]

[if Spec saved is not "n/a":]
Next: /nob implement [Spec saved field from IDEATION_OUTPUT]
```

**If workflow is `Refactor`**, use this summary. Populate each field from the corresponding field in REFACTOR_OUTPUT. Mark ✓ for success/created, ✗ for failed.

```
Nob refactor complete.

Moves:       [for each move in REFACTOR_OUTPUT Moves field, print one line:
             "{from} → {to}: ✓" or "{from} → {to}: ✗"]
             [if no moves: "None"]
Shared:      shared/core/             [✓ if REFACTOR_OUTPUT Shared is "created", ✗ otherwise]
Imports rewritten: [N from REFACTOR_OUTPUT "Imports rewritten:" field]
Config:      CLAUDE.md                  ✓ | ✗
             .nob.yml                   ✓ | ✗

[if move or import warnings in REFACTOR_OUTPUT:]
Manual review needed:
  [list warnings from REFACTOR_OUTPUT Move warnings and Import warnings fields]

Next: /nob implement docs/specs/your-feature.md
```

If REFACTOR_OUTPUT Status is `cancelled`: print "Refactor cancelled. No changes made." and exit.
If REFACTOR_OUTPUT Status is `failed`: print the failure details from REFACTOR_OUTPUT and exit.

**If workflow is `Init`, use this summary:**

```
Nob init complete.

Project:   [value of "Project:" field from INIT_OUTPUT]
Stack:     [value of "Frontend:" field] + [value of "Backend:" field] + [value of "Database:" field from INIT_OUTPUT]

Files created: [N]
Installs:
  [if JS/TS stack: pnpm install (root) ✓ | failed ✗]
  [if Python backend: apps/backend pip install ✓ | failed ✗]
  [if Go backend: apps/backend go mod tidy ✓ | failed ✗]
  [if Flutter frontend: apps/frontend flutter pub get ✓ | failed ✗]

[if any install failed:]
Install errors — run manually:
  [exact retry command with correct working directory]

Config written:
  CLAUDE.md
  .nob.yml

Next steps:
  1. Copy .env.example → .env in apps/frontend/ and apps/backend/ and fill in values
  2. Start backend:  [backend start command from INIT_OUTPUT]
  3. Start frontend: [frontend start command from INIT_OUTPUT]
  4. Write a spec:   docs/specs/your-feature.md
  5. Then run:       /nob implement docs/specs/your-feature.md
  6. When ready:     git push -u origin nob/init
```

If any field is unavailable (e.g. init-agent returned partial output), substitute "unknown" for that field.

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

Tests:     Backend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT] · Frontend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT]
Security:  [derive from SECURITY_OUTPUT: if "[SECURITY-DISABLED]" → "SKIPPED (disabled)", if "[SECURITY-SKIPPED]" → "SKIPPED (user)", if "Status: PASS" → "PASS", if "Status: FINDINGS" → count [MEDIUM] and [LOW] lines and print "FINDINGS: N medium, M low"]
Review status: [PASS | NEEDS REVIEW | FAIL]
[if RETRY_RAN = true: "Retry:     ran  →  Final review: [Overall status from final REVIEWER_OUTPUT]"]
[if RETRY_RAN = false and first review was not PASS: "Retry:     skipped"]
[if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]

[if any slice status is timed_out:]
Timed out:
  [slice-name]: timed out at [timed_out_at value]
  Re-run `/nob [spec-file]` to resume — checkpoint skips completed slices.

[if any slice status is malformed:]
Malformed output:
  [slice-name]: [agent-name] returned invalid output block after two attempts
  Check agent output above, then re-run `/nob [spec-file]` to retry.

[if checkpoint.enabled:]
Checkpoint: {checkpoint.path}checkpoint.json
When done: rm {checkpoint.path}checkpoint.json

Next steps:
- Review the changes above
- If items need human review, address them before committing
- When satisfied: git add -p && git commit -m "feat: <spec name>"
- Then: git push -u origin <branch-name>
```

**Worktree teardown** (run after printing the terminal summary above):

If `Overall status: PASS`:
- Run: `git -C {WORKTREE_PATH} add -A`
- Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip commit if nothing to commit)
- Run: `git worktree remove {WORKTREE_PATH}`
- Print: `Worktree committed and removed. Branch: {WORKTREE_BRANCH}`
- Print: `Next: git push -u origin {WORKTREE_BRANCH}`

If `Overall status: FAIL` or `NEEDS REVIEW`:
- Preserve the worktree for inspection.
- Print: `Worktree preserved at {WORKTREE_PATH} for inspection.`
- Print: `To clean up: git worktree remove {WORKTREE_PATH} --force`

If the run was cancelled or hit an unrecoverable error:
- Run: `git worktree remove {WORKTREE_PATH} --force`
- Print: `Run cancelled — worktree cleaned up.`

If WORKTREE_PATH equals the current working directory (git not available): skip teardown entirely.

---

## Error Handling

- **.nob.yml not found**: run auto-detection (Step 1)
- **Checkpoint file corrupted/unparseable**: warn user, start fresh run (Phase 0)
- **Sub-skill file not found**: warn "sub-skill file {SKILL_BASE_DIR}/[name]/SKILL.md not found — ensure the nob plugin is installed correctly"
- **Planner output has ambiguities**: pause and ask user before proceeding (Phase 1)
- **Slice agent returns no [SLICE OUTPUT] block**: re-dispatch that slice once; if still missing, mark `status: timed_out` (store `timed_out_at: "phase2/slice-runner"`), continue other slices, report in terminal summary (Phase 2)
- **All slices failed**: stop before Phase 3; list all failures prominently; do NOT dispatch Reviewer
- **Some slices failed, others succeeded**: Reviewer runs on successful outputs; failed slices listed prominently in terminal summary
- **Reviewer status is FAIL**: print all failing items prominently; offer one targeted retry via Phase 3.5; do NOT offer a second retry
- **Non-slice agent result missing expected output block**: re-dispatch once; if still missing after re-dispatch, mark status `timed_out` (store `timed_out_at: "<phase>/<agent-name>"`). Do NOT pass null output to downstream agents. For fan-out: skip this slice and continue remaining slices. For single mode: stop pipeline and skip Reviewer.
- **Init agent returns no [INIT-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
- **Refactor agent returns no [REFACTOR-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
- **Ideation agent returns no [IDEATION-AGENT OUTPUT] block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
