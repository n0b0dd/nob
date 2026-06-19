# Generalize Pipeline to Dev Units — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Nob's hardcoded Backend/Frontend duo with a single generic `dev` agent operating over project-declared `units`, so the pipeline works for any software project (CLI, library, single service, multi-service, mobile-only, fullstack).

**Architecture:** A project declares `units` (each a stack `type` + `path`) in `.nob.yml`. PM emits flat changes; Tech Lead writes contracts + a flat task list with `depends_on`; one `dev` coordinator self-manages parallel/sequential sub-agents per task; Reviewer validates per-unit. Spec: `docs/superpowers/specs/2026-06-17-generalize-dev-units-design.md`.

**Tech Stack:** Markdown skill files (`SKILL.md`) + JSON plugin manifests + YAML config/templates. No build system, no test runner. "Verification" = structural/consistency checks via grep + dispatch-path walkthrough.

## Global Constraints

- This is a **clean break**: `stack.frontend` / `stack.backend` keys are removed and read nowhere after this plan. No compat layer.
- Stack `type` values: `node | python | go | java | ruby | react | vue | next | flutter | android | ios | react-native | generic`. Each maps to `skills/dev/stacks/{type}.md`; `generic` (or unrecognized) means no guidance file — rely on codebase exploration.
- The canonical implementation output block is `[DEV OUTPUT]` (replaces `[BACKEND OUTPUT]` + `[FRONTEND OUTPUT]`). Its exact shape is fixed in Task 1 and consumed verbatim by Tasks 3, 4, 6, 7.
- After this plan, no live skill file under `skills/` contains the strings `BACKEND OUTPUT`, `FRONTEND OUTPUT`, `stack.frontend`, `stack.backend`, `RETRY_BACKEND`, or `RETRY_FRONTEND`. (Historical `docs/` are exempt.)
- Plugin version is bumped in **both** `.claude-plugin/plugin.json` and `marketplace.json` (Task 9).
- Each task ends with a commit. Branch is already `nob/verify-and-manual-pr`; commit there.
- Commit message trailer (per repo convention):
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## Shared contracts (referenced by multiple tasks)

These exact blocks are the cross-skill interfaces. Copy them verbatim where a task says "use the canonical block."

**Canonical `[DEV OUTPUT]` block (defined Task 1, consumed by Tasks 3/4/6/7):**

```
[DEV OUTPUT]
Units touched: [comma-separated unit names]

Tasks:
- [task-id] (unit: [name]): [done | partial | failed] — [one line]

Files changed:
- [unit] [exact/path]: [one-sentence reason]

Files created:
- [unit] [exact/path]: [one-sentence reason]

Contracts produced:
- [unit] [interface]: [METHOD /path | type name | api surface] request→response / shape
- none

Contracts consumed:
- [unit] [interface]: [what it calls and how]
- none

Test results:
- [unit]: Command: [cmd] | New tests: [PASS | FAIL — N] | Regression: [PASS | FAIL — N, list files | SKIPPED — reason]

Test output:
- [unit]:
  [verbatim last 80 lines of runner + type-checker stdout/stderr; if >80 lines prepend "[truncated — showing last 80 lines]"; or: SKIPPED — reason]

Deferred items:
- [item not implemented due to scope limit, or: none]

Items not implemented (needs human):
- [specific item and reason, or: none]

Memory conflicts:
- [conflict with a corrections entry in project memory, or: none]
[/DEV OUTPUT]
```

**Canonical Tech Lead task-list entry (defined Task 3, consumed by Task 1 dev coordinator):**

```
- id: [t1]
  title: [short title]
  description: [what to build]
  unit: [unit name from .nob.yml units list]
  files: [known target paths, or: unknown]
  depends_on: [list of task ids, or: empty]
```

**Canonical `units` schema (defined Task 2, consumed by Tasks 4/8):**

```yaml
units:
  - name: api        # unique label, used in task routing + output
    type: node       # selects dev/stacks/node.md
    path: services/api/
```

---

## Task 1: Create the merged `dev` skill and retire backend/frontend

**Files:**
- Create: `skills/dev/SKILL.md`
- Create (move): `skills/dev/stacks/{go,java,node,python}.md` (from `skills/backend/stacks/`), `skills/dev/stacks/{android,flutter,ios,next,react,react-native,vue}.md` (from `skills/frontend/stacks/`)
- Delete: `skills/backend/` (whole dir), `skills/frontend/` (whole dir)

**Interfaces:**
- Consumes: the canonical Tech Lead task-list entry (from `[TECH LEAD SPEC]` inputs — Task 3 produces it); per-unit stack guidance path map; `[PM OUTPUT]`; project memory; risk flags (already in `[TECH LEAD SPEC].Risks:`).
- Produces: the canonical `[DEV OUTPUT]` block; the `[BLOCKER]` block (unchanged from today's backend/frontend).

- [ ] **Step 1: Move the stack guidance files**

```bash
mkdir -p skills/dev/stacks
git mv skills/backend/stacks/go.md skills/dev/stacks/go.md
git mv skills/backend/stacks/java.md skills/dev/stacks/java.md
git mv skills/backend/stacks/node.md skills/dev/stacks/node.md
git mv skills/backend/stacks/python.md skills/dev/stacks/python.md
git mv skills/frontend/stacks/android.md skills/dev/stacks/android.md
git mv skills/frontend/stacks/flutter.md skills/dev/stacks/flutter.md
git mv skills/frontend/stacks/ios.md skills/dev/stacks/ios.md
git mv skills/frontend/stacks/next.md skills/dev/stacks/next.md
git mv skills/frontend/stacks/react-native.md skills/dev/stacks/react-native.md
git mv skills/frontend/stacks/react.md skills/dev/stacks/react.md
git mv skills/frontend/stacks/vue.md skills/dev/stacks/vue.md
```

- [ ] **Step 2: Verify the move**

Run: `ls skills/dev/stacks/ | wc -l && ls skills/dev/stacks/`
Expected: `11`, listing all eleven files.

- [ ] **Step 3: Write `skills/dev/SKILL.md`**

Adapt the existing `skills/backend/SKILL.md` + `skills/frontend/SKILL.md` into one generic skill. The file MUST contain these sections:

- **Frontmatter:** `name: dev`, description: "Implements work across one or more project units. Reads a Tech Lead task list, self-manages parallel vs. sequential execution, follows each unit's stack guidance and existing patterns, and emits a single [DEV OUTPUT] block. Invocable via `/nob:dev` or through the Nob hub after the Tech Lead."
- **Mode 0 — Mode Detection:** hub-dispatched (`[INPUTS]` present) vs. standalone (ask for the Tech Lead task list / spec path; look for `.nob/tech-lead-output.md`).
- **Step 1 — Read inputs:** read the `[TECH LEAD SPEC]` block — extract the task list (canonical entries), `Contracts:`, `Risks:` (store as PLAN_RISKS; `none`/absent → empty), and the per-unit stack-guidance path map. Read `[PM OUTPUT]` acceptance criteria. Read `Project memory:` and apply `corrections` (note unresolved conflicts in `Memory conflicts:`).
- **Step 2 — Build the execution plan (coordinator decision):**
  1. Parse the task list into a dependency graph using `depends_on`.
  2. If total work is trivial (≤4 files across a single unit, no risk flags): implement **in-session**, skip sub-agent dispatch.
  3. Otherwise: group tasks into dependency levels. Tasks with no unmet dependency run in the **same parallel batch** (cap concurrent dispatch at `max_parallel_slices` from inputs, default 3). A task whose `depends_on` are not all complete waits for a later batch; pass each prerequisite's produced contracts/output into the dependent task's prompt.
- **Step 3 — Sub-dev agent prompt:** for each dispatched task, dispatch an Agent with the `dev` model from inputs and a prompt that includes: the task's `title`/`description`/`files`, the unit's `stacks/{type}.md` path to read (skip if `generic`/missing), the relevant `Contracts:` (producer must implement exactly; consumer must call exactly), PLAN_RISKS handling (`[AUTH]`→match auth wiring; `[MIGRATION]`→create migration following existing pattern; `[BREAKING]`→flag callers; `[SHARED]`→read all usages), the 15-file SCOPE LIMIT, and the BLOCKER PROTOCOL. The sub-agent explores its unit's codebase, implements following existing patterns, runs that unit's tests + type-check, and returns a `[TASK OUTPUT: id]` block (fields: Files changed/created, Contracts produced/consumed, Test results, Test output, Items not implemented, Deferred).
- **Step 4 — Aggregate:** merge all `[TASK OUTPUT]` blocks (and any in-session work) into one `[DEV OUTPUT]` using the canonical block. Group `Files changed`/`Files created`/`Test results`/`Test output` by unit. Combine contracts and dedup `Items not implemented`.
- **Blocker Protocol, Output Format Requirement, Output Format, Error Handling** sections — port from the existing backend skill, renamed to `[DEV OUTPUT]`, with required fields exactly: `Tasks:`, `Files changed:`, `Contracts produced:`, `Contracts consumed:`, `Test results:`, `Items not implemented (needs human):`, `Deferred items:`, `Memory conflicts:`.

Use the **canonical `[DEV OUTPUT]` block** (Shared contracts section) verbatim as the Output Format.

- [ ] **Step 4: Delete the retired skill directories**

```bash
git rm -r skills/backend skills/frontend
```

- [ ] **Step 5: Verify no dangling references inside the new skill**

Run: `grep -nE "BACKEND OUTPUT|FRONTEND OUTPUT|PLAN OUTPUT" skills/dev/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -c "DEV OUTPUT" skills/dev/SKILL.md`
Expected: ≥ 2 (open + close tags, plus references).

- [ ] **Step 6: Commit**

```bash
git add skills/dev skills/backend skills/frontend
git commit -m "feat(dev): merge backend+frontend into generic dev skill" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: New `units` config schema (template + CLAUDE.md.template)

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`
- Modify: `skills/nob/templates/CLAUDE.md.template`

**Interfaces:**
- Produces: the canonical `units` schema (consumed by Task 4 hub + Task 8 init/refactor).

- [ ] **Step 1: Replace the `stack:` block in `.nob.yml.template`**

Replace the entire `stack:` section (the `frontend:`/`backend:`/`shared:`/`docs:`/`structure:` block) with:

```yaml
# Each unit is a buildable/testable piece of the project. A unit has a stack
# `type` (which selects dev/stacks/<type>.md guidance) and a `path`.
# A fullstack app is just two units; a CLI is one; a multi-service repo is N.
units:
  - name: api          # unique label — used in task routing and output
    type: node         # node | python | go | java | ruby | react | vue | next | flutter | android | ios | react-native | generic
    path: services/api/
  - name: web
    type: react
    path: apps/web/

docs:
  enabled: true
  specs: docs/specs        # where spec files live
  bugs: docs/bugs          # where bug reports live

structure:
  check: false  # set true to enable the nob monorepo migration offer when a non-standard layout is detected
```

- [ ] **Step 2: Update the `agents.models` block in `.nob.yml.template`**

Replace the `backend:`/`frontend:` model lines with a single `dev:` line. The block becomes:

```yaml
  models:
    # Models set here are always respected. Security review is performed inline
    # by the reviewer, so it has no separate model entry.
    dev: sonnet           # the generic implementation agent — code-writing needs sonnet
    tech-lead: sonnet     # writes contracts + task list, coordinates the dev agent
    pm: haiku
    reviewer: haiku
    init: sonnet          # project scaffolding agent
    venture: sonnet       # end-to-end venture validation pipeline
    refactor: sonnet      # project migration agent
    ideation: haiku       # feature ideation agent
```

Also update `agents.enabled` to: `[pm, tech-lead, dev, reviewer, ideation]`.

- [ ] **Step 3: Update `CLAUDE.md.template`**

In `skills/nob/templates/CLAUDE.md.template`, replace any reference to `apps/frontend` / `apps/backend` / "Backend Agent" / "Frontend Agent" with the units model and the `dev` agent. Describe the pipeline as `PM → Tech Lead → dev → Reviewer` and explain that units are declared in `.nob.yml`.

- [ ] **Step 4: Verify**

Run: `grep -nE "stack\.(frontend|backend)|^\s*frontend:|^\s*backend:" skills/nob/templates/.nob.yml.template || echo clean`
Expected: `clean`.
Run: `grep -n "units:" skills/nob/templates/.nob.yml.template`
Expected: one match.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/templates/.nob.yml.template skills/nob/templates/CLAUDE.md.template
git commit -m "feat(config): replace stack.frontend/backend with units schema" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Tech Lead emits a task list and dispatches the dev coordinator

**Files:**
- Modify: `skills/tech-lead/SKILL.md`

**Interfaces:**
- Consumes: `[PM OUTPUT]` (`Changes needed:` after Task 5 — until then `Backend/Frontend changes needed:` still parse; Tech Lead should read whichever changes fields exist); the per-unit stack-guidance path map from the hub (Task 4).
- Produces: the canonical Tech Lead task-list entries inside `[TECH LEAD SPEC]`; one dispatch of the `dev` coordinator; forwards `[DEV OUTPUT]`.

- [ ] **Step 1: Generalize the technical-spec step**

In Step 2, rename "API contracts" to **Interfaces / contracts** and define each contract with a **producing unit** and **consuming unit(s)**. Keep data schemas and risk flags as-is (risk flags already forwarded — leave intact).

- [ ] **Step 2: Replace the per-layer task breakdown with a flat task list**

Replace Step 2d ("Per-layer task breakdown") with **Step 2d — Task list**: derive a flat list of tasks, each using the **canonical Tech Lead task-list entry** (Shared contracts). Map each PM change item onto a `unit` from the `units` list. Set `depends_on` where one task needs another's output/contract (e.g. a consumer unit depends on the producer unit's contract task). Drop `BACKEND_COMPLEXITY`/`FRONTEND_COMPLEXITY`; the dev coordinator decides execution.

- [ ] **Step 3: Replace Steps 3–4 (run mode + dispatch) with a single dev dispatch**

Remove the `Mode: single | fan-out` determination and the separate Backend/Frontend dispatch blocks. Replace with: read `{SKILL_BASE_DIR}/../dev/SKILL.md` and dispatch ONE `dev` Agent (model from inputs `Agent models: dev`), with an `[INPUTS]` block containing: working directory, the per-unit stack-guidance path map, `.nob.yml` contents, `CLAUDE.md` contents, the `[TECH LEAD SPEC]` (interfaces + schemas + task list + `Risks:`), PM acceptance criteria, project memory, and `Max parallel slices`.

- [ ] **Step 4: Update the blocker resolution loop + output**

In Step 5, the blocked "layer" becomes the blocked **task/unit** — re-dispatch the dev coordinator scoped to the unresolved task(s). In the Output Format, replace the forwarded `[BACKEND OUTPUT]`/`[FRONTEND OUTPUT]` blocks with one forwarded `[DEV OUTPUT]`. Update the `[TECH LEAD OUTPUT]` required fields to: `Affected units:`, `Interfaces written:`, `Task count:`, `Risks:` (keep `Escalations made:`, `Unresolved blockers:`, `Contract violations:`).

- [ ] **Step 5: Verify**

Run: `grep -nE "BACKEND OUTPUT|FRONTEND OUTPUT|fan-out|max_parallel_slices" skills/tech-lead/SKILL.md`
Expected: only `[DEV OUTPUT]` references and the `Max parallel slices` input passthrough remain; no `[BACKEND OUTPUT]`/`[FRONTEND OUTPUT]`.
Run: `grep -n "task list\|depends_on\|dev/SKILL.md" skills/tech-lead/SKILL.md`
Expected: matches present.

- [ ] **Step 6: Commit**

```bash
git add skills/tech-lead/SKILL.md
git commit -m "feat(tech-lead): emit flat task list and dispatch dev coordinator" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Hub — units detection, dev dispatch, output validation, checkpoint

**Files:**
- Modify: `skills/nob/SKILL.md`

**Interfaces:**
- Consumes: `units` schema (Task 2); `[TECH LEAD OUTPUT]` + `[DEV OUTPUT]` (Tasks 3/1).
- Produces: `DEV_MODEL_RESOLVED`; per-unit stack-guidance path map; `tasks` checkpoint shape (consumed by Task 7 retry + resume).

- [ ] **Step 1: Rewrite auto-detection to produce `units`**

In Step 1 → Auto-detection, replace the frontend/backend classification with: each recognized manifest directory becomes a unit `{ name (from dir), type (from manifest), path }`. Remove the "multiple frontend/backend candidates" and "is this frontend or backend?" prompts. A `package.json` with no framework marker → `type: node`. Nothing detected → ask for `path:type` pairs or use one `generic` unit at repo root. Build `RESOLVED_CONFIG` with a `units:` list.

- [ ] **Step 2: Replace model + guidance resolution**

In "Extract from RESOLVED_CONFIG": replace `BACKEND_MODEL_RESOLVED`/`FRONTEND_MODEL_RESOLVED` with `DEV_MODEL_RESOLVED = agents.models["dev"] ?? "sonnet"`. Replace the two stack-guidance path variables with `UNIT_GUIDANCE_MAP` = for each unit, `{ name → {SKILL_BASE_DIR}/../dev/stacks/{type}.md }` (or `none` for `generic`/unrecognized). Update the auto-detect default config block: `agents.enabled: [pm, tech-lead, dev, reviewer, ideation]` and `agents.models` with a `dev: sonnet` line (drop backend/frontend).

- [ ] **Step 3: Collapse Phase 2 to a single Tech Lead → dev path**

Remove the "Single-slice path" vs. "Fan-out path" split entirely. Phase 2 runs PM, then dispatches Tech Lead (passing `UNIT_GUIDANCE_MAP`, `Agent models: dev: {DEV_MODEL_RESOLVED}`, `Max parallel slices`). Extract `[TECH LEAD OUTPUT]` and `[DEV OUTPUT]`. Set `IMPL_OUTPUT = [DEV OUTPUT]`. Delete `SLICE_RESULTS` and all fan-out merge logic. Update RUN_LOG appends: one `dev` line using `DEV_MODEL_RESOLVED` (replace the backend+frontend lines).

- [ ] **Step 4: Update the Output Block Validation table**

Replace the `Backend Agent` and `Frontend Agent` rows with one row:
`| Dev Agent | \`Tasks:\`, \`Files changed:\`, \`Contracts produced:\`, \`Contracts consumed:\`, \`Test results:\`, \`Items not implemented (needs human):\`, \`Deferred items:\`, \`Memory conflicts:\` |`

- [ ] **Step 5: Update the checkpoint shape + Phase 0 resume**

Replace `slices` with `tasks` (keyed by task id, values `pending | in_progress | completed`) in the initial checkpoint write and in Phase 0 resume (restore completed tasks; re-run pending/in_progress). Remove the per-slice restore prose. Keep `spec_path`, `worktree_path`, `worktree_branch`, `reviewer_output`.

- [ ] **Step 6: Update Phase 3 reviewer input**

In Phase 3, pass `[TECH LEAD OUTPUT]`, `[PM OUTPUT]`, and `[DEV OUTPUT]` (single mode only — remove the fan-out merged-slice branch).

- [ ] **Step 7: Verify**

Run: `grep -nE "BACKEND_MODEL|FRONTEND_MODEL|SLICE_RESULTS|fan-out|MERGED SLICE|stack\.(frontend|backend)" skills/nob/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -n "DEV_MODEL_RESOLVED\|UNIT_GUIDANCE_MAP\|units" skills/nob/SKILL.md | head`
Expected: matches present.

- [ ] **Step 8: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat(hub): detect units, dispatch dev, retire slice/fan-out machinery" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: PM emits a flat `Changes needed:` list

**Files:**
- Modify: `skills/pm/SKILL.md`

**Interfaces:**
- Produces: `[PM OUTPUT]` with `Changes needed:` (consumed by Task 3 Tech Lead).

- [ ] **Step 1: Replace the split fields in Requirements Extraction**

In Step 2, replace items 3 and 4 (`Backend changes needed` / `Frontend changes needed`) with a single item: **`Changes needed`** — a flat list; each item references a unit/component or file where known, otherwise "not specified — dev agent should infer from acceptance criteria."

- [ ] **Step 2: Update the Output Format block + Output Format Requirement**

In the `[PM OUTPUT]` template and the "Output Format Requirement" list, replace `Backend changes needed:` / `Frontend changes needed:` with `Changes needed:`. Keep `Acceptance criteria:`, `Edge cases to handle:`, `Out of scope:`, `Ambiguities flagged:`, `Third-party API notes:`.

- [ ] **Step 3: Verify**

Run: `grep -nE "Backend changes needed|Frontend changes needed" skills/pm/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -n "Changes needed:" skills/pm/SKILL.md`
Expected: matches present (Step 2 + Output Format).

- [ ] **Step 4: Commit**

```bash
git add skills/pm/SKILL.md
git commit -m "feat(pm): emit flat Changes needed list (drop layer split)" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Reviewer — per-unit tests and contract-list-driven check

**Files:**
- Modify: `skills/reviewer/SKILL.md`

**Interfaces:**
- Consumes: `[DEV OUTPUT]` (Task 1), `[TECH LEAD OUTPUT]` interfaces (Task 3), `[PM OUTPUT]` (Task 5).

- [ ] **Step 1: Read implementation output per unit**

In Step 3, read `[DEV OUTPUT]` instead of `[BACKEND OUTPUT]`/`[FRONTEND OUTPUT]`. Extract per-unit `Test results:` and `Test output:`. Apply the test-output corroboration rule (PASS must be backed by output; failure-indicator strings downgrade to FAIL) **per unit**. Aggregate: any unit FAIL → overall tests FAIL.

- [ ] **Step 2: Rewrite the contract check (Step 3.5) to be contract-list-driven**

Replace the three fixed checks (PM→Backend, PM→Frontend, Backend→Frontend) with: read the interface/contract list from `[TECH LEAD OUTPUT]`. For each contract, find the producing unit's `Contracts produced:` entry and verify it matches (method/path/shape or type/surface); find each consuming unit's `Contracts consumed:` entry and verify compatibility. Flag mismatches as CONTRACT VIOLATION → "Items for human review".

- [ ] **Step 3: De-layer the file-based scans**

In Steps 3.6 (security), 3.65 (migration), 3.7 (quality): collect changed/created files from `[DEV OUTPUT]` (all units) instead of from backend/frontend blocks. Drop "backend file"/"frontend file" wording; the scan categories themselves are unchanged.

- [ ] **Step 4: Update the Output Format**

In `[REVIEWER OUTPUT]`, replace the `Test results: Backend/Frontend` lines with a per-unit list:
```
Test results:
  [unit-name]: [PASS | FAIL — N | SKIPPED — reason]
```
Update the Contract check section to list per-contract results rather than the fixed three rows.

- [ ] **Step 5: Verify**

Run: `grep -nE "BACKEND OUTPUT|FRONTEND OUTPUT|PM → Backend|Backend → Frontend" skills/reviewer/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -n "DEV OUTPUT\|per-unit\|Contracts produced\|Contracts consumed" skills/reviewer/SKILL.md | head`
Expected: matches present.

- [ ] **Step 6: Commit**

```bash
git add skills/reviewer/SKILL.md
git commit -m "feat(reviewer): per-unit tests and contract-list-driven check" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Hub — retry loop, terminal summary, memory write

**Files:**
- Modify: `skills/nob/SKILL.md`

**Interfaces:**
- Consumes: `[REVIEWER OUTPUT]` per-unit results (Task 6), `[DEV OUTPUT]` (Task 1), `tasks` checkpoint (Task 4).

- [ ] **Step 1: Simplify Phase 3.5 retry routing**

Remove `RETRY_BACKEND` / `RETRY_FRONTEND` and the "cross-reference against Backend/Frontend changes needed" logic. Instead: collect failing criteria + the failing **task ids / units** from `[REVIEWER OUTPUT]`. Re-dispatch Tech Lead → dev with "re-implement these tasks: [ids]". Keep stuck-detection, `MAX_RETRIES`, the user gate after pass 1, and the retry diagnostic sub-agent (the diagnostic now emits per-unit fix scope: `Fix scope per unit:` instead of Backend/Frontend fix scope).

- [ ] **Step 2: Update the terminal summary**

- `Agents:` and `Timing:` lines: show `dev({DEV_MODEL_RESOLVED})` instead of `backend`/`frontend`.
- `Tests:` line: per-unit, e.g. `api ✓ · web ✗ · cli ✓`, derived from `[REVIEWER OUTPUT]` per-unit test results.
- Remove the fan-out `Slices:` block.

- [ ] **Step 3: Update Step 4.5 memory write**

Replace "Backend files" / "Frontend files" extraction with files grouped by unit from `[DEV OUTPUT]`. `file_clusters` records the set of units that changed together this run (e.g. `"api, web changed together"`). `routes` reads from `Contracts produced:`. `corrections` reads `Memory conflicts:` from `[DEV OUTPUT]`.

- [ ] **Step 4: Verify**

Run: `grep -nE "RETRY_BACKEND|RETRY_FRONTEND|Backend changes needed|Frontend changes needed|Slices:" skills/nob/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -n "failing task\|per unit\|dev(" skills/nob/SKILL.md | head`
Expected: matches present.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat(hub): per-task retry, per-unit summary and memory write" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: init and refactor emit the new `units` schema

**Files:**
- Modify: `skills/init/SKILL.md`
- Modify: `skills/refactor/SKILL.md`

**Interfaces:**
- Produces: generated `.nob.yml` using the canonical `units` schema (Task 2).

- [ ] **Step 1: Update init's generated `.nob.yml`**

Wherever `skills/init/SKILL.md` writes a `.nob.yml` with `stack.frontend`/`stack.backend`, change it to emit a `units` list (the scaffolded fullstack preset → two units, e.g. `web` (react/next) + `api` (node), with their scaffolded paths). Update `agents.models` to use `dev`. Update any INIT_OUTPUT/terminal references from "Frontend:/Backend:" to listing units.

- [ ] **Step 2: Update refactor's generated `.nob.yml`**

Wherever `skills/refactor/SKILL.md` writes/updates `.nob.yml`, emit the `units` schema. Keep its layout migration behavior; just map the resulting dirs to units. (Deep generalization of the target layout is out of scope per the spec — leave the `apps/frontend`+`apps/backend` target as-is but record both as units.)

- [ ] **Step 3: Verify**

Run: `grep -nE "stack\.frontend|stack\.backend|stack:\s*$" skills/init/SKILL.md skills/refactor/SKILL.md || echo clean`
Expected: `clean`.
Run: `grep -n "units:" skills/init/SKILL.md skills/refactor/SKILL.md`
Expected: matches in both files.

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md skills/refactor/SKILL.md
git commit -m "feat(init,refactor): emit units schema in generated config" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Repo docs + version bump

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update repo `CLAUDE.md`**

In the Repo Structure tree and Skill Architecture sections, replace `backend/` + `frontend/` with `dev/` (and `dev/stacks/`). Update the pipeline line to `PM → Tech Lead → dev → Reviewer` and note "Tech Lead writes a task list; the dev agent self-manages parallel/sequential sub-agents per unit." Update the `.nob.yml` section to describe `units`.

- [ ] **Step 2: Update `README.md`**

Replace the pipeline diagram `Backend ∥ Frontend (concurrent) → Security Review → Reviewer` with `Tech Lead (contracts + tasks) → dev (parallel/sequential per unit) → Reviewer (incl. inline security)`. Update the "What you get" bullets: "Backend + Frontend run concurrently" → "the dev agent runs independent units concurrently and dependent ones in order." Update the Configuration section to mention `units`.

- [ ] **Step 3: Bump the version in both manifests**

Set `version` to `1.5.0` in BOTH `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Update the marketplace `description` to drop the backend/frontend framing: "Automates the full dev cycle with minimal human-in-the-loop. PM → Tech Lead → dev → Reviewer — one command, spec to reviewed code, for any project shape."

- [ ] **Step 4: Verify**

Run: `grep -c '"version": "1.5.0"' .claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: `1` in each.
Run: `grep -rnE "Backend Agent|Frontend Agent|backend/ +—|frontend/ +—" CLAUDE.md README.md || echo clean`
Expected: `clean`.

- [ ] **Step 5: Final repo-wide consistency sweep**

Run: `grep -rnE "BACKEND OUTPUT|FRONTEND OUTPUT|stack\.frontend|stack\.backend|RETRY_BACKEND|RETRY_FRONTEND" skills/ || echo "skills clean"`
Expected: `skills clean`.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "docs: update for dev/units model, bump to 1.5.0" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes

- **Spec coverage:** every spec acceptance criterion maps to a task — schema (T2/T4), dev merge + stacks (T1), task list + dispatch (T3), coordinator parallel/sequential + `[DEV OUTPUT]` (T1), single-unit & two-unit end-to-end (validated by the structural sweeps in T4/T6/T9), reviewer per-unit + contract check (T6), retry by task (T7), summary + memory (T7), PM flat changes (T5), init/refactor schema (T8), version bump (T9).
- **Ordering:** T1/T2 are foundational (define `[DEV OUTPUT]` + schema). T3/T4 wire dispatch. T5/T6/T7 close the loop. T8/T9 ripple + release. Tech Lead (T3) is written to tolerate either PM field shape until PM lands in T5, avoiding a broken intermediate state.
- **Cross-task type consistency:** `[DEV OUTPUT]` field names, the task-list entry shape, and the `units` schema are fixed in the Shared contracts section and referenced verbatim by consumers.
- **No automated tests exist** (Markdown plugin); each task's verification is a grep/structural check, which is the appropriate analog.
