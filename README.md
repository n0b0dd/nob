# Nob

A spec-driven Claude Code plugin built for the 1-person team that needs to operate like five.

## The problem

A solo developer juggles every role: PM, architect, backend, frontend, reviewer. Most AI coding tools make each role faster — but you still have to coordinate between them yourself. That context-switching is where time and quality get lost.

## What Nob does

You give Nob a spec or a rough idea. It runs the entire dev cycle as a structured agent pipeline:

**PM (PRD) → Tech Lead (design: contracts + tasks) → dev (parallel/sequential per unit) → Reviewer (incl. inline security)**

Each agent is specialized and receives only what it needs. The Tech Lead writes contracts and a flat task list before the dev agent runs — so all units start from a shared, consistent interface. The dev agent runs independent units concurrently and dependent ones in order. The Reviewer blocks completion until the output meets the spec. You step in only when a decision genuinely requires a human.

## What you get

- **PM** turns a rough idea into a pure-product PRD (the *what/why*) so nothing starts from ambiguity
- **Tech Lead** owns the *how* — defines contracts upfront, persists a technical design doc, and keeps all units aligned
- **dev agent** runs independent units concurrently and dependent ones in order — work that would take a solo dev multiple context-switches happens automatically
- **Reviewer** gives you a pass/fail with a diff to scan, not a debugging session to start
- **Checkpoint/resume** means long runs survive interruption — you don't babysit the pipeline

## Why it's different

Most AI coding tools still require a human to coordinate between layers — write the spec, then prompt the backend, then prompt the frontend, then review. Nob removes those handoffs. The pipeline is the workflow.

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

By default, Nob auto-detects your stack — and on the first config-less run it offers to save the detected units to `.nob.yml` for you. For explicit control, copy the minimal starter `skills/nob/templates/.nob.yml.template` to your project root as `.nob.yml` and declare your `units`. Only `units` is required; every other setting (models, parallelism, CI, checkpoint, the unit-boundary guard) is optional with sensible defaults — see the full annotated `skills/nob/templates/.nob.yml.reference.yml` to override any of them.

## License

MIT
