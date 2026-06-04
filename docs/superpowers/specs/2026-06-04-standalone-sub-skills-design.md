# Standalone Sub-Skills Design

**Date:** 2026-06-04
**Status:** Approved

## Problem

All nob sub-skills (`backend`, `frontend`, `security`, `reviewer`, `planner`, `init`, `refactor`, `ideation`, `ask`) are currently hub-only: they can only run as sub-agents dispatched by the hub, which embeds their full SKILL.md content into `[INSTRUCTIONS]` and provides all context via an `[INPUTS]` block. Users cannot invoke them directly. The `pm` skill is already standalone (dual-mode, user-invocable at `/nob:pm`) — this design applies the same pattern to all remaining sub-skills.

## Goals

- Every sub-skill is user-invocable as its own slash command (e.g., `/nob:backend`, `/nob:frontend`)
- Hub dispatch is unchanged — sub-skills detect hub context and behave exactly as before
- Hub pipeline description reflects the new standalone capability

## Non-Goals

- Changing hub dispatch mechanics (still embeds SKILL.md as `[INSTRUCTIONS]`)
- Writing intermediate output files from hub runs (Approach B — deferred)
- Full interactive UX for pipeline-dependent skills in standalone mode (Approach C — deferred)

## Approach: Minimal Dual-Mode (Approach A)

The `pm` skill proves the pattern works. Apply it uniformly:

1. Update frontmatter `name` and `description` on every sub-skill
2. Add `## Mode 0: Mode Detection` to every sub-skill's Process section
3. Update hub frontmatter, overview, and CLAUDE.md

### Section 1: Naming & Frontmatter

Every sub-skill gets an updated frontmatter `name` following the `nob-<skill>` convention, consistent with `nob-pm`. The plugin registers these as `nob:<skill>` in Claude Code.

| Skill file | Frontmatter name | Invocation |
|---|---|---|
| `nob/planner/SKILL.md` | `nob-planner` | `/nob:planner` |
| `nob/backend/SKILL.md` | `nob-backend` *(keep)* | `/nob:backend` |
| `nob/frontend/SKILL.md` | `nob-frontend` *(keep)* | `/nob:frontend` |
| `nob/security/SKILL.md` | `nob-security` | `/nob:security` |
| `nob/reviewer/SKILL.md` | `nob-reviewer` *(keep)* | `/nob:reviewer` |
| `nob/init/SKILL.md` | `nob-init` | `/nob:init` |
| `nob/refactor/SKILL.md` | `nob-refactor` | `/nob:refactor` |
| `nob/ideation/SKILL.md` | `nob-ideation` | `/nob:ideation` |
| `nob/ask/SKILL.md` | `nob-ask` | `/nob:ask` |
| `pm/SKILL.md` | `nob-pm` *(keep)* | `/nob:pm` |

Each `description` field is updated to include both standalone trigger phrases and "Part of the Nob hub pipeline" so users and the skill system can discover it in both contexts.

### Section 2: Mode 0 Detection Pattern

Inserted at the top of every sub-skill's `## Process` section:

```markdown
## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** at the end of this file for how to source each required input.
```

A `### Standalone Inputs` subsection is added at the end of each skill (before the output block definition):

**Self-sufficient skills** (`init`, `refactor`, `ideation`, `ask`):
> Use the current working directory. Use the user's message as the intent/question. No prior agent output needed — proceed to Step 1.

**`planner`**:
> Ask the user for the spec file path. Proceed with that path as the spec. No prior agent output needed.

**`backend`, `frontend`**:
> Ask the user for the spec file path. Look for `.nob/pm-output.md` in the working directory — if found, use it as `[PM OUTPUT]`. If not found, ask the user to run `/nob:pm <spec>` first, or paste the PM output directly.

**`security`**:
> Look for `.nob/backend-output.md` and `.nob/frontend-output.md`. If found, use them. If not found, ask the user which implementation outputs to review and accept a paste.

**`reviewer`**:
> Look for `.nob/pm-output.md`, `.nob/backend-output.md`, `.nob/frontend-output.md`. Use what's found. Prompt for any missing ones or accept a paste.

### Section 3: Hub Pipeline Updates

**3a. Hub frontmatter & overview** — update `description` to reflect independent invocability. Add to `## Overview`:

> Sub-skills (`/nob:planner`, `/nob:backend`, `/nob:frontend`, `/nob:security`, `/nob:reviewer`, `/nob:init`, `/nob:refactor`, `/nob:ideation`, `/nob:ask`) can be invoked directly for targeted work. When invoked via the hub, each sub-skill receives an `[INPUTS]` block with all required context and runs in hub-dispatched mode. When invoked standalone, each sub-skill sources inputs from `.nob/` output files or prompts the user.

**3b. Skill path references** — all paths already use renamed folders after the in-progress renames. PM stays at `{SKILL_BASE_DIR}/../pm/SKILL.md` (no change — it lives at top-level `skills/pm/`).

**3c. CLAUDE.md** — add each new standalone sub-skill to the skills listing. Existing entries: `nob:nob`, `nob:pm-agent`. New entries: `nob:planner`, `nob:backend`, `nob:frontend`, `nob:security`, `nob:reviewer`, `nob:init`, `nob:refactor`, `nob:ideation`, `nob:ask`.

**3d. No other hub changes** — `agents.enabled` list, dispatch prompts, checkpoint logic, retry loop, output block validation — all unchanged.

## Acceptance Criteria

- Each sub-skill SKILL.md has a `name` frontmatter field following `nob-<skill>` convention
- Each sub-skill SKILL.md has a `## Mode 0: Mode Detection` block at the top of its Process section
- Each sub-skill SKILL.md has a `### Standalone Inputs` subsection describing its fallback behavior
- Hub `## Overview` mentions standalone sub-skill invocability
- CLAUDE.md skills listing includes all nine new standalone sub-skills
- Existing hub pipeline tests pass (dispatch with `[INPUTS]` still works identically)
- `pm` skill is unchanged (already standalone)
