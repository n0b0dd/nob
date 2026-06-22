# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob` and `/pm`. There is no build system, no test runner, and no runtime — this repo is almost entirely Markdown skill files and plugin metadata, plus one shell hook (`hooks/unit-boundary.sh`).

## Repo Structure

```
skills/
  nob/            — Hub orchestrator (entry point for /nob)
    SKILL.md      — Hub skill: entry point for /nob
    templates/    — CLAUDE.md.template, .nob.yml.template (minimal starter), .nob.yml.reference.yml (full annotated), spec.template.md
  pm/             — PM skill: spec-writing and requirements extraction (/nob:pm)
  tech-lead/      — Technical lead: writes contracts + task list (/nob:tech-lead)
  dev/            — Implements changes per declared units (/nob:dev)
    stacks/       — Per-stack implementation helpers (e.g. nextjs.md, rails.md)
  debug/          — Investigates a bug, finds root cause, recommends a fix (read-only) (/nob:debug)
  reviewer/       — Final pass/fail review + inline security scan (/nob:reviewer)
  init/           — Scaffolds a new fullstack project (/nob:init)
  ideation/       — Generates ranked feature ideas from an existing codebase (/nob:ideation)
  refactor/       — Migrates a project to nob's monorepo structure (/nob:refactor)
  venture/        — End-to-end venture validation pipeline (/nob:venture)
.claude-plugin/
  plugin.json     — Plugin manifest (name, version, author)
  marketplace.json — Marketplace listing
hooks/
  hooks.json      — Plugin hook config (auto-discovered; PreToolUse → unit-boundary.sh)
  unit-boundary.sh — PreToolUse guard: blocks dev edits outside declared unit paths during a run
docs/
  specs/          — Feature specs (PM writes here)
  design/         — Technical design docs (Tech Lead writes here)
```

## Plugin Versioning

Version is tracked in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Bump both together on every release.

## Skill Architecture

Each skill file (`SKILL.md`) is a self-contained instruction set dispatched via the Agent tool. The Nob hub (`skills/nob/SKILL.md`) orchestrates all sub-skills:

**PM → Tech Lead → dev → Reviewer**

(PM is pure product — it owns the *what/why* and never touches code. Tech Lead owns all technical work — it discovers affected files, resolves any third-party API shapes, writes contracts + a flat task list, and **persists a technical design doc** to `docs/design/`. The dev agent self-manages parallel/sequential sub-agents per unit. Reviewer includes inline security scanning.)

On a **Bug→Fix** run a **debug** investigation runs first and then the hub *routes by how complicated the fix is*:

- **PM → debug → dev → Reviewer** for a localized bug (the fast path), or
- **PM → debug → Tech Lead → dev → Reviewer** for a complicated bug (the escalated path).

The hub dispatches the **read-only** debug agent right after PM. Debug diagnoses (reproduce → root cause with file:line → recommended fix + risk flags + a *suggested* regression test) and emits `[DEBUG OUTPUT]` — it never edits code. The hub then reads debug's own self-reported complexity signals and sets `IMPL_PATH`:

- **Escalate to Tech Lead** if ANY of: ≥2 affected units, a `[BREAKING]`/`[MIGRATION]`/`[AUTH]` risk, `Confidence: low`, or >4 files in the recommended fix. The Tech Lead receives the diagnosis (it does **not** re-run debug), plans a sequenced task graph, gates risk, dispatches dev, and runs the blocker loop.
- **Direct dev** otherwise: the hub builds a minimal `[TECH LEAD SPEC]` task list straight from debug's recommended fix and dispatches `dev`, skipping the Tech Lead. It synthesizes a stub `[TECH LEAD OUTPUT]` (no contracts) so the Reviewer's contract check skips cleanly.

A `[AUTH]`/`[BREAKING]` risk also triggers a **human confirm gate** before any code is written. The Phase 3.5 retry loop always routes through the Tech Lead, so a localized fix that fails review naturally escalates. `dev` does all code changes (its usual flow, including running tests); Reviewer, checkpoint, and the retry loop are unchanged. Debug reuses `skills/dev/stacks/` for per-stack context; its model defaults to `agents.models.debug` → `agents.models.dev` → `sonnet`.

- The hub resolves `SKILL_BASE_DIR` at runtime from its `Base directory for this skill:` context line — all sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md` (sub-skills live one level up from the hub at `skills/X/`).
- The hub reads `.nob.yml` from the user's project root to configure models, enabled skills, and parallelism. If absent, it auto-detects the stack.
- Checkpoints are written to `.nob/checkpoint.json` in the user's project to support resume after interruption.
- **Unit-boundary hook**: `hooks/hooks.json` registers a `PreToolUse` hook (`hooks/unit-boundary.sh`) on `Edit|Write|MultiEdit|NotebookEdit`. It is marker-gated: the hub writes `.nob/.boundary.json` (`{ worktree, allow }`) at Phase 2 and removes it at Step 4, so the guard is active only during a run's dev/review work. The hook polices only edits *inside* the run's worktree, denying any that fall outside the declared unit paths (plus `.nob/`, the docs dirs, and `.nob.yml`). It fails open (no marker, missing `jq`, or any parse issue → allow) so it can never brick the pipeline. Disable via `agents.unit_boundary.enabled: false`.
- PM has two modes: **spec-writing** (plain text idea → writes a pure-product PRD to `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM OUTPUT]` block). In both, PM stays product-only — no file paths, API shapes, or contracts; those are the Tech Lead's. The Tech Lead reads the PRD directly, owns affected-file discovery and third-party API resolution, and persists its design to `docs/design/`.

## Specs and Plans for This Repo

Feature specs live in `docs/specs/` and technical design docs in `docs/design/`. These follow the Nob spec format but are about the plugin itself, not a user project.

## .nob.yml Template

`.nob.yml` is optional — the hub auto-detects the stack when it's absent (SKILL.md Step 1) and, on a config-less implement run, offers to save the detected `units` back to `.nob.yml` (Step 3). Two templates ship: `.nob.yml.template` is the **minimal starter** (just `units` + a pointer), and `.nob.yml.reference.yml` is the **full annotated reference** documenting every option. The only required field is `units` (list of project units — name, path, stack, optional `depends_on`); everything else (`agents.enabled`, `agents.models`, `agents.max_parallel_slices`, `agents.checkpoint`, `agents.unit_boundary`, …) has defaults.
