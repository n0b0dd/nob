# Changelog

All notable changes to the nob plugin are documented here. Versions are bumped in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

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
