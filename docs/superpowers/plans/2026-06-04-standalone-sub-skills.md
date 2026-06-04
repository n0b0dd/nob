# Standalone Sub-Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every nob sub-skill independently user-invocable while keeping hub dispatch identical by adding Mode 0 detection to each skill and updating descriptions and CLAUDE.md.

**Architecture:** Each SKILL.md gains a `## Mode 0: Mode Detection` block that detects whether `[INPUTS]` is present (hub-dispatched) or absent (standalone). Self-sufficient skills fall through immediately; pipeline-dependent skills add a `### Standalone Inputs` subsection describing fallback behaviour. Hub overview and CLAUDE.md are updated to document standalone invocability.

**Tech Stack:** Markdown only — no build system, no test runner. "Testing" = reading the modified file and verifying the structure.

---

## File Map

| File | Change |
|---|---|
| `skills/nob/ideation/SKILL.md` | Fix frontmatter `name`, fix title style, add Mode 0 |
| `skills/nob/planner/SKILL.md` | Update description, add Mode 0 + Standalone Inputs |
| `skills/nob/backend/SKILL.md` | Update description, add Mode 0 + Standalone Inputs |
| `skills/nob/frontend/SKILL.md` | Update description, add Mode 0 + Standalone Inputs |
| `skills/nob/security/SKILL.md` | Update description, add Mode 0 + Standalone Inputs |
| `skills/nob/reviewer/SKILL.md` | Update description, add Mode 0 + Standalone Inputs |
| `skills/nob/init/SKILL.md` | Update description, add Mode 0 |
| `skills/nob/refactor/SKILL.md` | Update description, add Mode 0 |
| `skills/nob/ask/SKILL.md` | Update description, add Mode 0 |
| `skills/nob/SKILL.md` | Update `## Overview` paragraph |
| `CLAUDE.md` | List standalone sub-skills in Skill Architecture section |

---

### Task 1: Fix ideation frontmatter and title

`ideation` is the only sub-skill with a non-standard frontmatter name (`ideation` instead of `nob-ideation`) and a title that doesn't follow the `Nob — X Agent` pattern.

**Files:**
- Modify: `skills/nob/ideation/SKILL.md:1-11`

- [ ] **Step 1: Edit frontmatter name and description**

In `skills/nob/ideation/SKILL.md`, replace the entire frontmatter block and title line:

```
---
name: ideation
description: Reads an existing codebase and a user-provided direction + constraints, generates 3-5 ranked feature ideas, lets the user pick one, then expands it into a ready-to-run mini-spec saved to the project's configured spec directory.
---

# Ideation Agent
```

With:

```
---
name: nob-ideation
description: "Generates ranked feature ideas from an existing codebase and expands the chosen idea into a ready-to-run spec. Invocable via `/nob:ideation` directly or through the Nob hub. Triggers on: 'nob ideate', 'ideate', 'what should I build next', 'suggest features for', 'what feature should I add'."
---

# Nob — Ideation Agent
```

- [ ] **Step 2: Verify the change**

Open `skills/nob/ideation/SKILL.md` and confirm:
- `name:` is `nob-ideation`
- `# Nob — Ideation Agent` is the title line

- [ ] **Step 3: Commit**

```bash
git add skills/nob/ideation/SKILL.md
git commit -m "fix: standardise ideation skill name to nob-ideation"
```

---

### Task 2: Update descriptions — hub-only wording on pipeline-dependent skills

Five skills still say "Part of the Nob skill hub." or "Always invoked first by the Nob hub." in their description. Replace with standalone-aware wording.

**Files:**
- Modify: `skills/nob/planner/SKILL.md:3`
- Modify: `skills/nob/backend/SKILL.md:3`
- Modify: `skills/nob/frontend/SKILL.md:3`
- Modify: `skills/nob/security/SKILL.md:3`
- Modify: `skills/nob/reviewer/SKILL.md:3`

- [ ] **Step 1: Update planner description**

In `skills/nob/planner/SKILL.md`, replace:

```
description: Use when starting any Nob workflow. Reads the user's intent, CLAUDE.md, .nob.yml, and the referenced source file, then produces a sequenced execution plan identifying affected layers and agent order. Always invoked first by the Nob hub.
```

With:

```
description: "Use when starting any Nob workflow. Reads the user's intent, CLAUDE.md, .nob.yml, and the referenced source file, then produces a sequenced execution plan identifying affected layers and agent order. Invocable via `/nob:planner <spec-path>` directly or through the Nob hub."
```

- [ ] **Step 2: Update backend description**

In `skills/nob/backend/SKILL.md`, replace:

```
description: Use when implementing backend/API changes in a Nob workflow. Reads [PM OUTPUT] or [QA-AGENT OUTPUT] to understand what to build, explores existing backend codebase, implements following existing patterns, and outputs a structured [BACKEND OUTPUT] block. Part of the Nob skill hub.
```

With:

```
description: "Use when implementing backend/API changes. Reads [PM OUTPUT] to understand what to build, explores the existing backend codebase, implements following existing patterns, and outputs a structured [BACKEND OUTPUT] block. Invocable via `/nob:backend` directly or through the Nob hub."
```

- [ ] **Step 3: Update frontend description**

In `skills/nob/frontend/SKILL.md`, replace:

```
description: Use when implementing UI/frontend changes in a Nob workflow. Reads [PM OUTPUT] and [BACKEND OUTPUT] to understand what to build, explores existing frontend codebase, adapts to any stack declared in .nob.yml, and outputs a structured [FRONTEND OUTPUT] block. Part of the Nob skill hub.
```

With:

```
description: "Use when implementing UI/frontend changes. Reads [PM OUTPUT] to understand what to build, explores the existing frontend codebase, adapts to any stack declared in .nob.yml, and outputs a structured [FRONTEND OUTPUT] block. Invocable via `/nob:frontend` directly or through the Nob hub."
```

- [ ] **Step 4: Update security description**

In `skills/nob/security/SKILL.md`, replace:

```
description: Use after Backend and Frontend agents complete in a Nob workflow. Reads changed files from implementation outputs and checks them for security issues across four categories: OWASP/Mobile Top 10, secrets, dependencies, and infra misconfigs. Covers web and mobile stacks (Android, iOS, Flutter, React Native). Outputs a structured [SECURITY OUTPUT] block. Part of the Nob skill hub.
```

With:

```
description: "Reviews implementation outputs for security issues across four categories: OWASP/Mobile Top 10, secrets, dependencies, and infra misconfigs. Covers web and mobile stacks. Outputs a structured [SECURITY OUTPUT] block. Invocable via `/nob:security` directly or through the Nob hub."
```

- [ ] **Step 5: Update reviewer description**

In `skills/nob/reviewer/SKILL.md`, replace:

```
description: Use at the end of every Nob workflow. Reads all agent output blocks and validates them against the original spec's acceptance criteria. Produces a pass/fail checklist and a clear human review list. Part of the Nob skill hub.
```

With:

```
description: "Validates implementation outputs against the original spec's acceptance criteria. Produces a pass/fail checklist and a clear human review list. Invocable via `/nob:reviewer` directly or through the Nob hub."
```

- [ ] **Step 6: Verify all five files**

For each file, open it and confirm the description no longer contains "Part of the Nob skill hub." or "Always invoked first by the Nob hub." and now contains the `/nob:X` trigger phrase.

- [ ] **Step 7: Commit**

```bash
git add skills/nob/planner/SKILL.md skills/nob/backend/SKILL.md skills/nob/frontend/SKILL.md skills/nob/security/SKILL.md skills/nob/reviewer/SKILL.md
git commit -m "feat: update pipeline-dependent skill descriptions for standalone discoverability"
```

---

### Task 3: Update descriptions — self-sufficient skills

Three self-sufficient skills (`init`, `refactor`, `ask`) need descriptions updated to include standalone trigger phrases. (`ideation` was handled in Task 1.)

**Files:**
- Modify: `skills/nob/init/SKILL.md:3`
- Modify: `skills/nob/refactor/SKILL.md:3`
- Modify: `skills/nob/ask/SKILL.md:3`

- [ ] **Step 1: Update init description**

In `skills/nob/init/SKILL.md`, replace:

```
description: Scaffolds a complete runnable fullstack project from an empty directory. Called by the Nob hub when workflow is Init. Asks user to describe their project, recommends a tech stack, generates working boilerplate for the confirmed stack, runs dependency installation, and writes CLAUDE.md and .nob.yml.
```

With:

```
description: "Scaffolds a complete runnable fullstack project from an empty directory. Invocable via `/nob:init` directly or through the Nob hub. Triggers on: 'nob init', 'initialize project', 'scaffold project'."
```

- [ ] **Step 2: Update refactor description**

In `skills/nob/refactor/SKILL.md`, replace:

```
description: Migrates an existing project to nob's monorepo structure (apps/frontend/, apps/backend/, shared/core/). Analyzes the current layout, presents a migration plan, and executes on user approval. Moves directories with git history preservation, rewrites cross-layer import paths, and writes CLAUDE.md and .nob.yml.
```

With:

```
description: "Migrates an existing project to nob's monorepo structure (apps/frontend/, apps/backend/, shared/core/). Analyzes the current layout, presents a migration plan, and executes on user approval. Invocable via `/nob:refactor` directly or through the Nob hub. Triggers on: 'nob refactor', 'restructure project', 'migrate to nob structure'."
```

- [ ] **Step 3: Update ask description**

In `skills/nob/ask/SKILL.md`, replace:

```
description: Read-only codebase Q&A agent. Answers developer questions about the codebase with cited file paths. Uses grep, find, and Read only — writes nothing to disk.
```

With:

```
description: "Read-only codebase Q&A agent. Answers developer questions about the codebase with cited file paths. Uses grep, find, and Read only — writes nothing to disk. Invocable via `/nob:ask <question>` directly or through the Nob hub. Triggers on: 'nob ask', 'ask [question about codebase]'."
```

- [ ] **Step 4: Verify all three files**

Open each file and confirm the description contains the `/nob:X` trigger phrase and standalone trigger words.

- [ ] **Step 5: Commit**

```bash
git add skills/nob/init/SKILL.md skills/nob/refactor/SKILL.md skills/nob/ask/SKILL.md
git commit -m "feat: update self-sufficient skill descriptions for standalone discoverability"
```

---

### Task 4: Add Mode 0 to self-sufficient skills (init, refactor, ideation, ask)

These four skills need a `## Mode 0: Mode Detection` block. They have no `## Process` wrapper — their steps start directly with `## Step 1`. Mode 0 goes immediately before `## Step 1`.

**Files:**
- Modify: `skills/nob/init/SKILL.md` — before `## Step 1: Check directory is empty`
- Modify: `skills/nob/refactor/SKILL.md` — before `## Step 1: Analysis pass`
- Modify: `skills/nob/ideation/SKILL.md` — before `## Step 1: Read project context`
- Modify: `skills/nob/ask/SKILL.md` — before `## Process`

The Mode 0 block for self-sufficient skills (same text for all four, only the `## Process` placement differs):

```markdown
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. Use the current working directory as the working directory and the user's message as the intent. No prior agent output needed — proceed to Step 1.

```

- [ ] **Step 1: Add Mode 0 to init**

In `skills/nob/init/SKILL.md`, insert the Mode 0 block immediately before `## Step 1: Check directory is empty`.

- [ ] **Step 2: Add Mode 0 to refactor**

In `skills/nob/refactor/SKILL.md`, insert the Mode 0 block immediately before `## Step 1: Analysis pass`.

- [ ] **Step 3: Add Mode 0 to ideation**

In `skills/nob/ideation/SKILL.md`, insert the Mode 0 block immediately before `## Step 1: Read project context`.

- [ ] **Step 4: Add Mode 0 to ask**

`ask` has a `## Process` heading. Insert the Mode 0 block immediately after the `## Process` line and before `### Step 1: Parse the question`.

The exact insertion in `skills/nob/ask/SKILL.md`:

Replace:
```
## Process

### Step 1: Parse the question
```

With:
```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. Use the current working directory as the working directory and the user's message as the question. No prior agent output needed — proceed to Step 1.

## Process

### Step 1: Parse the question
```

- [ ] **Step 5: Verify all four files**

Open each file and confirm `## Mode 0: Mode Detection` appears before the first step, with both `Hub-dispatched mode` and `Standalone mode` bullet points present.

- [ ] **Step 6: Commit**

```bash
git add skills/nob/init/SKILL.md skills/nob/refactor/SKILL.md skills/nob/ideation/SKILL.md skills/nob/ask/SKILL.md
git commit -m "feat: add Mode 0 detection to self-sufficient sub-skills"
```

---

### Task 5: Add Mode 0 + Standalone Inputs to planner

Planner needs PM output only if running requirements extraction, but for standalone use it just needs a spec path. Simpler than backend/frontend.

**Files:**
- Modify: `skills/nob/planner/SKILL.md` — inside `## Process`, before `### Step 1: Read project context`

- [ ] **Step 1: Insert Mode 0 block**

In `skills/nob/planner/SKILL.md`, replace:

```
## Process

### Step 1: Read project context
```

With:

```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

Ask the user for the spec file path if not provided in their message. Use the current working directory. No prior agent output needed — proceed to Step 1 with the provided spec path as the source file.

## Process

### Step 1: Read project context
```

- [ ] **Step 2: Verify**

Open `skills/nob/planner/SKILL.md` and confirm:
- `## Mode 0: Mode Detection` block is present before `## Process`
- `### Standalone Inputs` subsection is present
- `## Process` and `### Step 1: Read project context` follow immediately after

- [ ] **Step 3: Commit**

```bash
git add skills/nob/planner/SKILL.md
git commit -m "feat: add Mode 0 and Standalone Inputs to planner"
```

---

### Task 6: Add Mode 0 + Standalone Inputs to backend and frontend

Both need PM output; frontend also optionally uses backend output. Mode 0 goes inside `## Process`, before the first `### Step`.

**Files:**
- Modify: `skills/nob/backend/SKILL.md` — inside `## Process`, before `### Step 1: Read configuration`
- Modify: `skills/nob/frontend/SKILL.md` — inside `## Process`, before `### Step 1: Read configuration`

The Standalone Inputs subsection for **backend**:

```markdown
### Standalone Inputs

1. Ask the user for the spec file path if not provided in their message.
2. Look for `.nob/pm-output.md` in the working directory — if found, use it as `[PM OUTPUT]`.
3. If not found, ask: "I need the PM output to proceed. Run `/nob:pm <spec-path>` first, or paste the PM output directly."
4. Proceed with whatever context is available.
```

The Standalone Inputs subsection for **frontend**:

```markdown
### Standalone Inputs

1. Ask the user for the spec file path if not provided in their message.
2. Look for `.nob/pm-output.md` in the working directory — if found, use it as `[PM OUTPUT]`.
3. If not found, ask: "I need the PM output to proceed. Run `/nob:pm <spec-path>` first, or paste the PM output directly."
4. Proceed with whatever context is available. Backend output is optional — if absent, use API contracts from the PM output.
```

- [ ] **Step 1: Insert Mode 0 + Standalone Inputs into backend**

In `skills/nob/backend/SKILL.md`, replace:

```
## Process

### Step 1: Read configuration
```

With:

```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

1. Ask the user for the spec file path if not provided in their message.
2. Look for `.nob/pm-output.md` in the working directory — if found, use it as `[PM OUTPUT]`.
3. If not found, ask: "I need the PM output to proceed. Run `/nob:pm <spec-path>` first, or paste the PM output directly."
4. Proceed with whatever context is available.

## Process

### Step 1: Read configuration
```

- [ ] **Step 2: Insert Mode 0 + Standalone Inputs into frontend**

In `skills/nob/frontend/SKILL.md`, replace:

```
## Process

### Step 1: Read configuration
```

With:

```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

1. Ask the user for the spec file path if not provided in their message.
2. Look for `.nob/pm-output.md` in the working directory — if found, use it as `[PM OUTPUT]`.
3. If not found, ask: "I need the PM output to proceed. Run `/nob:pm <spec-path>` first, or paste the PM output directly."
4. Proceed with whatever context is available. Backend output is optional — if absent, use API contracts from the PM output.

## Process

### Step 1: Read configuration
```

- [ ] **Step 3: Verify both files**

Open each file and confirm:
- `## Mode 0: Mode Detection` block appears before `## Process`
- `### Standalone Inputs` has the four numbered steps
- `## Process` and `### Step 1: Read configuration` follow immediately after

- [ ] **Step 4: Commit**

```bash
git add skills/nob/backend/SKILL.md skills/nob/frontend/SKILL.md
git commit -m "feat: add Mode 0 and Standalone Inputs to backend and frontend"
```

---

### Task 7: Add Mode 0 + Standalone Inputs to security

Security needs both backend and frontend outputs. Mode 0 goes inside `## Process`, before `### Step 1`.

**Files:**
- Modify: `skills/nob/security/SKILL.md` — inside `## Process`, before `### Step 1: Extract changed files`

- [ ] **Step 1: Insert Mode 0 + Standalone Inputs**

In `skills/nob/security/SKILL.md`, replace:

```
## Process

### Step 1: Extract changed files
```

With:

```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

1. Look for `.nob/backend-output.md` and `.nob/frontend-output.md` in the working directory — if found, use them as `[BACKEND OUTPUT]` and `[FRONTEND OUTPUT]`.
2. If not found, ask: "Which implementation outputs should I review? You can paste a `[BACKEND OUTPUT]` block, a `[FRONTEND OUTPUT]` block, or both."
3. Proceed with whatever context is provided.

## Process

### Step 1: Extract changed files
```

- [ ] **Step 2: Verify**

Open `skills/nob/security/SKILL.md` and confirm:
- `## Mode 0: Mode Detection` block appears before `## Process`
- `### Standalone Inputs` references `.nob/backend-output.md` and `.nob/frontend-output.md`
- `## Process` and `### Step 1: Extract changed files` follow immediately after

- [ ] **Step 3: Commit**

```bash
git add skills/nob/security/SKILL.md
git commit -m "feat: add Mode 0 and Standalone Inputs to security"
```

---

### Task 8: Add Mode 0 + Standalone Inputs to reviewer

Reviewer needs pm, backend, and frontend outputs plus the spec path. It already has `### Step 0: Detect input mode` — Mode 0 goes before that.

**Files:**
- Modify: `skills/nob/reviewer/SKILL.md` — inside `## Process`, before `### Step 0: Detect input mode`

- [ ] **Step 1: Insert Mode 0 + Standalone Inputs**

In `skills/nob/reviewer/SKILL.md`, replace:

```
## Process

### Step 0: Detect input mode
```

With:

```
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

1. Ask the user for the spec file path so acceptance criteria can be verified.
2. Look for `.nob/pm-output.md`, `.nob/backend-output.md`, and `.nob/frontend-output.md` in the working directory — use any that are found.
3. For any missing outputs, ask the user to paste them directly, or note that those criteria will be marked ⚠ partial.
4. Proceed to Step 0 with whatever context is available.

## Process

### Step 0: Detect input mode
```

- [ ] **Step 2: Verify**

Open `skills/nob/reviewer/SKILL.md` and confirm:
- `## Mode 0: Mode Detection` block appears before `## Process`
- `### Standalone Inputs` has the four numbered steps referencing all three `.nob/` output files
- `## Process` and `### Step 0: Detect input mode` follow immediately after

- [ ] **Step 3: Commit**

```bash
git add skills/nob/reviewer/SKILL.md
git commit -m "feat: add Mode 0 and Standalone Inputs to reviewer"
```

---

### Task 9: Update hub overview

The hub's `## Overview` paragraph needs a second paragraph documenting standalone invocability.

**Files:**
- Modify: `skills/nob/SKILL.md:6-13`

- [ ] **Step 1: Insert standalone paragraph into hub overview**

In `skills/nob/SKILL.md`, replace:

```
## Overview
Nob automates cross-layer development workflows in a fullstack monorepo. This hub reads the user's intent, identifies the workflow type, and invokes sub-skills in the correct sequence. Every run starts with the Planner and ends with the Reviewer.
```

With:

```
## Overview
Nob automates cross-layer development workflows in a fullstack monorepo. This hub reads the user's intent, identifies the workflow type, and invokes sub-skills in the correct sequence. Every run starts with the Planner and ends with the Reviewer.

Sub-skills (`/nob:planner`, `/nob:backend`, `/nob:frontend`, `/nob:security`, `/nob:reviewer`, `/nob:init`, `/nob:refactor`, `/nob:ideation`, `/nob:ask`) can be invoked directly for targeted work. When invoked via the hub, each sub-skill receives an `[INPUTS]` block with all required context and runs in hub-dispatched mode. When invoked standalone, each sub-skill sources inputs from `.nob/` output files or prompts the user.
```

- [ ] **Step 2: Verify**

Open `skills/nob/SKILL.md` and confirm the second paragraph listing all `/nob:X` commands is present after the first overview paragraph.

- [ ] **Step 3: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "docs: update hub overview to document standalone sub-skill invocability"
```

---

### Task 10: Update CLAUDE.md

CLAUDE.md says the plugin "ships as a set of skills invokable via `/nob` and `/pm`" — update to reflect all standalone sub-skills.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update "What This Repo Is" sentence**

In `CLAUDE.md`, replace:

```
**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob` and `/pm`. There is no build system, no test runner, and no runtime — this repo contains only Markdown skill files and plugin metadata.
```

With:

```
**Nob** is a Claude Code plugin that orchestrates cross-layer fullstack monorepo development. It ships as a set of skills invokable via `/nob`, `/nob:pm`, and standalone sub-skills (`/nob:planner`, `/nob:backend`, `/nob:frontend`, `/nob:security`, `/nob:reviewer`, `/nob:init`, `/nob:refactor`, `/nob:ideation`, `/nob:ask`). There is no build system, no test runner, and no runtime — this repo contains only Markdown skill files and plugin metadata.
```

- [ ] **Step 2: Update Skill Architecture section**

In `CLAUDE.md`, replace:

```
- PM has two modes: **spec-writing** (plain text idea → writes `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM OUTPUT]` block).
```

With:

```
- PM has two modes: **spec-writing** (plain text idea → writes `docs/specs/YYYY-MM-DD-slug.md`) and **requirements extraction** (file path → `[PM OUTPUT]` block).
- All sub-skills support **standalone invocation**: each SKILL.md has a `## Mode 0: Mode Detection` block. When `[INPUTS]` is present the skill runs in hub-dispatched mode; when absent it prompts the user or reads from `.nob/` output files.
```

- [ ] **Step 3: Verify**

Open `CLAUDE.md` and confirm:
- "What This Repo Is" paragraph lists the standalone sub-skills
- "Skill Architecture" bullet list includes the Mode 0 detection note

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to document standalone sub-skills and Mode 0 pattern"
```
