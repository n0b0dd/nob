# Nob

A Claude Code plugin that orchestrates cross-layer fullstack monorepo development.

## What it does

Nob automates feature implementation, bug fixes, and API syncs across your full stack — backend, frontend, and security — using a pipeline of specialized agents:

**Planner → PM Agent → Backend + Frontend (concurrent) → Security Review → Reviewer**

## Install

Nob is not listed in Claude's official marketplace, so you need to register this GitHub repo as a plugin source first, then install from it:

```bash
# 1. Register this repo as a plugin source (only needed once)
claude plugin marketplace add n0b0dd/nob

# 2. Install the plugin from that source
claude plugin install nob@nob
```

Restart Claude Code after installing. No additional settings or config changes are required — the plugin is ready to use immediately.

## Update

When a new version is released, pull the latest from GitHub and restart Claude Code:

```bash
claude plugin update nob@nob
```

## Usage

In any Claude Code session in your project:

```
/nob implement docs/specs/my-feature.md
/nob fix docs/bugs/bug-report.md
/nob sync clients after docs/specs/api-change.md
/nob refactor
```

## Configuration (optional)

By default, Nob auto-detects your frontend and backend stack. For explicit control over paths, models, and enabled agents, copy `skills/nob/templates/.nob.yml.template` to your project root as `.nob.yml` and fill in your stack details.

## License

MIT
