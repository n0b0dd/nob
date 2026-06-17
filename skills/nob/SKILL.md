---
name: nob
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, migrate an existing project, or build something from a rough idea. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [idea or intent]". For rough ideas with no spec file, PM Agent writes the spec first then the full pipeline runs automatically. Orchestrates PM Agent → Tech Lead Agent → Reviewer in sequence.'
---

# Nob — Hub Orchestrator

## Overview
Nob automates cross-layer development workflows in a fullstack monorepo. This hub reads the user's intent, identifies the workflow type, and invokes sub-skills in the correct sequence. Every run starts with the PM Agent and ends with the Reviewer.

Sub-skills (`/nob:tech-lead`, `/nob:dev`, `/nob:reviewer`, `/nob:init`, `/nob:refactor`, `/nob:ideation`) can be invoked directly for targeted work. When invoked via the hub, each sub-skill receives an `[INPUTS]` block with all required context and runs in hub-dispatched mode. When invoked standalone, each sub-skill sources inputs from `.nob/` output files or prompts the user.

## Agent Dispatch Model

Each sub-skill runs as an **isolated Agent tool call** — a fresh context with only its required inputs. The hub reads each sub-skill's SKILL.md file, constructs a focused prompt, dispatches via the Agent tool, and extracts only the labeled output block from the result. The hub's own context stays under ~10k tokens regardless of codebase size.

## Setup: Resolve skill base directory

Read the system context for a line starting with `Base directory for this skill:`. Extract the path and store it as SKILL_BASE_DIR. Every sub-skill path in this document is written as `{SKILL_BASE_DIR}/../X/SKILL.md` — replace `{SKILL_BASE_DIR}` with the extracted path before using the Read tool.

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

Skip this step entirely unless `.nob.yml` exists AND `structure.check: true` is explicitly set. Nob adapts to any project layout — this check is opt-in for teams that want a migration offer toward the nob monorepo layout.

Also skip if the user's intent matches any of:
- Init: "nob init", "initialize project", "scaffold project"
- Venture: "startup idea", "business idea", "I have an idea", "nob venture", "build a startup", "build a product", "build a company", "validate my idea", "launch a startup", "launch a product", "launch a company", "bring to market"
- Refactor: "nob refactor", "restructure project", "migrate to nob structure", "migrate project", "refactor project structure"
- Ideation: "nob ideate", "ideate", "what should I build next", "suggest features for", "what feature should I add"

If `structure.check: true` and intent does not match the skip patterns above, run mismatch detection:

1. If the working directory is empty (no files other than `.git`/`.gitignore`) → no mismatch. Skip.
2. If `apps/frontend/` or `apps/backend/` is missing AND a recognisable source directory exists elsewhere (`frontend/`, `web/`, `client/`, `src/`, `backend/`, `server/`, `api/`) → **mismatch**.
3. If `apps/` layout is correct but `shared/core/` is absent → **partial mismatch**.

When mismatch detected, store detected dir names as DETECTED_DIRS. Print:

```
Detected project structure doesn't match nob's layout:
  Found:    [DETECTED_DIRS]
  Expected: apps/frontend/  +  apps/backend/  +  shared/core/

Refactor now before proceeding? (yes / skip)
```

Wait for user response:
- `yes` → read `{SKILL_BASE_DIR}/../refactor/SKILL.md`. Dispatch an Agent with `model: "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../refactor/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Detected source paths: {DETECTED_DIRS}
Stack type: unknown
Original user intent: {user's original message}
Refactor mode: mid-run
[/INPUTS]
```

Extract `[REFACTOR OUTPUT]...[/REFACTOR OUTPUT]`. Store as REFACTOR_OUTPUT.

If `Status: complete` in REFACTOR_OUTPUT: print "Refactor complete. Continuing with your original request..." then proceed to Step 1.
If `Status: cancelled` or `Status: failed`: proceed to Step 1 without changes. Note the skip in the terminal summary.

- `skip` or any non-yes response → set STRUCTURE_CHECK_SKIPPED = true. Proceed to Step 1 unchanged. Do not offer again in this run.

## Step 1: Read project config

Read `CLAUDE.md` at the repo root. If not found, note it and continue.

Read `.nob.yml` at the repo root using the Read tool.

If `.nob.yml` is found: use its contents as RESOLVED_CONFIG. Skip to **Extract from RESOLVED_CONFIG** below.

If `.nob.yml` is NOT found: run auto-detection to build RESOLVED_CONFIG.

### Auto-detection

Run a broad repository scan to discover all framework manifest files:

```bash
find . \( -name "package.json" -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "go.mod" -o -name "pom.xml" -o -name "pubspec.yaml" -o -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/vendor/*" -maxdepth 5 2>/dev/null | sort
```

Also check separately: does `android/` exist? Does `ios/Podfile` exist?

**Classify each found manifest into a unit** (`{ name, type, path }`):

- `package.json` with `next` in dependencies or devDependencies → type `next`
- `package.json` with `vue` in dependencies or devDependencies → type `vue`
- `package.json` with `react` or `react-dom` in dependencies → type `react`
- `package.json` with `svelte` in dependencies → type `react` (treat as generic component framework)
- `package.json` with `express`, `fastify`, `koa`, `hapi`, or `@nestjs/core` in dependencies → type `node`
- `package.json` with no recognized framework markers → type `node`
- `requirements.txt` or `pyproject.toml` → type `python`
- `go.mod` → type `go`
- `pom.xml` or `build.gradle` or `build.gradle.kts` → type `java`
- `pubspec.yaml` → type `flutter`
- `android/` directory present → type `android`, path = `android/`
- `ios/Podfile` present → type `ios`, path = `ios/`

For each recognized manifest: `name` = the manifest file's parent directory name (e.g. `apps/frontend/package.json` → name `frontend`); `path` = that directory.

Skip workspace-root `package.json` files that contain only a `workspaces` field and no dependency markers.

**Resolve units list:**

- Each recognized manifest → one unit in the list.
- If nothing is detected at all → ask: "Could not detect your stack. Provide `path:type` pairs (e.g. `apps/api:node apps/web:react`), or press Enter to use one `generic` unit at repo root." Wait for answer. If user provides pairs: parse into units list. If Enter/empty: units = `[{ name: "root", type: "generic", path: "." }]`.

**Build RESOLVED_CONFIG** as a YAML string using detected values plus these defaults:

```yaml
units:
  - name: {detected name}
    type: {detected type}
    path: {detected path}
agents:
  enabled: [pm, tech-lead, dev, reviewer, ideation]
  models:
    dev: sonnet
    tech-lead: sonnet
    pm: haiku
    reviewer: haiku
    init: sonnet
    venture: sonnet
    refactor: sonnet
    ideation: haiku
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
- `RUN_LOG_PATH` = `{agents.checkpoint.path}run-log.tsv` — the per-run timing log. On the first append of the run, create the file (and its parent directory) if absent: `mkdir -p {agents.checkpoint.path} && touch {RUN_LOG_PATH}`. All "Append to RUN_LOG_PATH" steps below append one tab-separated line via Bash (`printf '%s\n' "<line>" >> {RUN_LOG_PATH}`), which creates the file if it does not yet exist. If the write fails, skip silently (see Error Handling H2).
- `agents.max_retries` (default: 3 if not present — maximum retry passes in Phase 3.5)
- `agents.auto_pr` (default: false if not present — set true to opt-in to automatic PR creation after Reviewer PASS)
- `DEV_MODEL_RESOLVED` = `agents.models["dev"] ?? "sonnet"`

**Unit guidance map**: compute `UNIT_GUIDANCE_MAP` from SKILL_BASE_DIR and each unit's type. For every unit in `units`:
- `UNIT_GUIDANCE_MAP[unit.name]` = `{SKILL_BASE_DIR}/../dev/stacks/{unit.type}.md`
- If `unit.type` is `generic` or unrecognized (not one of: node, python, go, java, ruby, react, vue, next, flutter, android, ios, react-native): set to `none`

**Project memory**: load structured memory in this order:

1. Check whether `.nob/project-memory.yml` exists using the Read tool.
   - If found and non-empty: parse its YAML. Extract a ≤10-line summary across the four top-level keys (`patterns`, `routes`, `file_clusters`, `corrections`). Format the summary as:
     ```
     Project memory: {N} patterns, {M} routes, {K} file clusters, {J} corrections
     Recent patterns: [up to 3 most recent pattern.summary values]
     Recent routes: [up to 3 most recent route.summary values]
     Recent corrections: [up to 3 most recent correction.summary values — these are highest priority]
     ```
     Store this summary string as PROJECT_MEMORY.
   - If not found: check whether `.nob/project-memory.md` exists.
     - If `.nob/project-memory.md` exists and is non-empty: **migrate** — parse the Markdown entries, convert to the YAML structure below, write `.nob/project-memory.yml` using the Write tool, then delete `.nob/project-memory.md` using Bash (`rm .nob/project-memory.md`). Store the summary as PROJECT_MEMORY.
     - If neither file exists: set PROJECT_MEMORY = "none".

**`--plan-only` detection**: check whether the user's message contains `--plan-only`. If found: store PLAN_ONLY = true. Otherwise: PLAN_ONLY = false.

**M3: --plan-only early exit**

If PLAN_ONLY = true:
- Dispatch PM Agent only (same prompt as Phase 2 PM dispatch below).
- Print PM_OUTPUT verbatim.
- Print: `"Plan-only run complete — PM requirements extracted. Re-run without --plan-only to execute full pipeline."`
- Exit. Do not write a checkpoint. Do not dispatch Tech Lead or any further agents.

**`--diff-only` detection**: check whether the user's message contains `--diff-only`. If found: store DIFF_PREVIEW = true. Otherwise: DIFF_PREVIEW = false.

## Step 1.5: Spec pre-flight validation

For `Spec→Code` and `Bug→Fix` workflows only (skip for Init, Venture, Refactor, Ideate, API→Sync, and `--plan-only` runs) — validate the spec before dispatching any agents:

1. **Path present**: confirm the user's message contains a file path (not empty string). If not: print `"Error: no spec file path provided. Usage: /nob implement <path-to-spec.md>"` and exit.
2. **File exists**: use the Read tool to open the spec file. If the Read tool returns an error: print `"Error: spec file not found: <path>. Check the path and try again."` and exit.
3. **File non-empty**: check that the file content length > 0 characters. If empty: print `"Error: spec file is empty: <path>."` and exit.
4. **Acceptance criteria present**: check that the file content contains `## acceptance criteria` (case-insensitive substring match). If absent: print `"Error: spec file has no ## Acceptance criteria section: <path>. Add one before running nob."` and exit.

If all four checks pass: proceed to Step 2.

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
| Plain text with no `/` and not ending in `.md`, not matching any pattern above | Idea → Spec → Code |

If the intent does not clearly match any workflow AND contains a `/` or `.md` but is not a valid path, ask ONE clarifying question before proceeding:
> "Is this a new feature to implement, a bug to fix, an API contract sync, a business idea you'd like to validate, a project to restructure, or feature ideation?"

Do NOT guess the workflow type for ambiguous path-like inputs. Plain text ideas always route to `Idea → Spec → Code` — do not ask.

If the identified workflow is `Init`, skip to the **Init workflow early exit** section immediately below before proceeding to Phase 0.

If the identified workflow is `Refactor`, skip to the **Refactor workflow early exit** section immediately below before proceeding to Phase 0.

If the identified workflow is `Ideate`, skip to the **Ideation workflow early exit** section immediately below before proceeding to Phase 0.

## Init workflow early exit

If the identified workflow is `Init`:
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Do not read or check for a checkpoint file.
- Read `{SKILL_BASE_DIR}/../init/SKILL.md`.
- Dispatch an Agent with `model: agents.models["init"] ?? "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../init/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
User intent: {user's original message}
[/INPUTS]
```

- Extract `[INIT OUTPUT]...[/INIT OUTPUT]` from the result. Store as INIT_OUTPUT.
- Jump directly to Step 4 (Print terminal summary) using the Init terminal summary format below.

## Venture workflow early exit

If the identified workflow is `Venture`:
- Read `agents.venture.enabled` from RESOLVED_CONFIG. Default to `true` if absent.
- If `false`: print "Venture mode is disabled in `.nob.yml`. Set `agents.venture.enabled: true` to enable." and exit.
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Read `{SKILL_BASE_DIR}/../venture/SKILL.md`.
- Dispatch an Agent with `model: agents.models["venture"] ?? "sonnet"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../venture/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Venture idea: {user's original message}
Checkpoint path: {agents.checkpoint.path, or: .nob/}
Checkpoint enabled: {agents.checkpoint.enabled, or: true}
[/INPUTS]
```

- Extract `[VENTURE OUTPUT]...[/VENTURE OUTPUT]` from the result. Print the block verbatim as the terminal summary.
- Exit.

---

## Refactor workflow early exit

If the identified workflow is `Refactor`:
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Read `{SKILL_BASE_DIR}/../refactor/SKILL.md`.
- Dispatch an Agent with `model: agents.models["refactor"] ?? "sonnet"` and this prompt:

    [INSTRUCTIONS]
    {full contents of {SKILL_BASE_DIR}/../refactor/SKILL.md}
    [/INSTRUCTIONS]

    [INPUTS]
    Working directory: {current working directory path}
    Detected source paths: unknown
    Stack type: unknown
    Original user intent: {user's original message}
    Refactor mode: explicit
    [/INPUTS]

- Extract `[REFACTOR OUTPUT]...[/REFACTOR OUTPUT]` from the result. Store as REFACTOR_OUTPUT.
- Jump directly to Step 4 (Print terminal summary) using the Refactor terminal summary format.

## Ideation workflow early exit

If the identified workflow is `Ideate`:
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Parse direction: strip trigger phrases ("nob ideate", "ideate", "what should I build next", "suggest features for", "what feature should I add"). Remaining text = direction; default = "general improvements".
- Parse constraints: flags `--simple`, `--no-new-deps`, `--mobile-first`, `--backend-only`, `--frontend-only` or natural language equivalents. Store as a plain string, empty if none.
- Read `{SKILL_BASE_DIR}/../ideation/SKILL.md`.
- Dispatch an Agent with `model: agents.models["ideation"] ?? "haiku"` and this prompt:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../ideation/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Direction: {parsed direction}
Constraints: {parsed constraints, or: none}
Current date: {today's date in YYYY-MM-DD format}
[/INPUTS]
```

- Extract `[IDEATION OUTPUT]...[/IDEATION OUTPUT]` from the result. Store as IDEATION_OUTPUT.
- If extraction fails: re-dispatch once with the same prompt. If still missing: print raw agent output and stop.
- Jump directly to Step 4 (Print terminal summary) using the Ideation terminal summary format.

## Idea → Spec → Code workflow

If the identified workflow is `Idea → Spec → Code`:

1. Read `{SKILL_BASE_DIR}/../pm/SKILL.md`.
2. Dispatch PM Agent with `model: agents.models["pm"] ?? "haiku"` in spec-writing mode:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Hub dispatch: spec-writing
Working directory: {current working directory path}
Idea: {user's original message}
[/INPUTS]
```

3. Extract `[PM SPECWRITER OUTPUT]...[/PM SPECWRITER OUTPUT]` from the result.
   - If extraction fails: print `"PM agent did not produce a spec file path — cannot continue. Run \`/nob:pm <idea>\` directly to debug."` and exit.
4. Extract the `Spec file:` line from `[PM SPECWRITER OUTPUT]`. Store the value as SOURCE_FILE.
5. If `checkpoint.enabled` is true: write initial checkpoint with `spec_path: {SOURCE_FILE}` before proceeding.
6. Continue to **Step 1.5** using SOURCE_FILE as the spec file path. From this point forward treat the run as a `Spec → Code` workflow.

---

## Output Block Validation Procedure

After extracting any `[X OUTPUT]...[/X OUTPUT]` block from an agent result, apply this procedure before passing the output to the next agent. The required fields per agent are:

| Agent | Required fields |
|---|---|
| Tech Lead | `Affected units:`, `Interfaces written:`, `Task count:`, `Risks:` |
| PM Agent | `Changes needed:`, `Acceptance criteria:` |
| Dev Agent | `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:` |
| Reviewer | `Overall status:`, `Test results:`, `Criteria check:`, `Items for human review:`, `Code quality:` |

**Validation steps:**
1. Check that every required field for this agent appears as `FieldName:` on its own line within the extracted block.
2. If all required fields are present: proceed normally.
3. If any required field is missing:
   - Re-dispatch the agent once, prepending to the original prompt:
     > "Your previous response was missing these required fields: [list the missing fields].
     > Re-emit the complete [X OUTPUT] block with ALL required fields present.
     > Do not omit any field even if its value is 'none' or 'n/a'."
4. If still missing after re-dispatch: mark the agent status as `malformed`. Do not pass a malformed block to downstream agents. Treat `malformed` the same as `failed` for all pipeline flow decisions.

Apply this procedure after every agent dispatch in Phases 1, 2, 2.5, and 3.

---

## Phase 0: Resume scan

If `agents.checkpoint.enabled` is false, skip this phase entirely and proceed to Phase 1.

Check whether `{checkpoint.path}checkpoint.json` exists using the Read tool.

If the file does not exist or cannot be read: proceed to Phase 1 as a fresh run.

If the file exists and is valid JSON:
0. **Spec binding check** (Spec→Code and Bug→Fix workflows only — skip for Init, Venture, Refactor, Ideate, Ask):
   - If checkpoint has a `spec_path` field AND the identified workflow is `Idea → Spec → Code`: this is a resumed idea run — the spec was already written. Set `SOURCE_FILE = checkpoint.spec_path`, set `WORKFLOW_OVERRIDE = "Spec→Code"`, and skip the `Idea → Spec → Code` dispatch block entirely. Continue resume as a `Spec → Code` run using `SOURCE_FILE`.
   - If checkpoint has a `spec_path` field AND it does not match the current spec file path: print `"Warning: checkpoint is for \`{checkpoint.spec_path}\`, not \`{current spec path}\` — starting fresh run."` Treat the checkpoint as absent. Proceed to Phase 2 as a fresh run.
   - If checkpoint has no `spec_path` field (legacy format): proceed with resume as normal.
1. If `reviewer_output` is non-null → run is already complete. Print the terminal summary using stored outputs and exit. Do not re-run any agents.
2. If `"phase1"` is in `phases_completed` → skip Phase 1 dispatch. Restore the task list from the checkpoint `tasks` map. For each task (keyed by task id):
   - `status: completed` → inject as completed; skip re-running in Phase 2
   - `status: in_progress` → treat as pending; re-run in Phase 2 (partial output not trusted)
   - `status: pending` → run normally in Phase 2
3. If `phases_completed` is empty → proceed to Phase 1 as normal.
4. If `worktree_path` is set in the checkpoint: restore `WORKTREE_PATH` from it. If the path does not exist on disk, re-create the worktree: run `git worktree add {worktree_path} {worktree_branch}`.

If the file exists but cannot be parsed as valid JSON: print "Warning: checkpoint file is corrupted — starting fresh run." Proceed to Phase 1 without resume.

---

## Phase 1: (retired — Planner merged into Tech Lead)

Planner is no longer dispatched as a separate phase. Tech Lead reads the spec directly and produces the plan as part of its technical specification step.

Proceed directly to Phase 2.

---

## Phase 2: Tech Lead → dev pipeline

**Initial checkpoint write** (if `checkpoint.enabled` is true and no checkpoint file exists yet — fresh run only):
Write `{checkpoint.path}checkpoint.json` with:
```json
{ "spec_path": "{spec file path}", "worktree_path": "{WORKTREE_PATH}", "worktree_branch": "{WORKTREE_BRANCH}", "phases_completed": [], "tasks": {} }
```
Skip this write if the checkpoint file already exists (resume run — Phase 0 already loaded it).

**Agent 1 — PM Agent**

Run `date +%s` via the Bash tool and store as PM_START_EPOCH.

Read `{SKILL_BASE_DIR}/../pm/SKILL.md`. Dispatch with `model: agents.models["pm"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

Project memory:
{PROJECT_MEMORY}
[/INPUTS]
```

Extract `[PM OUTPUT]...[/PM OUTPUT]`. Store as PM_OUTPUT. Apply the **Output Block Validation Procedure** for PM Agent before proceeding.

Run `date +%s` and store as PM_END_EPOCH. Compute PM_DURATION_MS = (PM_END_EPOCH - PM_START_EPOCH) × 1000. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  pm              {model}  OK    {PM_DURATION_MS}ms`.

---

**Agent 2 — Tech Lead Agent**

Run `date +%s` via the Bash tool and store as TL_START_EPOCH.

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch with `model: agents.models["tech-lead"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../tech-lead/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

Unit guidance map:
{for each entry in UNIT_GUIDANCE_MAP: "  {name}: {path-or-none}"}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

PM Agent output:
{PM_OUTPUT}

Project memory:
{PROJECT_MEMORY}

Agent models:
  dev: {DEV_MODEL_RESOLVED}

Max parallel slices: {agents.max_parallel_slices}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]...[/TECH LEAD OUTPUT]`. Store as TECH_LEAD_OUTPUT. Apply Output Block Validation for Tech Lead.
Extract `[DEV OUTPUT]...[/DEV OUTPUT]`. Store as DEV_OUTPUT.

If DEV_OUTPUT is missing: re-dispatch Tech Lead once with the same prompt. If still missing after re-dispatch: mark as `failed`; stop pipeline.

Set IMPL_OUTPUT = DEV_OUTPUT.

Run `date +%s` and store as TL_END_EPOCH. Compute TL_DURATION_MS = (TL_END_EPOCH - TL_START_EPOCH) × 1000. Append to RUN_LOG_PATH:
```
{date -u +%FT%TZ}  tech-lead       {model}  OK    {TL_DURATION_MS}ms
{date -u +%FT%TZ}  dev             {DEV_MODEL_RESOLVED}  OK    {TL_DURATION_MS}ms
```

Proceed to Phase 3.

---


## Phase 3: Review

**Dispatch Reviewer agent:**

Run `date +%s` and store as REVIEWER_START_EPOCH.

Read `{SKILL_BASE_DIR}/../reviewer/SKILL.md`. Dispatch with `model: agents.models["reviewer"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {working directory path}
Spec file path: {spec file path}
Spec file contents:
{spec file content}

All agent outputs for review:

{TECH_LEAD_OUTPUT}

{PM_OUTPUT}

{DEV_OUTPUT}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply the **Output Block Validation Procedure** for Reviewer before proceeding.

Run `date +%s` and store as REVIEWER_END_EPOCH. Compute REVIEWER_DURATION_MS = (REVIEWER_END_EPOCH - REVIEWER_START_EPOCH) × 1000. Read checkpoint, set `agents["reviewer"] = { "model": "{resolved reviewer model}", "started_at": "{REVIEWER_START_EPOCH}", "duration_ms": REVIEWER_DURATION_MS, "error": null }`, write back. Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  reviewer        {model}  OK    {REVIEWER_DURATION_MS}ms`.

**Write final checkpoint** (if checkpoint.enabled):
Update `{checkpoint.path}checkpoint.json` — set `reviewer_output` to the full REVIEWER_OUTPUT string. Write using the Write tool.

---

## Phase 3.5: Retry loop

Initialize: RETRY_COUNT = 0. PREV_RETRY_ITEMS = []. RETRY_RAN = false.

--- Loop start ---

Read `Overall status:` from REVIEWER_OUTPUT.

If `Overall status: PASS`: exit loop. Proceed to Step 4.

Collect RETRY_ITEMS = all `✗` criterion lines, all `⚠` criterion lines, and all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

**Stuck check** (skip when RETRY_COUNT == 0):
If RETRY_COUNT > 0 AND RETRY_ITEMS is identical to PREV_RETRY_ITEMS:
  Set RETRY_RAN = true.
  Print:
  ```
  Retry stuck — same N failure(s) appeared in two consecutive passes:
    [RETRY_ITEMS listed one per line]
  Human review required before continuing.
  ```
  Exit loop. Proceed to Step 4.

**Max retries check:**
If RETRY_COUNT >= MAX_RETRIES:
  Set RETRY_RAN = true.
  Print:
  ```
  Max retries (MAX_RETRIES) reached. Human review required.
  ```
  Exit loop. Proceed to Step 4.

**Determine which tasks to re-dispatch:**

Extract from REVIEWER_OUTPUT:
- For each `✗` or `⚠` criterion line: extract the failing task id (e.g. `[api]`, `[web]`, `[cli]`) noted on that line or in the `Test results:` per-unit list. Collect the set of failing task ids as FAILING_TASK_IDS.
- Any CONTRACT VIOLATION in contract check → add all affected unit ids to FAILING_TASK_IDS; also set CONTRACT_RETRY = true.

If FAILING_TASK_IDS is empty: no failing task ids identified — no agent can auto-fix the remaining items. Exit loop. Proceed to Step 4.

**User gate:**

If RETRY_COUNT == 0:
  Print:
  ```
  Reviewer found N item(s) — auto-fixing (pass 1/MAX_RETRIES):
    [RETRY_ITEMS listed one per line]
  ```
  (No user prompt — proceed automatically.)
Else:
  Print:
  ```
  Still failing after pass RETRY_COUNT/MAX_RETRIES:
    [RETRY_ITEMS listed one per line]

  Retry again? (yes / no)
  ```
  Wait for user response.
  If `no` or any non-yes response: exit loop. Proceed to Step 4.

Set PREV_RETRY_ITEMS = RETRY_ITEMS.
Set RETRY_RAN = true.

**Retry diagnostic** (haiku, runs before retry agents):

Dispatch a sub-agent with `model: haiku`:

```
[INSTRUCTIONS]
You are a focused retry diagnostic agent. Read the provided file lists. For each failing item, identify which 1–2 files are most directly responsible. Do NOT implement anything. Do NOT read any file not listed in the inputs.

Emit exactly:

[RETRY-DIAGNOSTIC OUTPUT]
Fix scope per unit:
  [{unit-name}]:
    - {path}: {one sentence — what specifically needs to change}
  (repeat for each failing unit; use "none" if no specific file identified for a unit)

Root cause summary: {1–2 sentences}
[/RETRY-DIAGNOSTIC OUTPUT]
[/INSTRUCTIONS]

[INPUTS]
Failing items:
{RETRY_ITEMS listed one per line}

Failing task ids / units:
{FAILING_TASK_IDS listed one per line}

Files changed per unit from previous pass:
{for each unit in DEV_OUTPUT "Files changed:" grouped by unit tag [unit]: list paths, or: none}
[/INPUTS]
```

Extract `[RETRY-DIAGNOSTIC OUTPUT]...[/RETRY-DIAGNOSTIC OUTPUT]`. Store as DIAG_OUTPUT. If extraction fails: DIAG_OUTPUT = null (does not block retry).

**Parse fix scope:**
- If DIAG_OUTPUT non-null: extract `Fix scope per unit:` as UNIT_FIX_SCOPE map (unit name → list of paths). Units not listed → null fix scope.
- If DIAG_OUTPUT null: UNIT_FIX_SCOPE = {} (empty map).

**Tech Lead retry** (re-dispatches only failing tasks):

Read `{SKILL_BASE_DIR}/../tech-lead/SKILL.md`. Dispatch Tech Lead with `model: agents.models["tech-lead"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../tech-lead/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

Per-unit stack-guidance path map: {UNIT_GUIDANCE_MAP}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

PM Agent output:
{PM_OUTPUT}

Reviewer found these failures — re-implement only the failing tasks:
{RETRY_ITEMS listed one per line}

Failing task ids to re-implement:
{FAILING_TASK_IDS listed one per line}

{if UNIT_FIX_SCOPE non-empty:
Fix scope per unit (touch only these files):
{for each unit in UNIT_FIX_SCOPE: "  [{unit}]:\n    - {paths listed one per line}"}
}

Root cause (from diagnostic):
{DIAG_OUTPUT "Root cause summary:" line, or: "Diagnostic not available — use your judgment"}

Project memory:
{PROJECT_MEMORY}

Agent models:
  dev: {DEV_MODEL_RESOLVED}

Max parallel slices: {agents.max_parallel_slices}
[/INPUTS]
```

Extract `[TECH LEAD OUTPUT]` and `[DEV OUTPUT]`. Replace TECH_LEAD_OUTPUT and DEV_OUTPUT with results.

**After retry agents return:** Re-dispatch Reviewer using the same prompt structure as Phase 3. Extract new REVIEWER_OUTPUT. If checkpoint.enabled: update `reviewer_output` in checkpoint.json. Increment RETRY_COUNT. Go to Loop start.

--- Loop end ---

---

## Step 4: Print terminal summary

**If workflow is `Venture`**: the venture sub-agent prints its own summary before exiting. This section is not reached for Venture runs.

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

If any field is unavailable (e.g. init returned partial output), substitute "unknown" for that field.

**For all other workflows:**

```
Nob complete.

Workflow:  [Spec→Code | Bug→Fix | API→Sync]
Source:    [spec/bug file path]
Agents:    [each agent that ran as "name(model)" separated by " · " — e.g.: pm(haiku) · tech-lead(sonnet) · dev({DEV_MODEL_RESOLVED}) · reviewer(haiku). List only agents that actually ran; skip disabled/skipped agents. Use DEV_MODEL_RESOLVED for the dev agent.]
Timing:    [each agent that ran as "name Ns" separated by " · " — e.g.: pm 3s · tech-lead 18s · dev({DEV_MODEL_RESOLVED}) 18s · reviewer 8s. Round duration_ms to nearest second. Show "n/a" if duration not recorded.]

Tests:     [per-unit results derived from REVIEWER_OUTPUT "Test results:" per-unit list — e.g.: api ✓ · web ✗ · cli ✓. Use ✓ for PASS, ✗ for FAIL, — for SKIPPED. If no per-unit data: show overall PASS / FAIL / SKIPPED.]
Security:  [derive from the Security section of REVIEWER_OUTPUT: PASS, FINDINGS: N medium M low, or SKIPPED — no files changed]
CI:        [CI_STATUS — PASS | FAIL | SKIPPED (gh unavailable) | SKIPPED (disabled) | SKIPPED (timeout)]
Review status: [PASS | NEEDS REVIEW | FAIL]
[Retry line — derive from RETRY_COUNT, RETRY_RAN, and exit reason:
  if RETRY_RAN = true and not stuck and not max-hit: "Retry:     {RETRY_COUNT} pass(es) → Final review: [Overall status from final REVIEWER_OUTPUT]"
  if stuck: "Retry:     stuck after {RETRY_COUNT} pass(es) — same failures in 2 consecutive rounds"
  if max retries hit: "Retry:     max retries ({MAX_RETRIES}) reached after {RETRY_COUNT} pass(es)"
  if RETRY_RAN = false and first review was not PASS: "Retry:     skipped — [no failing tasks identified | user declined]"]
[if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]

[if any dev agent returned no [DEV OUTPUT] block after two attempts:]
Malformed output:
  dev: dev agent returned invalid output block after two attempts
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

**Diff preview** (DIFF_PREVIEW = true only — runs before commit):

If DIFF_PREVIEW = true AND `Overall status: PASS`:
1. Run: `git -C {WORKTREE_PATH} diff HEAD`
2. Count the output lines. If > 200 lines: print the first 200 lines and append `"... and N more lines. Run \`git -C {WORKTREE_PATH} diff HEAD\` to see the full diff."` Otherwise: print the full diff.
3. Prompt: `"Apply these changes? (yes / no)"`
4. Wait for user response.
   - `yes` or any clear affirmative: continue to the commit step below.
   - `no` or any non-yes response: run `git -C {WORKTREE_PATH} checkout .` to discard all worktree changes, run `git worktree remove {WORKTREE_PATH}`, print `"Changes discarded."` and exit. Do not proceed to Auto-PR or push notification.

**Worktree teardown** (run after printing the terminal summary above):

If `Overall status: PASS`:
- Run: `git -C {WORKTREE_PATH} add -A`
- Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip commit if nothing to commit)

**Verify / Push prompt** (PASS only — when `agents.auto_pr` is false or absent):

Print:
```
Implementation complete. What next?
  verify  — run build + test suite in worktree
  push    — print push command (create PR manually)
```
Wait for user response. If the response is anything other than `verify` or `push`: print `Worktree preserved at {WORKTREE_PATH} — run \`git worktree remove {WORKTREE_PATH}\` when done.` and exit.

If `verify`:

Detect build and test commands from the resolved stack type:

| Stack type | Build command | Test command |
|---|---|---|
| `next` / `react` / `vue` / `node` | `npm run build` | `npm test -- --watchAll=false` |
| `python` | skip build | `pytest` |
| `go` | `go build ./...` | `go test ./...` |
| `flutter` | `flutter build apk --debug` | `flutter test` |
| `android` | `./gradlew assembleDebug` | `./gradlew test` |
| `ios` | skip build | skip tests |
| unknown | skip — print "Build step skipped — stack type not recognised." | skip — print "Test step skipped — stack type not recognised." |

Run build command in WORKTREE_PATH: `cd {WORKTREE_PATH} && {build command}`. Print full output. If the build command exits non-zero, print `Build failed — review output above.`
Run test command in WORKTREE_PATH: `cd {WORKTREE_PATH} && {test command}`. Print full output. If the test command exits non-zero, print `Tests failed — review output above.`

After both commands complete (regardless of exit codes), print:
```
Verify complete.
  push  — print push command
  fix   — leave worktree open for manual edits
```
Wait for user response.
- `fix` or any non-push response: print `Worktree preserved at {WORKTREE_PATH} for manual edits.` and exit.
- `push`: fall through to push output below.

If `push` (from verify result or directly from initial prompt):
- Run: `git worktree remove {WORKTREE_PATH}`
Print:
```
Run this to push your branch:

  git push -u origin {WORKTREE_BRANCH}

Then create your PR on GitHub.
```
Exit.

**Auto-PR** (PASS only — when `agents.auto_pr: true`):
Run `gh --version` via the Bash tool to check availability.
- If available: run `gh pr create --title "{spec filename without path or extension}" --body "{first 3000 characters of REVIEWER_OUTPUT}" --head {WORKTREE_BRANCH}`. Print: `PR created: {returned URL}`.
- If `gh pr create` fails: print the error and fall through to the git push command below.
- If `gh` is not available: do nothing here — the push command below suffices.
- Print: `Next: git push -u origin {WORKTREE_BRANCH}`
- Run: `git worktree remove {WORKTREE_PATH}`

**CI polling** (PASS only — after `gh pr create` succeeds, and only when `agents.auto_pr: true`):

If `agents.auto_pr` is false or absent: skip CI polling entirely.

Set CI_STATUS = "SKIPPED (gh unavailable)" by default.

Run `gh --version` to check availability. If `gh` is not available: skip CI polling. Use the default CI_STATUS.

Read `agents.ci.enabled` from RESOLVED_CONFIG. If `false`: set CI_STATUS = "SKIPPED (disabled)" and skip CI polling.

If `gh` is available and `agents.ci.enabled` is not false:
1. Read `agents.ci.timeout_minutes` from RESOLVED_CONFIG (default: 10). Store as CI_TIMEOUT_SECONDS = timeout_minutes × 60.
2. Poll loop (every 30 seconds, up to CI_TIMEOUT_SECONDS total):
   - Run: `gh run list --branch {WORKTREE_BRANCH} --limit 1 --json status,conclusion,databaseId --jq '.[0]'`
   - If no run found yet: wait 30 seconds and retry.
   - If `status == "completed"`:
     - If `conclusion == "success"`: set CI_STATUS = "PASS". Exit loop.
     - Otherwise: set CI_STATUS = "FAIL". Run `gh run view {databaseId} --log-failed`. Print the failing step name and last 50 lines of log output. Exit loop.
   - Otherwise (in_progress / queued): wait 30 seconds and retry.
3. If loop exits due to timeout: set CI_STATUS = "SKIPPED (timeout)". Print: `"CI polling timed out after {timeout_minutes} minutes."`
4. If CI_STATUS = "FAIL":
   - Prompt: `"CI failed on [{check name}]. Re-trigger retry loop with CI context? (yes / skip)"`
   - If `yes`: re-dispatch the relevant impl agent(s) (Backend and/or Frontend as determined by the CI log) using the Phase 3.5 retry prompt structure, prepending `CI log:\n{failing log output}` to the `[INPUTS]` block. Re-commit: `git -C {WORKTREE_PATH} add -A && git -C {WORKTREE_PATH} commit -m "nob-ci-fix: {run-id}"`. Re-push: `git push origin {WORKTREE_BRANCH}`. Re-poll once (single pass, same timeout). Update CI_STATUS from the re-poll result.
   - If `skip` or any non-yes response: CI_STATUS remains "FAIL". Note in terminal summary.

If `Overall status: FAIL` or `NEEDS REVIEW`:
- Preserve the worktree for inspection.
- Print: `Worktree preserved at {WORKTREE_PATH} for inspection.`
- Print: `To clean up: git worktree remove {WORKTREE_PATH} --force`

If the run was cancelled or hit an unrecoverable error:
- Run: `git worktree remove {WORKTREE_PATH} --force`
- Print: `Run cancelled — worktree cleaned up.`

If WORKTREE_PATH equals the current working directory (git not available): skip teardown entirely.

**Push notification** (always — after teardown regardless of status):

Use the PushNotification tool with:
- `title`: `"Nob complete"`
- `body`: `"{workflow} · {spec filename without path} · {Overall status from REVIEWER_OUTPUT}"`

If the PushNotification tool is not available, skip silently.

## Step 4.5: Post-run memory write

Run only when `Overall status: PASS` or `Overall status: NEEDS REVIEW`, and `agents.checkpoint.enabled` is true.

Run `date +%F` via the Bash tool to get TODAY (YYYY-MM-DD format).

Extract from agent outputs:
1. **Test runner**: scan DEV_OUTPUT `Test output:` for the strings `jest`, `vitest`, `pytest`, `go test`, `rspec`, `mocha`. First match wins. Default: `unknown`.
2. **New routes**: extract up to 5 lines from `Contracts produced:` in DEV_OUTPUT. If absent or `none`: use empty list.
3. **Files per unit**: from DEV_OUTPUT `Files changed:` grouped by unit tag `[unit]`, collect the first 3 paths per unit. Build a map: `{ unit-name: [path1, path2, ...] }`. If a unit has no paths: skip it.
4. **Units changed this run**: collect all unit names that have at least one changed file (from step 3 above). Store as UNITS_CHANGED.
5. **Patterns observed**: scan DEV_OUTPUT for any explicit pattern notes (e.g. naming conventions, middleware patterns). Extract up to 3 as short summary strings. If none: use empty list.
6. **Corrections**: check DEV_OUTPUT `Memory conflicts:` field for any noted conflicts. If any: record them as corrections. If none: use empty list.

Read existing `.nob/project-memory.yml` using the Read tool. If not found, start with this base YAML structure:
```yaml
patterns: []
routes: []
file_clusters: []
corrections: []
```

Parse the YAML. Compute a content hash for each new entry (use a short deterministic string: `"{run-id}-{summary}"`). Before appending any entry, check whether an entry with the same summary already exists under that key — skip duplicates.

Append new entries (skip if duplicate):
- Under `patterns`: one entry per observed pattern: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{pattern description}" }`
- Under `routes`: one entry per new route extracted from `Contracts produced:` in DEV_OUTPUT: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{METHOD} {/path}" }`
- Under `file_clusters`: one entry per run (only if UNITS_CHANGED has 2 or more units): `{ run_id: "{run-id}", date: "{TODAY}", summary: "{comma-joined UNITS_CHANGED} changed together" }` — e.g. `"api, web changed together"`
- Under `corrections`: one entry per conflict noted in `Memory conflicts:` field of DEV_OUTPUT: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{conflict description}" }`

Write the updated YAML back to `.nob/project-memory.yml` using the Write tool.

Append final summary line to RUN_LOG_PATH (Bash append, as defined in Step 1):
```
{date -u +%FT%TZ}  run            -       {Overall status from REVIEWER_OUTPUT}   -  total
```

---

## Error Handling

- **.nob.yml not found**: run auto-detection (Step 1)
- **Checkpoint file corrupted/unparseable**: warn user, start fresh run (Phase 0)
- **Sub-skill file not found**: warn "sub-skill file {SKILL_BASE_DIR}/../[name]/SKILL.md not found — ensure the nob plugin is installed correctly"
- **Tech Lead output has ambiguities**: pause and ask user before proceeding (Phase 2)
- **Dev agent returns no [DEV OUTPUT] block**: re-dispatch once; if still missing after re-dispatch, mark as `failed`; stop pipeline; do NOT dispatch Reviewer
- **Reviewer status is FAIL**: print all failing items prominently; Phase 3.5 retry loop handles up to MAX_RETRIES passes (1 automatic + user-gated after that)
- **Agent result missing expected output block**: re-dispatch once; if still missing after re-dispatch, mark status `timed_out` (store `timed_out_at: "<phase>/<agent-name>"`). Do NOT pass null output to downstream agents. Stop pipeline and skip Reviewer.
- **Any early-exit agent (Init, Refactor, Ideation, Venture) returns no expected output block**: re-dispatch once with the same prompt; if still missing, print raw agent output and stop
- **Pre-flight validation fails (Step 1.5)**: print specific error message, exit immediately — no agents dispatched
- **`gh pr create` fails (M1)**: print the error output; print the `git push -u origin {WORKTREE_BRANCH}` command as fallback
- **`.nob/project-memory.md` unreadable (L1)**: set PROJECT_MEMORY = "none", skip silently; do not block pipeline
- **PushNotification tool unavailable (L2)**: skip silently
- **Run log write fails (H2)**: skip silently; do not block pipeline
