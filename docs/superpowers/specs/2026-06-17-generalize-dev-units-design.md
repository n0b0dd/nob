# Design: Generalize the pipeline from backend/frontend to dev units

**Date:** 2026-06-17
**Status:** Approved (design)
**Topic:** Replace the hardcoded Backend/Frontend duo with a generic `dev` agent operating over project-defined units.

## Problem

Nob's pipeline is locked to exactly two implementation lanes — **Backend Agent** and **Frontend Agent** — with contract checks, the retry loop, the reviewer, the config schema, and the terminal summary all built around that duo. This breaks for any project that is not a fullstack frontend+backend monorepo: CLIs, libraries, single backend services, data pipelines, infra/IaC, ML projects, desktop/game dev, mobile-only apps, and multi-service repos.

## Goal

A project is a set of **units** — each a buildable/testable piece with a stack type and a path. A single generic **`dev`** agent implements work across whatever units a project declares. "Frontend + backend" becomes just one configuration (two units). The orchestrator (the `dev` coordinator) adapts execution to task size, complexity, and dependencies — running sub-agents in parallel or sequentially as the work requires.

## Decisions (from brainstorming)

1. **Generic dev agent** — Backend + Frontend collapse into one `dev` skill. (chosen over keeping two generic slots or a single non-parallel implementer)
2. **Dev self-manages** — Tech Lead produces a flat task list; one `dev` coordinator reads it and spawns its own sub-agents, deciding parallel vs. sequential internally. (chosen over hub-owned or Tech-Lead-owned scheduling)
3. **Clean break schema** — `.nob.yml` replaces `stack.frontend` / `stack.backend` with a generic `units` list. Old keys are no longer read. (chosen over an auto-mapping compat layer)
4. **PM flat changes** — PM drops the `Backend changes needed:` / `Frontend changes needed:` split in favor of a single `Changes needed:` list.

## Architecture

### New mental model

No "layers." A project declares units; each unit has a `type` (language/framework) that selects a stack-guidance file, and a `path`. There is no frontend/backend distinction anywhere in the system.

### Pipeline

```
PM → Tech Lead → dev (coordinator, self-manages) → Reviewer
```

### `.nob.yml` schema (clean break)

```yaml
units:
  - name: api       # unique label, used in task routing + output
    type: node      # selects dev/stacks/node.md guidance
    path: services/api/
  - name: web
    type: react
    path: apps/web/
  - name: cli
    type: go
    path: cmd/
```

- `stack.frontend` and `stack.backend` are **removed** and no longer read.
- `type` is a language/framework only: `node | python | go | java | ruby | react | vue | next | flutter | android | ios | react-native | generic`. It maps to `dev/stacks/{type}.md`. `generic` (or an unrecognized type) means "no stack guidance — rely on codebase exploration."
- `docs`, `agents`, `checkpoint`, `venture`, `structure`, `auto_pr`, `ci`, `max_parallel_slices`, `max_retries` config keys are unchanged. `max_parallel_slices` now caps concurrent sub-dev agents inside the dev coordinator.

### Auto-detection (rewritten)

When `.nob.yml` is absent, scan for manifest files (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `pom.xml`, `build.gradle(.kts)`, `pubspec.yaml`; plus `android/`, `ios/Podfile`). Every recognized project directory becomes one unit:
- `name` = inferred from the directory (e.g. `services/api/` → `api`; repo root → `app`). De-duplicate names by suffixing.
- `type` = inferred from the manifest (e.g. `package.json` with `next` → `next`, with `react`/`react-dom` → `react`, with `express`/`fastify`/`koa`/`hapi`/`@nestjs/core` → `node`; `go.mod` → `go`; `pyproject.toml`/`requirements.txt` → `python`; `pom.xml`/`build.gradle` → `java`; `pubspec.yaml` → `flutter`; `android/` → `android`; `ios/Podfile` → `ios`).
- A `package.json` with no recognized framework markers is still a unit with `type: node` (covers CLIs, libraries, tooling).

No "is this frontend or backend?" prompts. If nothing is detected at all, ask the user for one or more `path:type` pairs, or proceed with a single `generic` unit at the repo root.

### Skills change

- **`skills/backend/` and `skills/frontend/` merge into `skills/dev/`.** Their `stacks/*.md` files combine into `skills/dev/stacks/` — 11 files, no overlap (`go, java, node, python` from backend; `android, flutter, ios, next, react, react-native, vue` from frontend).
- The merged `dev` skill's primary mode is the generalized coordinator. Today's separate backend/frontend coordinator modes become one.

### Tech Lead (planner)

Tech Lead continues to own technical decisions. It produces:

1. **Contracts** — generalized from "API contracts" to **interfaces between units**: still HTTP API contracts when two units talk over HTTP, but the concept also covers a shared type, a module/library API surface, or a CLI flag spec. Each contract notes its **producing unit** and **consuming unit(s)** where applicable.
2. **Data schemas** — unchanged.
3. **Risk flags** — unchanged (`[AUTH]`, `[MIGRATION]`, `[BREAKING]`, `[SHARED]`), forwarded into the dev spec as fixed earlier this session.
4. **Task list** — a flat list of work units. Each task:
   ```
   - id: t1
     title: <short>
     description: <what to build>
     unit: <unit name from .nob.yml>
     files: [<known target paths>]
     depends_on: [<task ids>]   # empty if independent
   ```

Tech Lead no longer dispatches per-layer agents. It dispatches **one `dev` coordinator**, passing the task list, contracts, schemas, risks, the per-unit stack-guidance path map, and project memory. It forwards the resulting `[DEV OUTPUT]` to the hub.

### `dev` coordinator (execution)

Receives the task list + dependency graph. Decides execution itself:

- **Independent tasks** (no `depends_on`) → dispatch sub-dev agents **in parallel**, capped at `max_parallel_slices`.
- **Dependent tasks** → run **sequentially** after their prerequisites complete; pass the prerequisite's output/produced contract forward into the dependent task's prompt.
- **Trivial total work** (few files, single unit, no risk flags) → implement **in-session**, no sub-agents.

Each sub-dev agent:
1. Reads its unit's `dev/stacks/{type}.md` guidance (skip if `generic`/missing).
2. Explores the unit's existing codebase and follows existing patterns (never invents).
3. Implements its task honoring the contracts (producer implements exactly; consumer calls exactly).
4. Acts on risk flags (`[AUTH]` → match auth wiring; `[MIGRATION]` → create migration; `[BREAKING]` → flag callers; `[SHARED]` → read all usages).
5. Runs tests/type-check for its own scope and captures verbatim output.

The coordinator aggregates all sub-agent results into **one `[DEV OUTPUT]`** block with a per-task/per-unit breakdown.

## `[DEV OUTPUT]` format

```
[DEV OUTPUT]
Units touched: [unit names]

Tasks:
- t1 (unit: api): [done | partial | failed] — [one line]
- t2 (unit: web): ...

Files changed:
- [unit] [path]: [reason]

Files created:
- [unit] [path]: [reason]

Contracts produced:
- [unit] [interface]: [METHOD /path | type | api surface] request→response / shape

Contracts consumed:
- [unit] [interface]: [what it calls and how]

Test results:
- [unit]: Command: [cmd] | New tests: [PASS|FAIL — N] | Regression: [PASS|FAIL — N|SKIPPED]

Test output:
- [unit]:
  [verbatim last 80 lines, or SKIPPED — reason]

Deferred items:
- [item, or: none]

Items not implemented (needs human):
- [item and reason, or: none]

Memory conflicts:
- [conflict with a corrections entry, or: none]
[/DEV OUTPUT]
```

The `[BLOCKER]` protocol carries over unchanged (emitted before `[DEV OUTPUT]`).

## Reviewer changes

- **Test results** are per-unit: read each unit's results from `[DEV OUTPUT]`; aggregate (any unit FAIL → tests FAIL). The PASS-must-be-corroborated-by-output rule is unchanged, applied per unit.
- **Contract check** is driven by the Tech Lead contract list: for each interface, verify the producing unit implements it (method/path/shape or type/surface) and each consuming unit calls it compatibly. Flag mismatches as CONTRACT VIOLATION. (Replaces the fixed PM→Backend→Frontend triple.)
- **Security / migration / quality scans** are file-based and stack-agnostic; only the "backend/frontend file" wording is dropped. Overall-status rules (medium security → ≥NEEDS REVIEW; important quality → ≥NEEDS REVIEW; critical migration → ≥NEEDS REVIEW) are unchanged.

## Hub plumbing (`skills/nob/SKILL.md`)

- Auto-detection produces `units`.
- `BACKEND_MODEL_RESOLVED` / `FRONTEND_MODEL_RESOLVED` → a single `DEV_MODEL_RESOLVED` (default `sonnet`).
- Stack guidance resolves per unit: `unit.type` → `{SKILL_BASE_DIR}/../dev/stacks/{type}.md`, passed to Tech Lead as a map.
- Phase 2 dispatches Tech Lead, which dispatches the one `dev` coordinator. The hub's single-slice vs. fan-out split is **removed** — parallelism lives inside the dev coordinator. `SLICE_RESULTS` and the per-slice checkpoint machinery are removed (this also retires the previously-broken per-slice resume path).
- **Output Block Validation** table: replace the Backend Agent and Frontend Agent rows with one **Dev Agent** row requiring: `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:`.
- Checkpoint shape: replace `slices` with a `tasks` map keyed by task id (`pending | in_progress | completed`) written by the dev coordinator / hub so resume can skip completed tasks.

## Retry loop (Phase 3.5)

Simplified. The hub collects failing criteria + failing **task ids / units** from the Reviewer and re-dispatches Tech Lead → dev with "re-implement these tasks." The `RETRY_BACKEND` / `RETRY_FRONTEND` routing flags and the "cross-reference against Backend/Frontend changes needed" logic are removed. Stuck-detection (same failures two passes in a row), the `max_retries` cap, the user gate after pass 1, and the retry diagnostic sub-agent are all retained — the diagnostic now emits per-unit fix scope instead of backend/frontend fix scope.

## Terminal summary & memory write

- `Tests:` line is per-unit: `api ✓ · web ✗ · cli ✓`.
- `Agents:` / `Timing:` show `dev(model)` instead of `backend`/`frontend`.
- Step 4.5 memory write: files grouped by unit; `file_clusters` records the set of units that changed together in a run (generalizes "backend+frontend changed together").

## PM changes

PM's Requirements Extraction Mode replaces the `Backend changes needed:` / `Frontend changes needed:` fields with one **`Changes needed:`** list — each item references a component/file where known, otherwise "not specified — dev agent should infer from acceptance criteria." Acceptance criteria, edge cases, out-of-scope, ambiguities, and the third-party API lookup are unchanged. Spec-Writing Mode is unaffected. Dropping the layer split is what removes the last hardcoded layer assumption from retry routing.

## Ripple to other skills

- **init** — keeps scaffolding a fullstack app as a preset, but writes the **new `units` schema** in the generated `.nob.yml`. Deeper "scaffold arbitrary unit sets" is a follow-up.
- **refactor** — still migrates toward a sensible layout but emits the new schema. Its hardcoded `apps/frontend` + `apps/backend` target is a follow-up.
- **ideation, venture** — unaffected. Ideation writes specs; venture is a separate pipeline that never used the dev agents.
- **`.nob.yml.template` + `CLAUDE.md.template`** — updated to the `units` schema and the `dev` skill.
- **Repo `CLAUDE.md` + `README.md`** — updated: skill list (`backend`/`frontend` → `dev`), repo-structure tree, and the pipeline diagram (`Backend ∥ Frontend` → `dev`).
- **`.claude-plugin/plugin.json` + `marketplace.json`** — version bump (both together) and description wording.

## Out of scope (YAGNI)

- No deep generalization of `init`/`refactor` beyond emitting the new schema.
- No per-unit model overrides (`units[].model`) — one `dev` model for now.
- No changes to the venture pipeline.
- No auto-migration of old `.nob.yml` files (clean break; users update the config or re-run detection).

## Acceptance criteria

- [ ] `.nob.yml` accepts a `units` list; `stack.frontend`/`stack.backend` are no longer read anywhere.
- [ ] Auto-detection (no `.nob.yml`) produces a `units` list with no frontend/backend prompts.
- [ ] `skills/dev/` exists with merged `stacks/` (11 files); `skills/backend/` and `skills/frontend/` are removed.
- [ ] Tech Lead emits a flat task list with `depends_on`, and dispatches one `dev` coordinator.
- [ ] The `dev` coordinator runs independent tasks in parallel and dependent tasks sequentially, and emits one `[DEV OUTPUT]`.
- [ ] A single-unit project (e.g. a Go CLI) runs end to end with no frontend/backend references.
- [ ] A two-unit project (react + node) runs end to end with a contract check between the units.
- [ ] Reviewer reports per-unit test results and a contract-list-driven contract check.
- [ ] Retry loop re-dispatches by failing task, with no `RETRY_BACKEND`/`RETRY_FRONTEND` flags.
- [ ] Terminal summary and memory write reference units, not backend/frontend.
- [ ] PM emits `Changes needed:` (no backend/frontend split).
- [ ] `init`/`refactor` write the new `units` schema; templates, `CLAUDE.md`, and `README.md` reflect the `dev` model.
- [ ] Plugin version bumped in both manifest files.

## Open questions

- none
```