# PM Agent Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `skills/nob/pm-agent/SKILL.md` to support dual-mode operation — spec-writing (plain text idea → codebase research → clarifying questions → spec file → optional Nob handoff) and requirements extraction (file path → structured output block, current behavior unchanged).

**Architecture:** Single file rewrite. Mode is auto-detected from the input at runtime. The Nob hub requires no changes — it always passes a file path, which routes to requirements extraction mode unchanged.

**Tech Stack:** Markdown skill file — no code, no tests. Verification is manual inspection of the file content and structure.

---

## File Structure

- Modify: `skills/nob/pm-agent/SKILL.md` — full rewrite with dual-mode logic

---

### Task 1: Rewrite `skills/nob/pm-agent/SKILL.md`

**Files:**
- Modify: `skills/nob/pm-agent/SKILL.md`

- [ ] **Step 1: Open the current file**

Run:
```bash
cat skills/nob/pm-agent/SKILL.md
```
Expected: current single-mode requirements extraction content.

- [ ] **Step 2: Write the new SKILL.md**

Overwrite `skills/nob/pm-agent/SKILL.md` with this exact content:

````markdown
---
name: nob-pm-agent
description: "Use directly to turn a rough idea into a spec file, or as part of the Nob pipeline to extract structured requirements from a spec. Triggers on: 'pm-agent [idea or spec path]'. Spec-writing mode: plain text input → research codebase → clarifying questions → write spec → optionally run /nob. Requirements mode: file path input → extract structured requirements block."
---

# Nob — PM Agent

## Overview
PM Agent owns all product definition work. It detects which mode to run from the input:
- **Plain text** → spec-writing mode: research codebase, ask clarifying questions, write a spec file
- **File path** → requirements extraction mode: read spec and output structured requirements for the engineering pipeline

---

## Step 0: Mode Detection

Inspect the input:

- Input contains `/` or ends in `.md` → go to **Requirements Extraction Mode**
- Input is plain text with no path characters → go to **Spec-Writing Mode**
- Ambiguous → ask: "Are you giving me a spec file path or a rough idea to turn into a spec?"

---

## Spec-Writing Mode

### Step 1: Read codebase context

Read these files if they exist (skip silently if not found):
- `CLAUDE.md` at the repo root
- `.nob.yml` at the repo root

Run stack auto-detection:

**Frontend** (first match wins):
1. `package.json` in `frontend/`, `web/`, `client/`, `app/` — check `dependencies`: `next` → Next.js · `vue` → Vue · `react` → React
2. `pubspec.yaml` → Flutter
3. `android/` directory → Android
4. `ios/Podfile` → iOS
5. None found → frontend not detected

**Backend** (first match wins):
1. `package.json` in `backend/`, `server/`, `api/` with `express`/`fastify`/`koa`/`hapi` → Node
2. `requirements.txt` or `pyproject.toml` in `backend/` → Python
3. `go.mod` in `backend/` → Go
4. `pom.xml` in `backend/` → Java
5. Check root level for same patterns
6. None found → backend not detected

Store result as STACK_CONTEXT.

### Step 2: Ask clarifying questions

Ask **one at a time** — wait for an answer before continuing:

1. "Who are the users of this feature?" (e.g. authenticated users, admins, guests)
2. "What is the core action they are trying to do? Describe the happy path in one sentence."
3. "Any constraints? (e.g. must work on mobile, requires auth, performance-critical)" — accept "none" as valid
4. "What is explicitly out of scope for this feature?" — accept "none" as valid

Store answers as CLARIFICATIONS.

### Step 3: Write spec file

Derive a slug from the idea: lowercase words, hyphens, max 5 words (e.g. "user notification system" → `user-notification-system`).

Ensure `docs/specs/` exists: run `mkdir -p docs/specs` using the Bash tool.

Write `docs/specs/YYYY-MM-DD-<slug>.md` using the Write tool with this structure:

```markdown
# Feature: [name]

## Summary
[one sentence describing what is being built]

## Users
[answer to question 1]

## Requirements
- [requirement derived from the idea and clarifying answers — specific and testable]
- [add as many as the idea and answers imply]

## Out of scope
- [answer to question 4, or: none specified]

## Open questions
- [any unresolved ambiguity, or: none]
```

Print: "Spec written to `docs/specs/<filename>.md`."

### Step 4: Offer implementation

Ask:
> "Ready to implement? I can hand this to the engineering pipeline now. (yes / no)"

- **yes** → invoke the `nob` skill with argument `implement docs/specs/<filename>.md`
- **no** → stop. Print: "Spec saved at `docs/specs/<filename>.md`. Run `/nob implement docs/specs/<filename>.md` when ready."

---

## Requirements Extraction Mode

### Step 1: Read the spec file

Use the Read tool to read the spec file path from the input (or from `[PLAN OUTPUT]` when called by the Nob hub).

### Step 2: Extract requirements

From the spec, extract:

1. **Feature name and summary** — one sentence
2. **Acceptance criteria** — convert every requirement into a testable checkbox. If vague, be specific and flag as an assumption.
3. **Backend changes needed** — HTTP method, path, request shape, response shape. If not specified: "not specified in spec — backend agent should infer from acceptance criteria"
4. **Frontend changes needed** — screen, component, user interaction. If not specified: "not specified in spec — frontend agent should infer from acceptance criteria"
5. **Edge cases** — explicitly mentioned only. If none: "none specified"
6. **Out of scope** — explicitly excluded. If none: "none specified"
7. **Ambiguities** — requirements that could be interpreted two ways, phrased as questions

### Step 3: Never invent requirements

Do NOT add anything not in the spec. Mark missing items as "not specified" and let implementation agents decide.

## Output Format

```
[PM-AGENT OUTPUT]
Feature: [name]
Summary: [one sentence]

Acceptance criteria:
- [ ] [specific, testable criterion]
- [ ] [specific, testable criterion]

Backend changes needed:
- [HTTP method] [/path]: request: [shape] → response: [shape]
- [or: not specified in spec — backend agent should infer from acceptance criteria]

Frontend changes needed:
- [screen/component]: [what changes]
- [or: not specified in spec — frontend agent should infer from acceptance criteria]

Edge cases to handle:
- [case, or: none specified]

Out of scope:
- [item, or: none specified]

Ambiguities flagged:
- [question about ambiguous requirement, or: none]
[/PM-AGENT OUTPUT]
```

## Error Handling
- **Spec file not found** (extraction mode): output "PM Agent cannot proceed — spec file [path] not found."
- **Spec is one-liners with no detail**: extract what exists, flag every missing dimension as an ambiguity
- **Spec has contradictions**: flag each contradiction in Ambiguities
- **`docs/specs/` cannot be created**: warn user and ask for an alternative path
````

- [ ] **Step 3: Verify the file was written correctly**

Run:
```bash
head -5 skills/nob/pm-agent/SKILL.md
```
Expected:
```
---
name: nob-pm-agent
description: "Use directly to turn a rough idea into a spec file...
```

Run:
```bash
grep -n "Mode Detection\|Spec-Writing Mode\|Requirements Extraction Mode\|Output Format\|Error Handling" skills/nob/pm-agent/SKILL.md
```
Expected: all five section headers present with line numbers.

- [ ] **Step 4: Verify Nob hub is unchanged**

Run:
```bash
grep -n "pm-agent" skills/nob/SKILL.md
```
Expected: lines referencing `{SKILL_BASE_DIR}/pm-agent/SKILL.md` — no changes needed.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/pm-agent/SKILL.md
git commit -m "feat: redesign pm-agent as dual-mode standalone skill"
```
Expected: 1 file changed.
