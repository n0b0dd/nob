# Nob Plugin Design

**Date:** 2026-05-29  
**Repo:** github.com/n0b0dd/nob  
**Status:** Approved

## Overview

Rename the `monoagent` skill to `nob` and package it as a Claude Code plugin. The plugin is published at `github.com/n0b0dd/nob` and installed via `claude plugin add n0b0dd/nob`. Users invoke the skill as `/nob`.

## File Structure

```
nob/
├── .claude-plugin/
│   └── plugin.json             ← plugin manifest
├── skills/
│   └── nob/                    ← skill directory (invoked as /nob)
│       ├── SKILL.md            ← hub orchestrator
│       ├── planner/
│       │   └── SKILL.md
│       ├── pm-agent/
│       │   └── SKILL.md
│       ├── backend-agent/
│       │   └── SKILL.md
│       ├── frontend-agent/
│       │   └── SKILL.md
│       ├── qa-agent/
│       │   └── SKILL.md
│       ├── reviewer/
│       │   └── SKILL.md
│       └── templates/
│           ├── .nob.yml.template
│           └── CLAUDE.md.template
├── README.md
└── LICENSE
```

## Plugin Manifest (.claude-plugin/plugin.json)

```json
{
  "name": "nob",
  "description": "Orchestrates cross-layer fullstack monorepo development: Planner → PM Agent → Backend Agent → Frontend Agent → Reviewer",
  "version": "1.0.0",
  "author": { "name": "n0b0dd" },
  "homepage": "https://github.com/n0b0dd/nob",
  "repository": "https://github.com/n0b0dd/nob",
  "license": "MIT"
}
```

## Path Resolution (Base-Directory-Relative)

The hub `SKILL.md` currently hardcodes `~/.claude/skills/monoagent/X/SKILL.md`. In the plugin, these become dynamic:

At the top of `skills/nob/SKILL.md`, Claude is instructed to extract the `Base directory for this skill:` path from the system context (injected by Claude Code at skill load time) and store it as `SKILL_BASE_DIR`. All sub-skill reads then use `{SKILL_BASE_DIR}/planner/SKILL.md`, `{SKILL_BASE_DIR}/pm-agent/SKILL.md`, etc.

This makes the plugin portable — it works at any install path and any version.

## Rename Changes

| Old | New |
|-----|-----|
| `~/.claude/skills/monoagent/X/SKILL.md` | `{SKILL_BASE_DIR}/X/SKILL.md` |
| `.monoagent.yml` | `.nob.yml` |
| `.monoagent/` (checkpoint dir) | `.nob/` |
| `monoagent/<spec>` (branch prefix) | `nob/<spec>` |
| `MonoAgent complete.` | `Nob complete.` |
| `# MonoAgent configuration` | `# Nob configuration` |
| `ensure ~/.claude/skills/monoagent/ is installed correctly` | `ensure the nob plugin is installed correctly` |
| All other `monoagent` / `MonoAgent` text | `nob` / `Nob` |

Applies to: hub SKILL.md, all 6 sub-skill SKILL.md files, both templates.

## Source Files

Copied from `~/.claude/skills/monoagent/` (9 files total):
- `SKILL.md` → `skills/nob/SKILL.md`
- `planner/SKILL.md` → `skills/nob/planner/SKILL.md`
- `pm-agent/SKILL.md` → `skills/nob/pm-agent/SKILL.md`
- `backend-agent/SKILL.md` → `skills/nob/backend-agent/SKILL.md`
- `frontend-agent/SKILL.md` → `skills/nob/frontend-agent/SKILL.md`
- `qa-agent/SKILL.md` → `skills/nob/qa-agent/SKILL.md`
- `reviewer/SKILL.md` → `skills/nob/reviewer/SKILL.md`
- `templates/.monoagent.yml.template` → `skills/nob/templates/.nob.yml.template`
- `templates/CLAUDE.md.template` → `skills/nob/templates/CLAUDE.md.template`

## Out of Scope

- Modifying sub-skill logic or adding new agents
- Publishing to a plugin marketplace
- Removing the original `~/.claude/skills/monoagent/` installation
