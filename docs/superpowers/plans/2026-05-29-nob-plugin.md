# Nob Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the monoagent skill as a Claude Code plugin named "nob", renaming all branding and making sub-skill paths portable via runtime base-directory resolution.

**Architecture:** Copy the 9 monoagent skill files into `skills/nob/`, apply sed-based bulk renames (monoagent→nob, MonoAgent→Nob), replace hardcoded `~/.claude/skills/monoagent/` paths in the hub with `{SKILL_BASE_DIR}/` (resolved at runtime from the Claude Code system context line `Base directory for this skill:`), and add a `.claude-plugin/plugin.json` manifest.

**Tech Stack:** Markdown skill files, bash (sed, cp, grep), git

---

### Task 1: Create directory structure and plugin manifest

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `skills/nob/` and all subdirectories

- [ ] **Step 1: Create all directories**

Run from `/Users/virun-kosign/Desktop/nob`:
```bash
mkdir -p .claude-plugin skills/nob/planner skills/nob/pm-agent skills/nob/backend-agent skills/nob/frontend-agent skills/nob/qa-agent skills/nob/reviewer skills/nob/templates
```
Expected: no output, exit 0

- [ ] **Step 2: Write plugin manifest**

Write `.claude-plugin/plugin.json` with this exact content:
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

- [ ] **Step 3: Verify directory structure**

Run: `find . -not -path './.git/*' -type d | sort`
Expected to include:
```
./.claude-plugin
./skills
./skills/nob
./skills/nob/backend-agent
./skills/nob/frontend-agent
./skills/nob/planner
./skills/nob/pm-agent
./skills/nob/qa-agent
./skills/nob/reviewer
./skills/nob/templates
```

- [ ] **Step 4: Verify plugin.json is valid JSON**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('valid')"`
Expected: `valid`

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/
git commit -m "chore: scaffold plugin directory structure and manifest"
```

---

### Task 2: Copy source skill files into plugin structure

**Files:**
- Create: `skills/nob/SKILL.md`
- Create: `skills/nob/planner/SKILL.md`
- Create: `skills/nob/pm-agent/SKILL.md`
- Create: `skills/nob/backend-agent/SKILL.md`
- Create: `skills/nob/frontend-agent/SKILL.md`
- Create: `skills/nob/qa-agent/SKILL.md`
- Create: `skills/nob/reviewer/SKILL.md`
- Create: `skills/nob/templates/.nob.yml.template`
- Create: `skills/nob/templates/CLAUDE.md.template`

- [ ] **Step 1: Copy all skill files**

Run:
```bash
cp ~/.claude/skills/monoagent/SKILL.md skills/nob/SKILL.md
cp ~/.claude/skills/monoagent/planner/SKILL.md skills/nob/planner/SKILL.md
cp ~/.claude/skills/monoagent/pm-agent/SKILL.md skills/nob/pm-agent/SKILL.md
cp ~/.claude/skills/monoagent/backend-agent/SKILL.md skills/nob/backend-agent/SKILL.md
cp ~/.claude/skills/monoagent/frontend-agent/SKILL.md skills/nob/frontend-agent/SKILL.md
cp ~/.claude/skills/monoagent/qa-agent/SKILL.md skills/nob/qa-agent/SKILL.md
cp ~/.claude/skills/monoagent/reviewer/SKILL.md skills/nob/reviewer/SKILL.md
cp ~/.claude/skills/monoagent/templates/.monoagent.yml.template skills/nob/templates/.nob.yml.template
cp ~/.claude/skills/monoagent/templates/CLAUDE.md.template skills/nob/templates/CLAUDE.md.template
```
Expected: no output, exit 0

- [ ] **Step 2: Verify all 9 files exist**

Run: `find skills/nob -type f | sort`
Expected:
```
skills/nob/SKILL.md
skills/nob/backend-agent/SKILL.md
skills/nob/frontend-agent/SKILL.md
skills/nob/planner/SKILL.md
skills/nob/pm-agent/SKILL.md
skills/nob/qa-agent/SKILL.md
skills/nob/reviewer/SKILL.md
skills/nob/templates/.nob.yml.template
skills/nob/templates/CLAUDE.md.template
```

- [ ] **Step 3: Verify source branding is present (pre-rename sanity check)**

Run: `grep -rl "monoagent" skills/nob/ | wc -l | tr -d ' '`
Expected: `8` (CLAUDE.md.template has no monoagent references)

---

### Task 3: Apply all monoagent→nob renames

**Files:**
- Modify: all files in `skills/nob/`

Order of operations matters — path substitution happens before the bulk lowercase rename.

- [ ] **Step 1: Fix error message in hub before bulk replacements**

The hub's error handling section contains:
`ensure ~/.claude/skills/monoagent/ is installed correctly`

Replace it with the plugin-aware message:
```bash
sed -i '' 's|ensure ~/.claude/skills/monoagent/ is installed correctly|ensure the nob plugin is installed correctly|' skills/nob/SKILL.md
```
Expected: no output, exit 0

Verify:
```bash
grep "ensure the nob plugin is installed correctly" skills/nob/SKILL.md
```
Expected: one matching line

- [ ] **Step 2: Replace hardcoded skill paths with SKILL_BASE_DIR variable (hub only)**

```bash
sed -i '' 's|~/.claude/skills/monoagent/|{SKILL_BASE_DIR}/|g' skills/nob/SKILL.md
```
Expected: no output, exit 0

Verify no raw skill paths remain:
```bash
grep "~/.claude/skills/monoagent" skills/nob/SKILL.md
```
Expected: no output

- [ ] **Step 3: Replace MonoAgent (title-cased) in all files**

```bash
find skills/nob -type f -exec sed -i '' 's/MonoAgent/Nob/g' {} \;
```
Expected: no output, exit 0

- [ ] **Step 4: Replace monoagent (lowercase) in all files**

```bash
find skills/nob -type f -exec sed -i '' 's/monoagent/nob/g' {} \;
```
Expected: no output, exit 0

This single command handles all of:
- `monoagent-planner` → `nob-planner` (frontmatter name fields)
- `.monoagent.yml` → `.nob.yml` (config file references)
- `.monoagent/` → `.nob/` (checkpoint dir and gitignore entry)
- `monoagent/<spec>` → `nob/<spec>` (branch prefix)
- `monoagent.yml contents` → `nob.yml contents` (field names in prompt templates)

- [ ] **Step 5: Verify no monoagent or MonoAgent references remain**

Run: `grep -r "monoagent" skills/nob/`
Expected: no output

Run: `grep -r "MonoAgent" skills/nob/`
Expected: no output

- [ ] **Step 6: Verify key renames applied correctly in hub**

Check terminal output line:
```bash
grep "Nob complete" skills/nob/SKILL.md
```
Expected: `Nob complete.`

Check branch prefix:
```bash
grep "nob/<spec" skills/nob/SKILL.md
```
Expected: line containing `nob/<spec-or-bug-filename-without-extension>`

Check .nob.yml references:
```bash
grep "\.nob\.yml" skills/nob/SKILL.md | wc -l | tr -d ' '
```
Expected: `9` or more

Check checkpoint dir:
```bash
grep "\.nob/" skills/nob/SKILL.md | head -3
```
Expected: lines showing `.nob/` as checkpoint path

- [ ] **Step 7: Verify sub-skill frontmatter names updated**

```bash
head -3 skills/nob/planner/SKILL.md
```
Expected:
```
---
name: nob-planner
description: Use when starting any Nob workflow...
```

```bash
head -3 skills/nob/backend-agent/SKILL.md
```
Expected:
```
---
name: nob-backend-agent
```

- [ ] **Step 8: Commit**

```bash
git add skills/nob/
git commit -m "feat: copy monoagent files and rename all branding to nob"
```

---

### Task 4: Add base-directory setup section to hub SKILL.md

**Files:**
- Modify: `skills/nob/SKILL.md`

The hub currently uses `{SKILL_BASE_DIR}/X/SKILL.md` as path references (set in Task 3), but doesn't yet instruct Claude how to resolve SKILL_BASE_DIR. Claude Code injects a `Base directory for this skill: <path>` line in the system context when a skill is loaded. The new section instructs Claude to read that line.

- [ ] **Step 1: Insert the setup section**

In `skills/nob/SKILL.md`, find the exact text:
```
The hub's own context stays under ~10k tokens regardless of codebase size.

## Step 0: Git branch safety
```

Replace it with:
```
The hub's own context stays under ~10k tokens regardless of codebase size.

## Setup: Resolve skill base directory

Read the system context for a line starting with `Base directory for this skill:`. Extract the path and store it as SKILL_BASE_DIR. Every sub-skill path in this document is written as `{SKILL_BASE_DIR}/X/SKILL.md` — replace `{SKILL_BASE_DIR}` with the extracted path before using the Read tool.

Example: if the system context shows `Base directory for this skill: /home/user/.claude/plugins/cache/n0b0dd/nob/1.0.0/skills/nob`, then SKILL_BASE_DIR is `/home/user/.claude/plugins/cache/n0b0dd/nob/1.0.0/skills/nob`.

---

## Step 0: Git branch safety
```

- [ ] **Step 2: Verify setup section is present**

Run: `grep -c "Resolve skill base directory" skills/nob/SKILL.md`
Expected: `1`

Run: `grep -c "SKILL_BASE_DIR" skills/nob/SKILL.md`
Expected: ≥ 12

- [ ] **Step 3: Verify setup section appears before Step 0**

Run: `grep -n "Resolve skill base directory\|Step 0: Git" skills/nob/SKILL.md`
Expected: "Resolve skill base directory" line number is lower than "Step 0: Git branch safety"

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add SKILL_BASE_DIR resolution for portable plugin paths"
```

---

### Task 5: Create README.md and LICENSE

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Write README.md**

Write `README.md` with this content:
```markdown
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
```

- [ ] **Step 2: Write LICENSE**

Write `LICENSE` with this content:
```
MIT License

Copyright (c) 2026 n0b0dd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: add README and MIT license"
```

---

### Task 6: Final verification

- [ ] **Step 1: Confirm no monoagent references anywhere in repo**

Run: `grep -r "monoagent" . --exclude-dir=.git`
Expected: no output

Run: `grep -r "MonoAgent" . --exclude-dir=.git`
Expected: no output

- [ ] **Step 2: Confirm complete file structure**

Run: `find . -not -path './.git/*' -type f | sort`
Expected:
```
./.claude-plugin/plugin.json
./LICENSE
./README.md
./docs/superpowers/plans/2026-05-29-nob-plugin.md
./docs/superpowers/specs/2026-05-29-nob-plugin-design.md
./skills/nob/SKILL.md
./skills/nob/backend-agent/SKILL.md
./skills/nob/frontend-agent/SKILL.md
./skills/nob/planner/SKILL.md
./skills/nob/pm-agent/SKILL.md
./skills/nob/qa-agent/SKILL.md
./skills/nob/reviewer/SKILL.md
./skills/nob/templates/.nob.yml.template
./skills/nob/templates/CLAUDE.md.template
```

- [ ] **Step 3: Confirm hub frontmatter name is nob**

Run: `head -3 skills/nob/SKILL.md`
Expected:
```
---
name: nob
```

- [ ] **Step 4: Confirm SKILL_BASE_DIR instruction is in hub**

Run: `grep "Resolve skill base directory" skills/nob/SKILL.md`
Expected: `## Setup: Resolve skill base directory`

- [ ] **Step 5: Confirm plugin.json is valid JSON**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('valid')"`
Expected: `valid`
