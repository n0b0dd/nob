# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob` and `/pm`. There is no build system, no test runner, and no runtime — this repo is almost entirely Markdown skill files and plugin metadata, plus one shell hook (`hooks/unit-boundary.sh`).

## Repo Structure

```
skills/
  nob/            — Hub orchestrator (entry point for /nob)
    SKILL.md          — Hub skill: pure router (classify, route, git, config, Step 4 summary)
    checkpoint-gate/  — Pre-flight checkpoint check: runs first, alerts user, returns action
    path-full/        — Full path: PM→Debug→TL→Dev→Docs→Reviewer pipeline + Phase 0 resume scan
    retry/            — Retry loop: Phase 3.5 stuck/max/user-gate loop
    templates/        — CLAUDE.md.template, .nob.yml.template (minimal starter), .nob.yml.reference.yml (full annotated), spec.template.md
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

Each skill file (`SKILL.md`) is a self-contained instruction set dispatched via the Agent tool. The Nob hub (`skills/nob/SKILL.md`) classifies intent, reads config, and dispatches path-full for all implementation work. The hub prints the Step 4 terminal summary from path-full's output block.

**Hub → path-full → Reviewer**

All implementation workflows (Spec→Code, Bug→Fix, API→Sync) dispatch `path-full` directly. No routing, no inline path.

- **Full path** (`skills/nob/path-full/`) — PM → Debug (Bug→Fix only) → Tech Lead → Dev → Docs → Reviewer pipeline, delegates Phase 3.5 retry to `skills/nob/retry/`.

(PM is pure product — it owns the *what/why* and never touches code. Tech Lead owns all technical work — it discovers affected files, resolves any third-party API shapes, writes contracts + a flat task list, and **persists a technical design doc** to `docs/design/`. The dev agent self-manages parallel/sequential sub-agents per unit. Reviewer includes inline security scanning.)

On a **Bug→Fix** run inside `path-full`, a **debug** investigation runs after PM and routes by complexity:

- **PM → debug → dev → Reviewer** for a localized bug (IMPL_PATH = direct-dev), or
- **PM → debug → Tech Lead → dev → Reviewer** for a complicated bug (IMPL_PATH = tech-lead, escalated).

Debug diagnoses (reproduce → root cause with file:line → recommended fix + risk flags + suggested regression test) and emits `[DEBUG OUTPUT]` — it never edits code. `path-full` reads debug's self-reported complexity signals and sets IMPL_PATH:

- **Escalate to Tech Lead** if ANY of: ≥2 affected units, `[BREAKING]`/`[MIGRATION]`/`[AUTH]` risk, `Confidence: low`, or >4 files in the recommended fix. A `[AUTH]`/`[BREAKING]` risk also triggers a human confirm gate.
- **Direct dev** otherwise: `path-full` builds a minimal `[TECH LEAD SPEC]` from debug's recommended fix, dispatches dev directly, and synthesizes a stub `[TECH LEAD OUTPUT]` so the Reviewer's contract check skips cleanly.

The Phase 3.5 retry loop (`skills/nob/retry/`) always routes through Tech Lead — a localized fix that fails review naturally escalates.

- The hub resolves `SKILL_BASE_DIR` at runtime. Path skills at `skills/nob/path-*/` receive `Hub skill base dir: {SKILL_BASE_DIR}` via [INPUTS] and use it to reach sibling sub-skills (`{SKILL_BASE_DIR}/../tech-lead/SKILL.md`, etc.). The checkpoint-gate, retry, and path skills are all at `{SKILL_BASE_DIR}/<name>/SKILL.md`.
- The hub reads `.nob.yml` from the user's project root. If absent, it auto-detects the stack.
- **Checkpoint pre-flight** (`skills/nob/checkpoint-gate/`) runs as the very first agent call — before git, config, or any scan. It reads `.nob/checkpoint.json`, determines state (none / completed / interrupted), alerts the user interactively, and returns `[CHECKPOINT GATE OUTPUT]` with `Action: none | fresh | resume | cancel`. The hub routes from this before doing anything else. `--fresh` bypasses the gate entirely.
- **Resume flow**: when the gate returns `Action: resume`, the hub skips branch creation, worktree creation, spec preflight, and scope scan — it restores WORKTREE_PATH/BRANCH from the checkpoint and dispatches `path-full` directly with `ROUTE = full`. `path-full` Phase 0 handles task-level resume (which completed tasks to skip).
- Checkpoints are written to `.nob/checkpoint.json` by `path-full` (initial write at Phase 2 start, task statuses updated after dev, `reviewer_output` written after review).
- **Unit-boundary hook**: `hooks/hooks.json` registers a `PreToolUse` hook on `Edit|Write|MultiEdit|NotebookEdit`. Marker-gated: `path-full` writes `.nob/.boundary.json` at Phase 2 start; the hub removes it after the path skill returns. The hook fails open (no marker, missing `jq`, or parse error → allow) so it can never brick the pipeline. Disable via `agents.unit_boundary.enabled: false`.
- PM has two modes: **spec-writing** (plain text idea → writes a PRD to `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM OUTPUT]` block). PM stays product-only — no file paths or contracts; those belong to the Tech Lead.

## Specs and Plans for This Repo

Feature specs live in `docs/specs/` and technical design docs in `docs/design/`. These follow the Nob spec format but are about the plugin itself, not a user project.

## .nob.yml Template

`.nob.yml` is optional — the hub auto-detects the stack when it's absent (SKILL.md Step 1) and, on a config-less implement run, offers to save the detected `units` back to `.nob.yml` (Step 3). Two templates ship: `.nob.yml.template` is the **minimal starter** (just `units` + a pointer), and `.nob.yml.reference.yml` is the **full annotated reference** documenting every option. The only required field is `units` (list of project units — name, path, stack, optional `depends_on`); everything else (`agents.enabled`, `agents.models`, `agents.max_parallel_slices`, `agents.checkpoint`, `agents.unit_boundary`, …) has defaults.
