# Nob

A Claude Code plugin that orchestrates cross-layer fullstack monorepo development.

## What it does

Nob automates feature implementation, bug fixes, and API syncs across your full stack — backend, frontend, and QA — using a pipeline of specialized agents:

**Planner → PM Agent → Backend + Frontend (concurrent) → QA Agent → Reviewer**

## Install

```bash
claude plugin add n0b0dd/nob
```

## Usage

In any Claude Code session:

```
/nob implement docs/specs/my-feature.md
/nob fix docs/bugs/bug-report.md
/nob sync clients after docs/specs/api-change.md
```

## Configuration

Copy `skills/nob/templates/.nob.yml.template` to your project root as `.nob.yml` and fill in your stack details. If no `.nob.yml` is present, Nob auto-detects your frontend and backend.

## License

MIT
