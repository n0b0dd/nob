---
name: nob-planner
description: Use when starting any Nob workflow. Reads the user's intent, CLAUDE.md, .nob.yml, and the referenced source file, then produces a sequenced execution plan identifying affected layers and agent order. Always invoked first by the Nob hub.
---

# Nob — Planner Agent

## Overview
Analyze the full request before any implementation begins. Produce a sequenced execution plan that tells subsequent agents exactly what to do and in what order. You do not implement anything — you plan only.

## Process

### Step 1: Read project context
Read `CLAUDE.md` at the repo root — understand conventions, stack, folder structure. If not found, note it and continue.

Get stack configuration from the `.nob.yml contents` field in your `[INPUTS]` block. Do not read `.nob.yml` from disk — the hub has already resolved it. Use this config to understand which layers are enabled and agent names.

### Step 2: Read the source file
Read the file referenced in the user's intent (spec file, bug report, etc.) using the Read tool.

If the user's intent does not reference a specific file, note this and derive the work scope from the intent message directly. Skip Steps 2 reading and proceed to Step 3 using the intent message as the source.

### Step 3: Identify affected layers
Based on the source file content and `.nob.yml`:
- Does this change require backend work? (new/changed API endpoints, data models, business logic)
- Does this change require frontend work? (new/changed screens, components, API consumption)
- Does this change require both? In what order? (default: backend first, then frontend — frontend consumes backend)

### Step 3.5: Determine run mode
Count independent work streams in the spec:

- A work stream is independent if it shares no API contracts or UI state with other streams
- Example independent: "profile fields" and "notification preferences" use different endpoints and different components
- Example dependent: "avatar upload" that requires a profile endpoint to exist — keep as single slice

If 1 independent work stream → `Mode: single`
If 2+ independent work streams → `Mode: fan-out`

For fan-out, name each slice with a short kebab-case slug (e.g., `profile-settings`, `notification-prefs`).

Cap slices at `max_parallel_slices` from `.nob.yml` (default: 3). If more independent streams exist than the cap, group excess into the nearest slice.

When in doubt: `Mode: single`. Do not force fan-out on ambiguous specs.

All slices in a fan-out output must be fully independent — `Independent: yes` is the only valid value in the Slices section. If two work streams are not fully independent, do not include them as separate slices; keep Mode: single instead.

### Step 4: Break into ordered tasks
**Skip this step if Mode: fan-out** — slices from Step 3.5 already capture the work scope. Tasks are only written for Mode: single.

Write 2-6 tasks. Each task must:
- Name the agent that handles it
- Describe what that agent should do in one specific sentence
- State its dependency (what must complete before it can start)

Agent names in the task list must match the names in the `agents.enabled` list from your [INPUTS] config. Do not use hardcoded names.

### Step 5: Flag ambiguities
List anything in the source file that is vague, contradictory, or missing. If there are ambiguities, list them. If none, write "none".

Do NOT ask the user about ambiguities here — list them in the output block. The hub will decide whether to pause and ask.

## Output Format

Return this exact block. For `Mode: single`, omit the `Slices:` section entirely — the `Tasks` section is used instead (backward compatible with Phase 2).

```
[PLAN OUTPUT]
Workflow: [Spec→Code | Bug→Fix | API→Sync]
Source file: [path as provided by user]
Mode: single | fan-out
Affected layers: [frontend | backend | frontend + backend]
(use exactly one of these three values — no other format)

Slices (only present when Mode: fan-out):
  Slice 1 — [slug-name]
    Scope: [one sentence describing this work stream]
    Affected layers: [frontend | backend | frontend + backend]
    Independent: yes

  Slice 2 — [slug-name]
    Scope: [one sentence describing this work stream]
    Affected layers: [frontend | backend | frontend + backend]
    Independent: yes

Tasks (in order, only present when Mode: single):
1. [agent-name]: Read [source file] and extract structured requirements — depends on: none
2. [agent-name]: Implement [specific backend changes from Task 1 output] — depends on: Task 1
3. [agent-name]: Implement [specific frontend changes], consuming API contracts from Task 2 — depends on: Task 2
4. [agent-name]: Validate all outputs against acceptance criteria — depends on: Task 1, Task 2, Task 3
(use agent names from .nob.yml agents.enabled)

Ambiguities (human input needed before proceeding):
- [specific ambiguity, or: none]
[/PLAN OUTPUT]
```

## Error Handling
- **CLAUDE.md missing**: note "CLAUDE.md not found — proceeding with reduced context" and continue
- **.nob.yml contents missing from [INPUTS]**: proceed assuming frontend + backend both enabled (should not happen — hub always provides resolved config)
- **Source file missing**: stop and output: "Cannot plan — source file [path] not found. Please check the path and try again."
- **Only one layer enabled in config**: include only that layer's agent in the task list
