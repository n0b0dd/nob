---
name: nob
description: 'Use when asked to implement a feature spec, fix a bug, sync clients after an API change, migrate an existing project, or build something from a rough idea. Triggers on: "implement [spec]", "build [feature] from [spec]", "fix [bug report]", "sync clients after [change]", "nob refactor", "nob [idea or intent]". For rough ideas with no spec file, PM Agent writes the spec first then the full pipeline runs automatically. Orchestrates PM Agent → Tech Lead Agent → Reviewer in sequence.'
---

# Nob — Hub Orchestrator

## Overview
Nob automates development workflows across a project's declared units — any project shape (CLI, library, single service, or fullstack monorepo). This hub reads user intent, resolves config, scans scope, routes to the appropriate path skill, and prints the terminal summary.

Sub-skills (`/nob:tech-lead`, `/nob:dev`, `/nob:reviewer`, `/nob:init`, `/nob:refactor`, `/nob:ideation`) can be invoked directly. When invoked via the hub, each sub-skill receives an `[INPUTS]` block with all required context and runs in hub-dispatched mode.

## Agent Dispatch Model
Each sub-skill runs as an isolated Agent tool call — fresh context, focused inputs. The hub reads each sub-skill's SKILL.md, constructs a prompt, dispatches via the Agent tool, and extracts the labeled output block. The hub's own context stays under ~10k tokens regardless of codebase size.

## Setup: Resolve skill base directory
Set `SKILL_BASE_DIR` = the path on the `Base directory for this skill:` line in your system context. All sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md`. Path skill paths use `{SKILL_BASE_DIR}/path-{route}/SKILL.md` and `{SKILL_BASE_DIR}/retry/SKILL.md`.

---

## Checkpoint pre-flight

**Dispatched as the very first agent call — before git, config, scan, or any other work.**

Skip if `--fresh` is in the user's message: run `rm -f .nob/checkpoint.json` (ignore errors) and proceed to Step 0 directly.

Skip for Init, Venture, Refactor, and Ideate intent patterns (these workflows never write a checkpoint).

Read `{SKILL_BASE_DIR}/checkpoint-gate/SKILL.md`. Dispatch with `model: haiku`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/checkpoint-gate/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Checkpoint path: .nob/
Spec path: {first .md path or file-like token found in the user's message, or: none}
[/INPUTS]
```

Extract `[CHECKPOINT GATE OUTPUT]...[/CHECKPOINT GATE OUTPUT]`. Read the `Action:` field.

| Action | Hub behaviour |
|---|---|
| `none` | Proceed to Step 0 normally. |
| `fresh` | Proceed to Step 0 normally (checkpoint already deleted by the gate skill). |
| `cancel` | Exit immediately. |
| `resume` | Set `CHECKPOINT_RESUME = true`. Set `RESUME_WORKTREE_PATH` = `Worktree path:` field. Set `RESUME_WORKTREE_BRANCH` = `Worktree branch:` field. Set `RESUME_COMPLETED_TASKS` = `Resume tasks:` field (comma-separated ids, or empty if `none`). Proceed to Step 0. |

### Resume adjustments (applied when CHECKPOINT_RESUME = true)

These override normal step behaviour throughout the rest of the hub:

- **Step 0** (git branch): skip creating a new branch. If not already on `RESUME_WORKTREE_BRANCH`, run `git checkout {RESUME_WORKTREE_BRANCH}`.
- **Step 0.1** (worktree): worktree already exists — skip `git worktree add`. Set `WORKTREE_PATH = RESUME_WORKTREE_PATH`, `WORKTREE_BRANCH = RESUME_WORKTREE_BRANCH`.
- **Step 1.5** (spec preflight): skip — spec was validated in the original run.
- **After Step 1** (once config is read): set `ROUTE = full`. Skip Step 2.5 and Step 3. Print `"Resuming from checkpoint — skipping scope scan."` Jump directly to **Dispatch path skill**, passing `RESUME_COMPLETED_TASKS` in [INPUTS].

---

## Step 0: Git branch safety

Run `git branch --show-current` to get the current branch name.

If the current branch is `main` or `master`:
- Derive a branch name: `nob/<spec-or-bug-filename-without-extension>`. Special cases: `nob/init` (Init), `nob/venture` (Venture), `nob/refactor` (Refactor). For plain-text intents with no source file: derive a slug from the first 3–4 meaningful words, lowercased and hyphenated → `nob/idea-<slug>`. Otherwise: `nob/unnamed`.
- Run `git checkout -b <branch-name>`. Confirm: `"Created branch \`<branch-name>\`"`

If already on a non-main branch, proceed without creating a new branch.

If git is not available or not a git repo, skip Step 0 and Step 0.1. Note it in the terminal summary.

### Step 0.1: Create worktree

1. Derive run-id: take branch name, replace `/` with `-` (e.g. `nob/user-profile` → `nob-user-profile`).
2. Run: `git worktree add .nob/worktrees/<run-id> <current-branch-name>`
   - If `.nob/worktrees/<run-id>` already exists: resumed run — reuse it, skip creation.
   - On collision with a different path: append `-2`, `-3`, etc.
   - On other error: print the error and exit.
3. Set `WORKTREE_PATH = .nob/worktrees/<run-id>` and `WORKTREE_BRANCH = <current-branch-name>`.
4. Ensure `.nob/` is in `.gitignore`. If absent: append it with the Edit tool.
5. From this point all agent dispatches use `Working directory: {WORKTREE_PATH}`.

If git is not available: set WORKTREE_PATH = current working directory. Note "No worktree created" in summary.

## Step 0.5: Structure Check

Skip entirely unless `.nob.yml` exists AND `structure.check: true` is explicitly set. Also skip if the intent matches: Init, Venture, Refactor, Ideate patterns (see Step 2 table).

If `structure.check: true`:
1. If working directory is empty → skip.
2. If `apps/frontend/` or `apps/backend/` is missing AND a recognisable source dir exists (`frontend/`, `web/`, `client/`, `src/`, `backend/`, `server/`, `api/`) → **mismatch**. Store detected dirs as DETECTED_DIRS.
3. If `apps/` layout correct but `shared/core/` absent → **partial mismatch**.

On mismatch: print detected vs expected layout. Prompt `"Refactor now before proceeding? (yes / skip)"`. If `yes`: read `{SKILL_BASE_DIR}/../refactor/SKILL.md`, dispatch Agent with `model: refactor-model` (resolved in Step 1) passing DETECTED_DIRS. If `Status: complete`: print "Refactor complete. Continuing…" and proceed. If failed/cancelled: proceed unchanged. If `skip` or non-yes: proceed unchanged.

---

## Step 1: Read project config

Read `CLAUDE.md` at the repo root (note if not found). Read `.nob.yml` at the repo root.

**If `.nob.yml` found**: set RESOLVED_CONFIG = its contents. Set CONFIG_AUTODETECTED = false. Skip to **Extract from RESOLVED_CONFIG**.

**If `.nob.yml` not found**: run auto-detection. Set CONFIG_AUTODETECTED = true.

### Auto-detection

```bash
find . \( -name "package.json" -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "go.mod" -o -name "pom.xml" -o -name "pubspec.yaml" -o -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/vendor/*" -maxdepth 5 2>/dev/null | sort
```

Also check: does `android/` exist? Does `ios/Podfile` exist?

Classify each found manifest:

| File | Type condition | Type |
|---|---|---|
| `package.json` | `next` in deps | next |
| `package.json` | `vue` in deps | vue |
| `package.json` | `react` or `react-dom` in deps | react |
| `package.json` | `express`/`fastify`/`koa`/`hapi`/`@nestjs/core` | node |
| `package.json` | no recognised framework | node |
| `requirements.txt` / `pyproject.toml` | — | python |
| `go.mod` | — | go |
| `pom.xml` / `build.gradle` | — | java |
| `pubspec.yaml` | — | flutter |
| `android/` dir | — | android (path = `android/`) |
| `ios/Podfile` | — | ios (path = `ios/`) |

`name` = parent directory of the manifest (e.g. `apps/frontend/package.json` → `frontend`). Skip workspace-root `package.json` with only a `workspaces` field.

If nothing detected: ask `"Could not detect your stack. Provide \`path:type\` pairs (e.g. \`apps/api:node apps/web:react\`), or press Enter to use one generic unit at repo root."` Parse response, or default to `[{ name: "root", type: "generic", path: "." }]`.

Build RESOLVED_CONFIG as YAML with detected units + these defaults:

```yaml
units:
  - name: {detected}
    type: {detected}
    path: {detected}
agents:
  enabled: [pm, tech-lead, dev, debug, reviewer, ideation]
  models:
    dev: sonnet
    debug: sonnet
    tech-lead: sonnet
    designer: haiku
    pm: haiku
    reviewer: haiku
    docs: haiku
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

Print: `"No \`.nob.yml\` found — using auto-detected config. Create \`.nob.yml\` to override."`

### Extract from RESOLVED_CONFIG

Resolve each agent model — if absent in config, use this canonical default:

| Agent | Default |
|---|---|
| dev | sonnet |
| debug | sonnet |
| tech-lead | sonnet |
| designer | haiku |
| init | sonnet |
| venture | sonnet |
| refactor | sonnet |
| pm | haiku |
| reviewer | haiku |
| ideation | haiku |
| docs | haiku |
| (any other) | haiku |

Extract:
- `agents.max_parallel_slices` (default: 3)
- `agents.checkpoint.enabled` (default: true)
- `agents.checkpoint.path` (default: `.nob/`)
- `agents.max_retries` → MAX_RETRIES (default: 3)
- `agents.auto_pr` (default: false)
- `agents.unit_boundary.enabled` (default: true)
- `agents.enabled` list (default: all agents enabled)
- `RUN_LOG_PATH` = `{checkpoint.path}run-log.tsv`
- `MARKER_PATH` = `{checkpoint.path}.boundary.json`
- Remove any stale marker: `rm -f {MARKER_PATH}` (ignore errors)
- `DEV_MODEL_RESOLVED` = `agents.models["dev"] ?? "sonnet"`
- `DEBUG_MODEL_RESOLVED` = `agents.models["debug"] ?? agents.models["dev"] ?? "sonnet"`
- `DESIGNER_MODEL_RESOLVED` = `agents.models["designer"] ?? "haiku"`
- `DOCS_MODEL_RESOLVED` = `agents.models["docs"] ?? "haiku"`

**Unit guidance map**: for each unit in `units`: `UNIT_GUIDANCE_MAP[unit.name]` = `{SKILL_BASE_DIR}/../dev/stacks/{unit.type}.md`. Set to `none` if type is `generic` or unrecognised.

**Project memory**: check `.nob/project-memory.yml` using the Read tool.
- If found and non-empty: parse and extract a ≤10-line summary across `patterns`, `routes`, `file_clusters`, `corrections`. Store as PROJECT_MEMORY.
- If not found: check `.nob/project-memory.md`. If found: migrate to YAML (same structure, write as `.nob/project-memory.yml`, delete `.nob/project-memory.md`). Store summary as PROJECT_MEMORY.
- If neither: set PROJECT_MEMORY = "none".

**Flag detection**: `--plan-only` in user's message → PLAN_ONLY = true. `--diff-only` → DIFF_PREVIEW = true.

---

## Step 2: Identify workflow type

| Intent pattern | Workflow |
|---|---|
| `"implement [file]"`, `"build [feature]"`, `"add [feature] from [spec]"` | Spec → Code |
| `"fix [file]"`, `"there's a bug in [area]"`, `"bug report [file]"` | Bug → Fix |
| `"sync clients"`, `"api changed"`, `"update clients after [change]"` | API → Sync |
| `"nob init"`, `"initialize project"`, `"scaffold project"` | Init |
| `"startup idea"`, `"business idea"`, `"I have an idea"`, `"nob venture"`, `"build a startup/product/company"`, `"validate my idea"`, `"launch a startup/product/company"`, `"bring to market"` | Venture |
| `"nob refactor"`, `"restructure project"`, `"migrate to nob structure"`, `"migrate project"`, `"refactor project structure"` | Refactor |
| `"nob ideate"`, `"ideate [direction]"`, `"what should I build next"`, `"suggest features for"`, `"what feature should I add"` | Ideate |
| Plain text with no `/` and not ending in `.md`, not matching any pattern above | Idea → Spec → Code |

For ambiguous inputs: ask `"Is this a new feature, bug fix, API sync, business idea, refactor, or ideation?"` Plain text always routes to `Idea → Spec → Code` without asking.

---

## Init workflow early exit

- Skip all remaining steps. Read `{SKILL_BASE_DIR}/../init/SKILL.md`. Dispatch with `model: agents.models["init"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../init/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
User intent: {user's original message}
[/INPUTS]
```

- Extract `[INIT OUTPUT]...[/INIT OUTPUT]`. Store as INIT_OUTPUT. Jump to **Step 4**.

## Venture workflow early exit

- Read `agents.venture.enabled` (default: true). If false: print "Venture mode is disabled." and exit.
- Read `{SKILL_BASE_DIR}/../venture/SKILL.md`. Dispatch with `model: agents.models["venture"] ?? "sonnet"`:

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

- Extract `[VENTURE OUTPUT]...[/VENTURE OUTPUT]`. Print verbatim as terminal summary. Exit.

## Refactor workflow early exit

- Read `{SKILL_BASE_DIR}/../refactor/SKILL.md`. Dispatch with `model: agents.models["refactor"] ?? "sonnet"`:

```
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
```

- Extract `[REFACTOR OUTPUT]...[/REFACTOR OUTPUT]`. Store as REFACTOR_OUTPUT. Jump to **Step 4**.

## Ideation workflow early exit

- Parse direction: strip trigger phrases; remaining text = direction; default = "general improvements".
- Parse constraint flags: `--simple`, `--no-new-deps`, `--mobile-first`, `--backend-only`, `--frontend-only` (or natural-language equivalents).
- Read `{SKILL_BASE_DIR}/../ideation/SKILL.md`. Dispatch with `model: agents.models["ideation"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../ideation/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Direction: {parsed direction}
Constraints: {parsed constraints, or: none}
Current date: {today's date in YYYY-MM-DD}
[/INPUTS]
```

- Extract `[IDEATION OUTPUT]...[/IDEATION OUTPUT]`. Store as IDEATION_OUTPUT. If missing: re-dispatch once; if still missing: print raw output and stop. Jump to **Step 4**.

---

## Idea → Spec → Code pre-processing

If workflow is `Idea → Spec → Code`:

1. Read `{SKILL_BASE_DIR}/../pm/SKILL.md`. Dispatch PM in spec-writing mode with `model: agents.models["pm"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../pm/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Hub dispatch: spec-writing
Working directory: {WORKTREE_PATH}
Idea: {user's original message}
[/INPUTS]
```

2. Extract `[PM SPECWRITER OUTPUT]...[/PM SPECWRITER OUTPUT]`. If missing: print `"PM agent did not produce a spec file path — cannot continue. Run \`/nob:pm <idea>\` directly to debug."` and exit.
3. Extract `Spec file:` line from the output. Store value as SOURCE_FILE.
4. If `checkpoint.enabled`: write initial checkpoint `{ "spec_path": "{SOURCE_FILE}", "worktree_path": "{WORKTREE_PATH}", "worktree_branch": "{WORKTREE_BRANCH}", "phases_completed": [], "tasks": {} }`.
5. Continue to **Step 1.5** treating the run as Spec → Code with SOURCE_FILE as the spec path.

---

## Step 1.5: Spec pre-flight validation

For `Spec → Code` and `Bug → Fix` workflows only. Skip for Init, Venture, Refactor, Ideate, API → Sync.

Set IS_BUG_FIX = true when intent matches a Bug → Fix pattern (case-insensitive). Otherwise IS_BUG_FIX = false.

1. **Path present**: spec file path in user's message (or SOURCE_FILE). If empty: print error and exit.
2. **File exists**: Read the file. On error: print `"Error: file not found: <path>."` and exit.
3. **File non-empty**: check length > 0. If empty: print error and exit.
4. **Content check**:
   - Spec → Code: require `## acceptance criteria` (case-insensitive). If absent: print error and exit.
   - Bug → Fix: check for `reproduc`, `expected`, `actual`, or `## acceptance criteria` (case-insensitive). If at least one: proceed. If none: print warning and proceed (do not exit).

If all checks pass: proceed.

**`--plan-only` early exit**: if PLAN_ONLY = true: dispatch PM only (requirements-extraction mode, same prompt as Phase 2 PM dispatch in path-full). Print PM_OUTPUT verbatim. Print `"Plan-only run complete."` and exit.

---

## Step 2.5: Scope scan + complexity routing

Skip for Init, Venture, Refactor, Ideate, API → Sync.

If `--full` in user's message: ROUTE = full. Skip scan. Proceed to Step 3.
If `--quick` in user's message: ROUTE = quick. Skip scan. Proceed to Step 3.

**Determine scan source**: for `Idea → Spec → Code` (SOURCE_FILE set by PM): use the spec file at SOURCE_FILE. For Spec → Code / Bug → Fix: use the user's original message, supplemented by the spec/bug file content.

**Extract targets** from the primary scan source:
- Explicit file paths (strings with `/` or known extensions: `.ts`, `.tsx`, `.js`, `.py`, `.go`, `.rb`, `.java`, `.dart`)
- Symbol names (tokens in backticks, quotes, or recognisable camelCase/snake_case identifiers)

For each symbol: `grep -rn "<symbol>" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" --include="*.rb" --include="*.java" -l 2>/dev/null | grep -v node_modules | grep -v ".git" | head -20`

For each explicit path: `ls <path> 2>/dev/null`. If no targets found: run 1–2 broad finds against likely directories.

If a spec/bug file is available and was not the primary scan source: also scan it for `## Files` or path references.

Collect SCAN_RESULT:
- `affected_files`: deduplicated list of found file paths
- `affected_units`: unit names whose `path` is a prefix of any affected file
- `new_files_required`: true if intent clearly requires creating non-existent files
- `cross_unit_contract`: true if a new shared interface, new API endpoint consumed by another unit, or schema change coordinated across units is needed

**Judge** (thresholds are guides — apply judgment; prefer higher route when ambiguous):
- **ROUTE = quick**: ALL — `affected_files` ≤ 3, `affected_units` ≤ 1, `new_files_required` = false, `cross_unit_contract` = false, no spec file with acceptance criteria.
- **ROUTE = lite**: `affected_files` 4–10, OR 1–2 new files within one unit, OR spec without cross-unit contracts.
- **ROUTE = full**: `affected_files` > 10, OR multi-unit, OR `cross_unit_contract` = true, OR task too risky/complex to plan inline.

Print: `Scope: {N} file(s) across {M} unit(s) → {ROUTE} path`

---

## Step 3: Offer to save detected config

Skip for ROUTE = quick. Skip if CONFIG_AUTODETECTED = false.

1. Print detected units, one per line: `- {name} ({type}) → {path}`
2. Prompt: `"No .nob.yml found — save the detected units so future runs skip detection? (y/N)"`
3. If `y`/`yes`: write a minimal `.nob.yml` to the repo root containing only the `units` list with the header comment from `.nob.yml.template`. Print `"Wrote .nob.yml"`. On write failure: warn and continue.
4. Otherwise: continue with in-memory config.

---

## Dispatch: ROUTE = quick (hub inline — no sub-agents)

Read the affected files from the scope scan. If none listed, grep for the key identifier from the user intent and read the first match; if still nothing, set QUICK_STATUS = FAIL, QUICK_SUMMARY = "No files found — re-run with --lite." and jump to **Step 4**.

Make all edits directly with Edit or Write tools per the user intent. Then run a stack-appropriate type-check (`npx tsc --noEmit` / `python -m py_compile <files>` / `go build ./...`) — skip for unrecognised stacks. On failure: one self-correction attempt, then QUICK_CHECK = FAIL or PASS. If skipped: QUICK_CHECK = SKIPPED.

Commit: `git -C {WORKTREE_PATH} add -A && git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip if clean).

Set QUICK_STATUS = PASS (or FAIL), QUICK_FILES_CHANGED, QUICK_SUMMARY, QUICK_CHECK. Proceed to **Step 4**.

---

## Dispatch: ROUTE = lite (hub implements; Reviewer sub-agent)

No PM or Tech Lead phases. Understand what needs to change from the user intent, spec contents, and affected files — no structured output blocks needed.

Dispatch Dev with a plain task description (no `[TECH LEAD SPEC]` wrapper). Run `date +%s` → DEV_START_EPOCH.

Read `{SKILL_BASE_DIR}/../dev/SKILL.md`. Dispatch with `model: {DEV_MODEL_RESOLVED}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../dev/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}

Per-unit stack-guidance path map:
{UNIT_GUIDANCE_MAP entries}

.nob.yml contents:
{.nob.yml content, or: not found}

CLAUDE.md contents:
{CLAUDE.md content, or: not found}

Task: {2–4 sentences describing what to implement, derived directly from user intent and spec}
Files to change: {affected files from scope scan, one per line}
Acceptance criteria: {key criteria from spec / user intent, or: implement as described}

Project memory:
{PROJECT_MEMORY}

Max parallel slices: 1
Already-completed tasks: none
[/INPUTS]
```

Extract `[DEV OUTPUT]...[/DEV OUTPUT]`. Store as DEV_OUTPUT. Apply Output Block Validation. If missing after one re-dispatch: set LITE_STATUS = FAIL; jump to **Step 4**.

Run `date +%s` → DEV_END_EPOCH.

Dispatch Reviewer. Run `date +%s` → REVIEWER_START_EPOCH.

Read `{SKILL_BASE_DIR}/../reviewer/SKILL.md`. Dispatch with `model: {agents.models["reviewer"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/../reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}
Spec file path: {spec file path, or: none}
Spec file contents:
{spec file content, or: none}
User intent: {user's original message}

All agent outputs for review:
{DEV_OUTPUT}
[/INPUTS]
```

Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Apply Output Block Validation.

Run `date +%s` → REVIEWER_END_EPOCH.

**Auto-retry (1 pass):** Set LITE_RETRY_COUNT = 0. If `Overall status:` is not PASS: collect all `✗`/`⚠` lines from REVIEWER_OUTPUT as RETRY_ITEMS; print `"Reviewer found {N} item(s) — auto-fixing:\n{RETRY_ITEMS}"`; re-dispatch Dev prepending `"Fix only these:\n{RETRY_ITEMS}"`, extract new DEV_OUTPUT; re-dispatch Reviewer, extract new REVIEWER_OUTPUT; set LITE_RETRY_COUNT = 1.

**Commit if PASS:** `git -C {WORKTREE_PATH} add -A && git -C {WORKTREE_PATH} commit -m "nob: {run-id}"`

Set:
- LITE_STATUS = `Overall status:` from REVIEWER_OUTPUT
- LITE_RETRY_COUNT, LITE_RETRY_RAN = (LITE_RETRY_COUNT > 0)
- LITE_TIMING = `dev {round(DEV_END_EPOCH - DEV_START_EPOCH)}s · reviewer {round(REVIEWER_END_EPOCH - REVIEWER_START_EPOCH)}s`
- LITE_AGENTS_RUN = `dev({DEV_MODEL_RESOLVED}) · reviewer({agents.models["reviewer"] ?? "haiku"})`

Proceed to **Step 4**.

---

## Dispatch: ROUTE = full (path-full sub-agent)

Read `{SKILL_BASE_DIR}/path-full/SKILL.md`. Dispatch with `model: {DEV_MODEL_RESOLVED}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/path-full/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKTREE_PATH}
Run ID: {run-id}
Worktree branch: {WORKTREE_BRANCH}
Hub skill base dir: {SKILL_BASE_DIR}
Workflow: {identified workflow type — e.g. Spec→Code | Bug→Fix | API→Sync}
Is bug fix: {IS_BUG_FIX — true | false}
Stack type: {type of first affected unit, or: unknown}

Spec file path: {spec file path, or: none}
Spec file contents:
{spec file content, or: none}

User intent: {user's original message}

Per-unit stack-guidance path map:
{for each entry in UNIT_GUIDANCE_MAP: "  {name}: {path-or-none}"}

.nob.yml contents:
{.nob.yml content, or: not found}

CLAUDE.md contents:
{CLAUDE.md content, or: not found}

Agent models:
  dev: {DEV_MODEL_RESOLVED}
  debug: {DEBUG_MODEL_RESOLVED}
  tech-lead: {agents.models["tech-lead"] ?? "sonnet"}
  designer: {DESIGNER_MODEL_RESOLVED}
  reviewer: {agents.models["reviewer"] ?? "haiku"}
  pm: {agents.models["pm"] ?? "haiku"}
  docs: {DOCS_MODEL_RESOLVED}

Agents enabled: {agents.enabled list, comma-separated}
Max parallel slices: {agents.max_parallel_slices}
Max retries: {MAX_RETRIES}
Checkpoint enabled: {agents.checkpoint.enabled}
Checkpoint path: {agents.checkpoint.path}
Marker path: {MARKER_PATH}
Run log path: {RUN_LOG_PATH}
Unit boundary enabled: {agents.unit_boundary.enabled}

Affected files (from scope scan):
{SCAN_RESULT.affected_files — one per line, or: none}

Affected units (from scope scan):
{SCAN_RESULT.affected_units — one per line, or: none}

Cross-unit contract: {SCAN_RESULT.cross_unit_contract}
New files required: {SCAN_RESULT.new_files_required}

Units (from config):
{for each unit: "- name: {name}, type: {type}, path: {path}"}

Project memory:
{PROJECT_MEMORY}

Resume completed tasks: {RESUME_COMPLETED_TASKS from checkpoint, or: none}
[/INPUTS]
```

Extract `[FULL PATH OUTPUT]...[/FULL PATH OUTPUT]`. Store as PATH_OUTPUT_META. Then extract embedded: `[PM OUTPUT]`, `[DEBUG OUTPUT]` (if present), `[TECH LEAD OUTPUT]`, `[DEV OUTPUT]`, `[DESIGNER OUTPUT]` (if present), `[DOCS OUTPUT]` (if present), `[REVIEWER OUTPUT]`.

If PATH_OUTPUT_META is missing: re-dispatch once. If still missing: print raw output and exit.

**Lift unit-boundary marker**: `rm -f {MARKER_PATH}` (ignore errors).

---

## Output Block Validation Procedure

The hub (lite: Dev + Reviewer), path-full, and retry all validate agent output blocks before passing them downstream. This table documents the required fields per agent — the linter checks this table against the producing skills.

| Agent | Required fields |
|---|---|
| Tech Lead | `Units touched:`, `Interfaces written:`, `Task count:`, `Risks:` |
| PM Agent | `Acceptance criteria:`, `Edge cases to handle:`, `Out of scope:`, `Ambiguities flagged:` |
| Dev Agent | `Units touched:`, `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:` |
| Reviewer | `Overall status:`, `Test results:`, `Contract check:`, `Security:`, `Migration safety:`, `Code quality:`, `Design compliance:`, `Criteria check:`, `Items for human review:` |
| Docs Agent | `Files documented:`, `Files skipped:`, `Total:` |

When any required field is missing from an agent's output: re-dispatch once with a field list prepended. If still missing after re-dispatch: mark as `malformed` and treat as `failed` for all pipeline flow decisions.

---

## Step 4: Print terminal summary

**If workflow is `Ideate`:**

```
Nob ideation complete.

Direction:   {Direction from IDEATION_OUTPUT}
Constraints: {Constraints from IDEATION_OUTPUT}
Ideas:       {Ideas generated from IDEATION_OUTPUT}
Chosen:      {Chosen from IDEATION_OUTPUT}
Spec:        {Spec saved from IDEATION_OUTPUT}

{if Spec saved is not "n/a":}
Next: /nob implement {Spec saved from IDEATION_OUTPUT}
```

**If workflow is `Refactor`:**

```
Nob refactor complete.

Moves:       {for each move in REFACTOR_OUTPUT: "{from} → {to}: ✓ or ✗"}
             {none if no moves}
Shared:      shared/core/             {✓ if created, ✗ otherwise}
Imports rewritten: {N}
Config:      CLAUDE.md                  ✓ | ✗
             .nob.yml                   ✓ | ✗

{if move or import warnings:}
Manual review needed:
  {warnings from REFACTOR_OUTPUT}

Next: /nob implement docs/specs/your-feature.md
```

If REFACTOR_OUTPUT Status is `cancelled`: print "Refactor cancelled. No changes made." and exit.
If Status is `failed`: print failure details and exit.

**If workflow is `Init`:**

```
Nob init complete.

Project:   {Project from INIT_OUTPUT}
Stack:     {Frontend} + {Backend} + {Database from INIT_OUTPUT}

Files created: {N}
Installs:
  {if JS/TS: pnpm install (root) ✓ | failed ✗}
  {if Python backend: pip install ✓ | failed ✗}
  {if Go backend: go mod tidy ✓ | failed ✗}
  {if Flutter: flutter pub get ✓ | failed ✗}

{if any install failed:}
Install errors — run manually:
  {retry command with correct working directory}

Config written:
  CLAUDE.md
  .nob.yml

Next steps:
  1. Copy .env.example → .env in each unit and fill in values
  2. Start each unit: {start commands from INIT_OUTPUT}
  3. Write a spec:   docs/specs/your-feature.md
  4. Then run:       /nob implement docs/specs/your-feature.md
  5. When ready:     git push -u origin nob/init
```

**If ROUTE = quick:**

```
Nob quick complete.

Path:          quick (hub inline — no sub-agents)
Files changed: {QUICK_FILES_CHANGED}
Changes:       {QUICK_SUMMARY}
Check:         {QUICK_CHECK}
Branch:        {WORKTREE_BRANCH}

Next:
  Review: git -C {WORKTREE_PATH} diff HEAD
  Push:   git push -u origin {WORKTREE_BRANCH}
```

Exit after printing. Do not proceed to the sections below.

**For all other workflows** (Spec → Code, Bug → Fix, API → Sync — ROUTE = lite or full):

**ROUTE = lite**: DEV_OUTPUT and REVIEWER_OUTPUT are in hub context from the inline dispatch above. PM_OUTPUT, TECH_LEAD_OUTPUT, DEBUG_OUTPUT, DESIGNER_OUTPUT, DOCS_OUTPUT are all "none" (not produced on lite path). Set RETRY_COUNT = LITE_RETRY_COUNT, RETRY_RAN = LITE_RETRY_RAN, RETRY_EXIT_REASON = "n/a (lite)". Use LITE_AGENTS_RUN for the Agents line and LITE_TIMING for the Timing line.

**ROUTE = full**: read from PATH_OUTPUT_META and the embedded output blocks extracted from the path-full sub-agent result:
- REVIEWER_OUTPUT, DEV_OUTPUT, TECH_LEAD_OUTPUT, PM_OUTPUT from extracted `[X OUTPUT]` blocks.
- DEBUG_OUTPUT (from [DEBUG OUTPUT] block, or "none").
- DESIGNER_OUTPUT (from [DESIGNER OUTPUT] block, or "none").
- DOCS_OUTPUT (from [DOCS OUTPUT] block, or "none").
- RETRY_COUNT, RETRY_RAN, RETRY_EXIT_REASON: extract from PATH_OUTPUT_META.

```
Nob complete.

Workflow:  {Spec→Code | Bug→Fix | API→Sync}
Source:    {spec/bug file path}
Design:    {Design doc field from TECH_LEAD_OUTPUT — omit if absent or "none"}
UX design: {Design doc field from DESIGNER_OUTPUT — omit if DESIGNER_OUTPUT is "none" or field absent}
Agents:    {LITE_AGENTS_RUN for lite | Agents run from PATH_OUTPUT_META for full}
Timing:    {LITE_TIMING for lite | Timing from PATH_OUTPUT_META for full}
{Bug→Fix only, if DEBUG_OUTPUT is not "none":}
Root cause: {Root cause field from DEBUG_OUTPUT}

Tests:     {per-unit test results from REVIEWER_OUTPUT "Test results:" — e.g. api ✓ · web ✗ · cli ✓. ✓=PASS, ✗=FAIL, —=SKIPPED. If no per-unit data: overall PASS/FAIL/SKIPPED.}
Security:  {from REVIEWER_OUTPUT Security section: PASS | FINDINGS: N medium M low | SKIPPED}
CI:        {CI_STATUS — PASS | FAIL | SKIPPED (gh unavailable) | SKIPPED (disabled) | SKIPPED (timeout)}
Review status: {PASS | NEEDS REVIEW | FAIL}
{Retry line — from RETRY_COUNT, RETRY_RAN, RETRY_EXIT_REASON:
  if RETRY_RAN = true and exit was pass: "Retry:     {RETRY_COUNT} pass(es) → Final review: {Overall status from REVIEWER_OUTPUT}"
  if stuck: "Retry:     stuck after {RETRY_COUNT} pass(es) — same failures in 2 consecutive rounds"
  if max-retries: "Retry:     max retries ({MAX_RETRIES}) reached after {RETRY_COUNT} pass(es)"
  if no-failing-tasks or user-declined: "Retry:     skipped — {no failing tasks identified | user declined}"
  if RETRY_RAN = false and first review was not PASS: "Retry:     skipped — {reason}"}
{if NEEDS REVIEW or FAIL: list items from REVIEWER_OUTPUT "Items for human review:" section}

{if any agent was marked malformed/timed_out:}
Malformed output:
  {agent-name}: returned invalid/no output block after two attempts
  Check agent output above, then re-run to retry.

{if checkpoint.enabled:}
Checkpoint: {checkpoint.path}checkpoint.json
When done: rm {checkpoint.path}checkpoint.json

Next steps:
- Review the changes above
- If items need human review, address them before committing
- When satisfied: git add -p && git commit -m "feat: <spec name>"
- Then: git push -u origin <branch-name>
```

**Diff preview** (DIFF_PREVIEW = true only):

If `Overall status: PASS`:
1. Run `git -C {WORKTREE_PATH} diff HEAD`. If > 200 lines: print first 200 + truncation notice. Otherwise print full diff.
2. Prompt `"Apply these changes? (yes / no)"`. If `no`: run `git -C {WORKTREE_PATH} checkout .`, remove worktree, print "Changes discarded." and exit.

**Worktree teardown** (after terminal summary):

If `Overall status: PASS`:
- `git -C {WORKTREE_PATH} add -A`
- `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip if nothing to commit)

**Verify / Push prompt** (PASS only, when `agents.auto_pr` is false):

```
Implementation complete. What next?
  verify  — run build + test suite in worktree
  push    — print push command (create PR manually)
```
If anything other than `verify` or `push`: print `"Worktree preserved at {WORKTREE_PATH}"` and exit.

If `verify`: detect build/test commands from resolved stack type and run them in WORKTREE_PATH. Print output. Then prompt `"  push  — print push command  /  fix  — leave worktree open"`. If `fix`: print `"Worktree preserved."` and exit.

If `push` (from verify or directly):
- `git worktree remove {WORKTREE_PATH}`
- Print: `"Run this to push:\n\n  git push -u origin {WORKTREE_BRANCH}\n\nThen create your PR on GitHub."`

**Auto-PR** (PASS only, when `agents.auto_pr: true`):
- Run `gh --version`. If available: `gh pr create --title "{spec filename}" --body "{first 3000 chars of REVIEWER_OUTPUT}" --head {WORKTREE_BRANCH}`. On failure: print error.
- Print `"Next: git push -u origin {WORKTREE_BRANCH}"`. `git worktree remove {WORKTREE_PATH}`.

**CI polling** (only when `agents.auto_pr: true` and `gh pr create` succeeded):

Set CI_STATUS = "SKIPPED (gh unavailable)". If `gh` unavailable: skip. If `agents.ci.enabled` = false: CI_STATUS = "SKIPPED (disabled)". Otherwise:
1. CI_TIMEOUT_SECONDS = `agents.ci.timeout_minutes` (default: 10) × 60.
2. Poll every 30s up to timeout: `gh run list --branch {WORKTREE_BRANCH} --limit 1 --json status,conclusion,databaseId --jq '.[0]'`. On `completed`: if `success` → CI_STATUS = "PASS"; else → CI_STATUS = "FAIL", `gh run view {databaseId} --log-failed`, print failing step + last 50 lines.
3. On timeout: CI_STATUS = "SKIPPED (timeout)".
4. If CI_STATUS = "FAIL": prompt `"CI failed. Re-trigger retry loop with CI context? (yes / skip)"`. If `yes`: re-dispatch impl agents with CI log prepended. Re-commit, re-push, re-poll once.

If `Overall status: FAIL` or `NEEDS REVIEW`: print `"Worktree preserved at {WORKTREE_PATH} for inspection."` and `"To clean up: git worktree remove {WORKTREE_PATH} --force"`.

On cancellation or unrecoverable error: `git worktree remove {WORKTREE_PATH} --force`. Print `"Run cancelled — worktree cleaned up."`

**Push notification** (always, after teardown):

Use PushNotification tool: `title: "Nob complete"`, `body: "{workflow} · {spec filename} · {Overall status from REVIEWER_OUTPUT}"`. If tool unavailable: skip silently.

---

## Step 4.5: Post-run memory write

Run only when `Overall status: PASS` or `NEEDS REVIEW`, and `checkpoint.enabled` is true.

Run `date +%F` → TODAY.

Extract from DEV_OUTPUT:
1. **Test runner**: scan `Test output:` for `jest`, `vitest`, `pytest`, `go test`, `rspec`, `mocha`. First match wins. Default: `unknown`.
2. **New routes**: up to 5 lines from `Contracts produced:` (empty list if absent or "none").
3. **Files per unit**: from `Files changed:` grouped by `[unit]` tag — first 3 paths per unit.
4. **Units changed**: all unit names with at least one changed file → UNITS_CHANGED.
5. **Patterns**: up to 3 pattern notes from DEV_OUTPUT. Empty list if none.
6. **Corrections**: `Memory conflicts:` field notes. Empty list if none.

Read `.nob/project-memory.yml` (or start with `{ patterns: [], routes: [], file_clusters: [], corrections: [] }`).

Dedup: before appending, check whether an entry with the same `summary` already exists under that key — skip duplicates.

Append:
- Under `patterns`: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{pattern description}" }` per pattern.
- Under `routes`: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{METHOD} {/path}" }` per new route.
- Under `file_clusters`: if UNITS_CHANGED ≥ 2: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{comma-joined UNITS_CHANGED} changed together" }`.
- Under `corrections`: `{ run_id: "{run-id}", date: "{TODAY}", summary: "{conflict description}" }` per conflict.

Write updated YAML to `.nob/project-memory.yml`.

Append to RUN_LOG_PATH: `{date -u +%FT%TZ}  run            -       {Overall status}   -  total`

---

## Error Handling

| Condition | Action |
|---|---|
| `.nob.yml` not found | Auto-detect (Step 1) |
| Checkpoint corrupted/unparseable | Warn; start fresh run |
| Sub-skill SKILL.md not found | Warn "sub-skill file {SKILL_BASE_DIR}/../[name]/SKILL.md not found — ensure nob plugin is installed" |
| Path skill returns no output block | Re-dispatch once; if still missing, print raw output and exit |
| Spec pre-flight fails (Step 1.5) | Print specific error; exit immediately — no agents dispatched |
| `gh pr create` fails | Print error; print `git push -u origin {WORKTREE_BRANCH}` as fallback |
| `.nob/project-memory.*` unreadable | Set PROJECT_MEMORY = "none"; skip silently |
| PushNotification unavailable | Skip silently |
| Run log write fails | Skip silently |
