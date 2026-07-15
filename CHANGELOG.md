# Changelog

All notable changes to the nob plugin are documented here. Versions are bumped in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## [2.5.1] — 2026-07-15

### Fixed
- **Direct-dev bug-fix stub used pre-v2.4.0 field names.** `path-full`'s synthesized `[TECH LEAD OUTPUT]` for the localized bug-fix fast path emitted `Affected units:`/`Task count:` instead of the current `Units touched:`/`Task list:`, and omitted `Coverage check:` entirely — breaking retry's task-completion tracking and Reviewer's AC-MISSING classification on any retried direct-dev fix. The stub now emits the canonical fields, with `Coverage check:` mapping each PM acceptance criterion to the constructed task ids (not a blanket `none`, which would force an unwanted Tech Lead escalation on retry).
- **Plan-cancellation didn't emit `[FULL PATH OUTPUT]`.** Cancelling at the `--plan` approval gate tore down the worktree but never printed the required output wrapper, so the hub treated the cancellation as a crashed sub-agent and silently re-dispatched the entire pipeline from scratch. The cancel branch now emits a minimal `cancelled at plan approval` status block, and the hub short-circuits on it instead of re-running.
- **Two copies of the Output Block Validation required-fields table had drifted apart** (hub vs `path-full`) — re-synced field-for-field.
- **Removed the dead `Contract violations:` field** from Tech Lead's output — its contract-check step moved to Reviewer in v2.4.0 and nothing ever populated or read this field.
- **Three stale Tech Lead cross-references** to a removed dev-dispatch step and a removed blocker-loop "Step 4" corrected to reflect the current planner-only role (path-full dispatches dev; ambiguity/risk blockers are handled inline in Step 2 / Error Handling).
- **Reviewer's dev-only retry routing couldn't attach a task id to per-file findings.** Quality/Security/Design findings are captured per-file, not per-task, but retry's `PASS_THROUGH_IDS` computation only recognized `[t{N}]`-prefixed items — an unmapped finding could be silently treated as already-completed and skipped. Reviewer now matches the finding's file against Tech Lead's task list to derive the task id, falling back to an explicit `[unmapped]` sentinel that retry always forwards to Dev instead of dropping.
- **`--full` flag was documented but never implemented.** Hub routing now honors it as an explicit override of the auto-quick heuristic.
- **Removed a stale "Lite path" tier** from `CLAUDE.md.template`, left over from the quick/lite/full model collapsed to quick/full-only in v2.4.0.

## [2.5.0] — 2026-06-23

### Added
- **PM: hardened error-states question** with a failure scaffold (invalid input, network, auth, empty, rate limits) so specs surface edge cases up front.
- **PM: AC self-audit (Step 3.2)** sharpens vague acceptance criteria before the revision loop; the AC format now requires a concrete observable signal (toast, redirect, download, state change).
- **Tech Lead: AC→task coverage check (Step 2e)** — every PM acceptance criterion must map to at least one task.
- **Tech Lead: integration/wiring task checklist (Step 2f)** — route registration, DI, index exports, env vars, migrations, middleware.
- **Tech Lead: `what` field self-audit (Step 2g)** — exact naming, error handling, edge cases, no forward references.
- **Tech Lead: extended risk flags** — `[PAGINATION]`, `[VALIDATION]`, `[CORS]` (informational, no escalation).
- **Reviewer: retry routing classification (Step 5.5)** — classifies every failing item into `tl-required`, `dev-only`, or `human-gate`, emitted as a new `Retry routing` block.
- **Retry: routing-aware dispatch (Step 8.5)** — reads the `Retry routing` block and human-gates `CRITICAL` findings before autonomous retry. TL-required items (contract violations, missing tasks) route through Tech Lead as before; dev-only items (implementation bugs, quality findings, partial criteria) skip Tech Lead and only re-run the failing tasks against the existing plan, falling back to the TL-required path if dev dispatch fails. Backward compatible — an absent `Retry routing` block defaults to `tl-required`.

### Changed
- Tech Lead's Designer dispatch now warns explicitly when `.nob.yml` is absent.
- Tech Lead's coverage check is emitted in `[TECH LEAD OUTPUT]` and validated by `path-full`.

## [2.4.0] — 2026-06-23

### Changed
- **Simplified pipeline: quick or full only.** Removed `path-quick` and `path-lite`; the hub now routes to either the inline quick handler or `path-full`. Quick bypass triggers on a `--quick` flag or a plain casual message (≤15 words, no spec file) and the hub handles it inline.
- **Tech Lead is planner-only.** Removed dev dispatch, the blocker loop, TDD status computation, and the contract-check step from Tech Lead — it now only discovers files, resolves contracts, and produces the task list.
- **`path-full` dispatches Dev directly after Tech Lead**; TDD status is computed post-Dev instead of inside Tech Lead.
- **`[TECH LEAD OUTPUT]` now includes the full task list**, replacing the prior `Task count` field.
- **Hub no longer runs a scope scan** — Tech Lead owns file discovery.

## [2.3.0] — 2026-06-23

### Added
- **`/nob:status` skill** (`skills/status/`). New haiku-dispatched skill that shows the current nob session state — active branch, checkpoint status, running agents, and last completed phase. Routed from the hub via `"nob status"` / `"show status"` / `"what's running"` intent patterns. Excluded from checkpoint-gate (no checkpoint written or read).
- **`/nob:test-writer` skill** (`skills/test-writer/`). New haiku-dispatched skill that generates tests for changed or specified files. Wired into hub model defaults (`test-writer: haiku`) and `.nob.yml` config surface.
- **`--tdd` flag** (`TDD_FLAG`). Hub flag extraction now detects `--tdd` in the user's message and passes it downstream. Path skills use this to enable test-first mode — test-writer runs before dev, and dev implements to make those tests pass.

### Changed
- Hub intent routing table updated: `"nob status"` and related phrases now resolve to the Status workflow before falling through to `Idea → Spec → Code`.
- Hub agent model table and `.nob.yml` defaults updated to include `test-writer` and `status` (both `haiku`).

## [2.2.0] — 2026-06-23

### Added
- **Designer creative mandate.** Designer now has an explicit creative requirement: explore 2–3 distinct UX approaches before committing (Step 1.8), reframe each requirement as a user goal + emotional state and surface missing moments the spec never mentioned — first-use, success, error recovery, permission states (Step 1.7). A Designer that only outputs what the spec already said adds no value; this forces the creative judgment that justifies the agent's existence.
- **Designer ↔ Tech Lead feedback loop** (1–2 rounds). After each Designer round, Tech Lead reviews for technical feasibility — data cost, real-time implications, SSR constraints, impossible state combinations — and sends targeted feedback. Designer revises. If round 2 still has unresolved concerns they become `[DESIGN]` risk flags rather than blocking the pipeline. Short-circuits on approval: zero concerns after round 1 means no round 2.
- **Workflow-based dev task dispatch.** The dev coordinator now fans out per-task agents via the Claude Workflow tool instead of manual Agent calls. Dependency ordering is handled by a topological sort (`buildLevels`) and `parallel()` within each level — tasks with no mutual dependency run concurrently, dependent tasks wait for their prerequisites' structured results.
- **Intelligent per-task model selection.** Each task agent is assigned `haiku` or `devModel` (sonnet by default) based on a complexity score: critical-path position (other tasks depend on this one), risky keywords in `what`/`title`, global risk flags, multiple `depends_on` inputs, `action: delete`, and multiple `consumes` entries. Simple focused leaf tasks use haiku; high-stakes or complex tasks escalate automatically.
- **Composable task format.** Tech Lead task list now uses `file` (one file per task), `action` (create/edit/delete), `what` (self-contained implementation sentence), `exports` (produced symbol/endpoint), and `consumes` (taskId → symbol). Each task agent needs only its own fields to implement — no cross-task context required.
- **Designer detail encoded into task `what` fields.** Tech Lead encodes the relevant component section from Designer output directly into each frontend task's `what` — all states with exact visual treatments, design token values, interaction steps, ARIA and keyboard requirements. A focused Haiku agent implementing `ExportButton` gets everything it needs in `what`; full Designer output is injected only as a fallback when `what` is sparse.

### Changed
- **Spec template cleaned up.** Removed `## API contracts` (Tech Lead's domain) and `## UI spec` (Designer's domain). Replaced with a lightweight `## Data` section (entity names + intent only, no field types) and `## Design resources` (Figma link only). Acceptance criteria and error state examples are now behaviour-focused — no HTTP verbs or response shapes.
- **Design template restructured per-unit.** One `## {unit-name}` section per unit (api, web, ios, android, flutter, cli — any stack). Data schemas only appear under units that own persisted data. Task list is grouped by unit with the new composable format.
- **`.nob.yml.reference.yml` updated.** Added `designer`, `test-writer`, and `status` to both `agents.enabled` and `agents.models` with inline comments.
- **`CLAUDE.md.template` updated.** Corrected pipeline description (Designer runs inside Tech Lead, not as a separate step). Added flags table documenting `--tdd`, `--plan`, `--plan-only`, `--diff-only`, `--fresh`, `--quick`, `--full`.
- **Dev Workflow drops full Designer output from task prompts.** Since Tech Lead encodes Designer detail into `what`, task agents receive focused prompts. Full Designer output is only injected as fallback when `what` is sparse (< 80 chars).

## [2.1.0] — 2026-06-22

### Changed
- **Quick path runs entirely in hub context — no sub-agents dispatched.** For ≤3-file, single-unit changes the hub now reads, edits, verifies, and commits directly. Eliminates the sub-agent spin-up that was the dominant latency on small tasks.
- **Lite path drops PM/TL structured-block phases.** The `[PM OUTPUT]` and `[TECH LEAD OUTPUT]` block-production steps are removed. The hub reasons about what to change inline and passes Dev a plain `Task:` description instead of a formal `[TECH LEAD SPEC]` wrapper. Only Dev and Reviewer are dispatched as sub-agents (down from the former path-lite wrapper + Dev + Reviewer).
- **Full path unchanged.** Multi-unit, cross-contract, and complex runs still go through the complete PM → Debug → Tech Lead → Dev → Docs → Reviewer pipeline with checkpoint and retry.

## [1.8.0] — 2026-06-19

### Added
- **Dedicated `debug` skill for Bug→Fix runs** (`/nob:debug`) with **complexity-based routing**. The hub runs the **read-only** debug agent right after PM; debug reproduces the failure, isolates the root cause (file:line evidence, not just the symptom), and emits a `[DEBUG OUTPUT]` with a recommended fix plan, risk flags, confidence, and a *suggested* regression test. It never edits code. The hub then routes on debug's own complexity signals:
  - **Localized bug → `PM → debug → dev → Reviewer`** (fast path): the hub builds a minimal `[TECH LEAD SPEC]` straight from the recommended fix and dispatches `dev`, **skipping the Tech Lead**.
  - **Complicated bug → `PM → debug → Tech Lead → dev → Reviewer`** (escalated path): triggered when any of ≥2 affected units, a `[BREAKING]`/`[MIGRATION]`/`[AUTH]` risk, `Confidence: low`, or >4 recommended-fix files. The Tech Lead receives the diagnosis (does not re-run debug), plans a sequenced task graph, gates risk, and runs the blocker loop.
  An `[AUTH]`/`[BREAKING]` risk also triggers a human confirm gate before any code is written. `dev` does all code changes (its usual flow, including tests); Reviewer, checkpoint, and the retry loop are unchanged. Debug reuses `skills/dev/stacks/` for per-stack context.
- New `agents.models.debug` config (defaults to `agents.models.dev`, then `sonnet`); `debug` added to the auto-detected `agents.enabled` list.

### Changed
- **Hub passes the identified `Workflow:` type into Phase 2** and orchestrates the bug-fix routing above (the Tech Lead is dispatched only on the escalated path). On the direct-dev fast path the hub synthesizes a stub `[TECH LEAD OUTPUT]` (no contracts) so the Reviewer's contract check skips cleanly. The Phase 3.5 retry loop always routes through the Tech Lead, so a localized fix that fails review escalates automatically. The terminal summary, run-log, and `Agents:`/`Timing:` lines list `debug(<model>)` after pm on Bug→Fix runs and include `tech-lead` only when the bug escalated; the `Root cause:` line is printed from `[DEBUG OUTPUT]` when present.
- **Relaxed Step 1.5 pre-flight for bug reports.** Bug→Fix runs no longer require a `## Acceptance criteria` section (a bug report's implicit criterion is "the reported behaviour no longer occurs"). Instead the hub looks for a reproduction signal (`reproduce` / `expected` / `actual`, or acceptance criteria) and only **warns** (does not exit) when none is found — the debug agent reconstructs repro steps from the report text. Spec→Code runs still require acceptance criteria.

## [1.7.1] — 2026-06-19

### Fixed
- **Tech Lead `agents.max_retries` is now live.** The blocker-resolution loop and the "max passes reached" error path now honour the `agents.max_retries` value read in Step 1 (default 3) instead of a hardcoded `3` — previously the config knob had no effect.
- **Tech Lead escalations no longer hang in autonomous runs.** Added a single **Escalation protocol**: standalone mode still waits for a human, but hub-dispatched / non-interactive mode applies a conservative default and records it under `Escalations made:` with an `[AUTO-DEFAULTED]` prefix, so high-risk (`[AUTH]`/`[BREAKING]`) and unresolvable-ambiguity blockers can't stall the pipeline waiting on an answer that may never arrive.

## [1.7.0] — 2026-06-19

### Added
- **Tech Lead persists a technical design doc** to `docs/design/<slug>.md` (previously the design lived only in the ephemeral `[TECH LEAD OUTPUT]` block). New `design.template.md`; new `docs.design` config option (defaults to `docs/design`); the unit-boundary `allow` list and the hub terminal summary include it.
- **Opinionated decision points** across `venture`, `ideation`, and `pm`: each now leads with a clear recommendation (marked pick, rationale) instead of a neutral menu, and proceeds on its recommendation when the user defers.

### Changed
- **PM is now pure product.** It owns the *what/why* only — no file paths, API shapes, or contracts. Its authored PRD drops the `## API contracts` and `## Data models` sections; `[PM OUTPUT]` drops `Changes needed:` and `Third-party API notes:`.
- **Tech Lead owns all technical work.** It reads the spec/PRD directly, absorbed the third-party API lookup (moved from PM), and derives contracts/schemas/tasks from the spec requirements + PM acceptance criteria.
- **Ideation emits the shared PRD shape** instead of its own mini-spec format, so every idea-to-spec path produces one consistent document.
- `init`/`refactor` now write a **minimal `units`-only `.nob.yml`** (no hardcoded `agents` block) and document `docs/specs` (PRDs) + `docs/design` in the generated `CLAUDE.md`.

### Fixed
- **Hub model defaults**: a minimal `.nob.yml` (no `agents.models`) now falls back to the documented per-agent defaults (dev/tech-lead/init/venture/refactor → sonnet) instead of flat `haiku`, so it behaves identically to a no-config run.
- **De-duplicated affected-file discovery** — removed PM's codebase grep; Tech Lead is now the sole discoverer.
- **Removed dead `[PLAN OUTPUT]` / Planner references** in `pm`, `reviewer`, and `spec.template.md` (the Planner was retired and merged into Tech Lead).
- **Unified stack detection on the `units` model** in `pm` and `ideation` (dropped the divergent frontend/backend binary detector); fixed ideation's `stack.docs.specs` → `docs.specs` path bug.
