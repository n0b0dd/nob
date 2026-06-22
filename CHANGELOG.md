# Changelog

All notable changes to the nob plugin are documented here. Versions are bumped in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

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
