# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob` and `/pm`. There is no build system, no test runner, and no runtime — this repo contains only Markdown skill files and plugin metadata.

## Repo Structure

```
skills/
  nob/            — Hub orchestrator (entry point for /nob)
    SKILL.md      — Hub skill: entry point for /nob
    templates/    — CLAUDE.md.template and .nob.yml.template for user projects
  pm/             — PM skill: spec-writing and requirements extraction (/nob:pm)
  planner/        — Breaks the spec into a sequenced plan (/nob:planner)
  backend/        — Implements backend/API changes (/nob:backend)
  frontend/       — Implements frontend/UI changes (/nob:frontend)
  security/       — Reviews implementation for security findings (/nob:security)
  reviewer/       — Final pass/fail review against the spec (/nob:reviewer)
  init/           — Scaffolds a new fullstack project (/nob:init)
  ideation/       — Generates ranked feature ideas from an existing codebase (/nob:ideation)
  refactor/       — Migrates a project to nob's monorepo structure (/nob:refactor)
  ask/            — Read-only codebase Q&A (/nob:ask)
  slice-runner/   — Runs a single fan-out slice mini-pipeline
  venture-workflow/ — End-to-end venture validation pipeline
  idea-framer/    — First agent in the Venture pipeline
  market-researcher/ — Second agent in the Venture pipeline
  business-modeler/ — Third agent in the Venture pipeline
  gtm-strategist/ — Fourth agent in the Venture pipeline
  financial-modeler/ — Fifth agent in the Venture pipeline
  venture-reviewer/ — Final agent in the Venture pipeline
.claude-plugin/
  plugin.json     — Plugin manifest (name, version, author)
  marketplace.json — Marketplace listing
docs/
  superpowers/
    specs/        — Feature specs for this repo itself
    plans/        — Implementation plans for this repo itself
```

## Plugin Versioning

Version is tracked in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Bump both together on every release.

## Skill Architecture

Each skill file (`SKILL.md`) is a self-contained instruction set dispatched via the Agent tool. The Nob hub (`skills/nob/SKILL.md`) orchestrates all sub-skills:

**Planner → PM → Backend + Frontend (concurrent) → Security → Reviewer**

- The hub resolves `SKILL_BASE_DIR` at runtime from its `Base directory for this skill:` context line — all sub-skill paths use `{SKILL_BASE_DIR}/../X/SKILL.md` (sub-skills live one level up from the hub at `skills/X/`).
- The hub reads `.nob.yml` from the user's project root to configure models, enabled skills, and parallelism. If absent, it auto-detects the stack.
- Checkpoints are written to `.nob/checkpoint.json` in the user's project to support resume after interruption.
- PM has two modes: **spec-writing** (plain text idea → writes `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM OUTPUT]` block).
- Planner produces either `Mode: single` (one pipeline) or `Mode: fan-out` (N parallel slices, each running a full mini-pipeline).

## Specs and Plans for This Repo

Feature specs live in `docs/superpowers/specs/` and implementation plans in `docs/superpowers/plans/`. These follow the Nob spec format but are about the plugin itself, not a user project.

## .nob.yml Template

Users configure their project by copying `skills/nob/templates/.nob.yml.template` to their project root. Key fields: `stack.frontend`, `stack.backend`, `agents.enabled`, `agents.models`, `agents.max_parallel_slices`, `agents.checkpoint`.
