# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob` and `/pm-agent`. There is no build system, no test runner, and no runtime — this repo contains only Markdown skill files and plugin metadata.

## Repo Structure

```
skills/
  nob/            — Hub orchestrator and sub-agent skills
    SKILL.md      — Hub skill: entry point for /nob
    planner/      — Breaks the spec into a sequenced plan (Mode: single or fan-out)
    pm-agent/     — Extracts structured requirements from specs (also standalone via /pm-agent)
    backend-agent/ — Implements backend/API changes
    frontend-agent/ — Implements frontend/UI changes
    qa-agent/     — Validates output against acceptance criteria
    reviewer/     — Final pass/fail review against the spec
    templates/    — CLAUDE.md.template and .nob.yml.template for user projects
  pm-agent/
    SKILL.md      — Standalone pm-agent skill (also used inside the nob pipeline)
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

**Planner → PM Agent → Backend Agent + Frontend Agent (concurrent) → QA Agent → Reviewer**

- The hub resolves `SKILL_BASE_DIR` at runtime from its `Base directory for this skill:` context line — all sub-skill paths use `{SKILL_BASE_DIR}/X/SKILL.md`.
- The hub reads `.nob.yml` from the user's project root to configure agent models, enabled agents, and parallelism. If absent, it auto-detects the stack.
- Checkpoints are written to `.nob/checkpoint.json` in the user's project to support resume after interruption.
- PM Agent has two modes: **spec-writing** (plain text idea → writes `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM-AGENT OUTPUT]` block).
- Planner produces either `Mode: single` (one pipeline) or `Mode: fan-out` (N parallel slice agents, each running a full mini-pipeline).

## Specs and Plans for This Repo

Feature specs live in `docs/superpowers/specs/` and implementation plans in `docs/superpowers/plans/`. These follow the Nob spec format but are about the plugin itself, not a user project.

## .nob.yml Template

Users configure their project by copying `skills/nob/templates/.nob.yml.template` to their project root. Key fields: `stack.frontend`, `stack.backend`, `agents.enabled`, `agents.models`, `agents.max_parallel_slices`, `agents.checkpoint`.
