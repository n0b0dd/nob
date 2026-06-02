# Product Ideation Agent

## Summary

A new Ideation Agent that reads an existing codebase and a user-provided direction + constraints, then generates 3-5 ranked feature ideas. User picks one, agent expands it into a ready-to-run mini-spec saved to `docs/specs/`. Integrated into the hub as a new `ideate` workflow type.

---

## Hub Integration

`ideate` is a new workflow type alongside `Spec→Code`, `Bug→Fix`, `Venture`, `Init`, and `Refactor`.

**Trigger patterns** (detected in Step 2 of the hub):
- `"ideate [direction]"`, `"nob ideate"`
- `"what should I build next"`, `"suggest features for"`
- `"I want to add [vague goal]"`, `"what feature should I add"`

When detected → hub skips Planner, PM Agent, Backend, Frontend, and Reviewer entirely. Routes directly to the Ideation Agent via an early-exit (same pattern as Venture and Init).

**Constraint parsing:** The hub extracts constraints from the user's message before dispatching. Constraints appear as:
- Explicit flags: `--simple`, `--no-new-deps`, `--mobile-first`, `--backend-only`
- Natural language: "keep it simple", "no new dependencies", "mobile only", "backend only"

Hub passes both `direction` and `constraints` (as a plain string, empty if none) to the agent.

---

## Codebase Exploration

The agent reads these files on entry — no sub-agent dispatch, no full codebase scan:

| Source | Purpose |
|---|---|
| `CLAUDE.md` | Tech stack, conventions, what already exists |
| `.nob.yml` | Stack type, frontend/backend paths |
| `package.json` / `requirements.txt` / `pubspec.yaml` / `build.gradle` (whichever exists) | Installed dependencies → existing capabilities |
| Main routes file (auto-detected from stack type and backend path) | What endpoints/features are already built |
| Main components or screens directory listing (from frontend path) | What UI already exists |
| `docs/specs/` directory listing (if present) | What has already been specced or built recently |

The agent reads only what it needs to understand the project's shape — not every file.

---

## Output Flow

### Stage 1: Ranked idea list

After exploring the codebase, the agent prints 3-5 ideas:

```
Here are N feature ideas based on your codebase and direction:

1. [Feature Name] ★★★
   [2-sentence description: what it does, why it fits the existing codebase.]
   Scope: [backend-only | frontend-only | full-stack] · Complexity: [simple | moderate | significant]

2. [Feature Name] ★★☆
   ...

Which would you like to build? (1-N, or "none")
```

Ideas are ranked by fit: how well they match the direction, respect the constraints, and extend what already exists without requiring major architectural changes. Each idea shows scope (affected layers) and complexity so the user can make an informed choice.

### Stage 2: Mini-spec expansion

User picks a number → agent expands that idea into a mini-spec with:

- **Problem statement** — what gap this fills
- **Proposed solution** — 1 paragraph describing the feature
- **Acceptance criteria** — 3-5 bullet points (specific, testable)
- **Affected files** — best-guess based on codebase exploration (routes, components, models likely touched)
- **Out of scope** — what the feature explicitly does NOT include

The mini-spec is saved to `docs/specs/YYYY-MM-DD-[feature-slug].md`.

Agent prints: `Spec saved to docs/specs/[filename]. Run: /nob implement docs/specs/[filename]`

If user responds "none" → agent exits cleanly: "No problem. Run `/nob ideate [new direction]` to try a different direction."

---

## Output Format

```
[IDEATION-AGENT OUTPUT]
Direction: [user's direction]
Constraints: [parsed constraints, or: none]
Ideas generated: [N]
Chosen: [idea name, or: none]
Spec saved: [path, or: n/a]
[/IDEATION-AGENT OUTPUT]
```

---

## File Changes

| File | Change |
|---|---|
| `skills/nob/ideation-agent/SKILL.md` | New — codebase exploration, idea generation, mini-spec expansion |
| `skills/nob/SKILL.md` | Add `ideate` to workflow detection table; add Ideation early-exit section; add `ideation-agent: haiku` to RESOLVED_CONFIG `agents.models` defaults; add `ideation-agent` to `agents.enabled` default list |
| `skills/nob/templates/.nob.yml.template` | Add `ideation-agent: haiku` to models section |
