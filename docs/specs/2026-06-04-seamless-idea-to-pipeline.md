# Feature: Seamless Idea-to-Pipeline Flow

## Summary
When a user runs `/nob` with a rough idea instead of a spec file path, the hub automatically runs the PM agent to write the spec, then continues the full pipeline without requiring a second command.

## Users
All Nob users — solo developers, small teams, first-time and experienced users alike.

## User flow
1. User types `/nob add dark mode to my app` (plain text, no file path)
2. Hub detects the input is a rough idea, not a spec file path
3. Hub invokes PM agent in spec-writing mode with the raw idea as input
4. PM agent asks clarifying questions one at a time and waits for answers
5. PM agent writes the spec to `docs/specs/YYYY-MM-DD-<slug>.md`
6. Hub reads the spec path from PM output and continues automatically
7. Tech Lead, Backend, Frontend, Reviewer run as normal
8. User receives reviewed, diff-ready output — same result as `/nob implement <spec>`

**Alt path — user runs `/nob:pm` directly:**
Steps 1–5 are identical. At step 6, PM offers "Ready to implement?" as today. No change to standalone PM behaviour.

## Requirements
- Hub must distinguish a rough idea (plain text) from a spec file path (contains `/` or ends in `.md`)
- Rough idea input must route to PM spec-writing mode before any other pipeline step
- PM agent, when dispatched by the hub in idea mode, must skip the "Ready to implement?" prompt — spec path is returned to the hub instead
- Hub must extract the spec file path from PM output and store it as SOURCE_FILE
- After PM completes, hub must resume the normal pipeline from Step 1.5 (spec pre-flight) using SOURCE_FILE
- Checkpoint must record SOURCE_FILE so resumed runs don't re-invoke PM
- All existing workflow types (Bug→Fix, API→Sync, Venture, Init, Refactor, Ideate) must be unaffected
- Standalone `/nob:pm <idea>` must continue to offer "Ready to implement?" as before

## Acceptance criteria
- [ ] `/nob add dark mode` (no file path) runs PM → Tech Lead → Backend ∥ Frontend → Reviewer in one command
- [ ] PM's clarifying questions are asked and answered before the pipeline continues
- [ ] Spec file is written to `docs/specs/` before Tech Lead is dispatched
- [ ] Hub uses the PM-written spec as SOURCE_FILE for all downstream agents
- [ ] Checkpoint records SOURCE_FILE; a resumed run skips PM and starts from Tech Lead
- [ ] `/nob implement docs/specs/my-spec.md` (explicit path) behaves exactly as today — no regression
- [ ] `/nob:pm my idea` (standalone) still asks "Ready to implement?" after writing the spec
- [ ] Venture, Init, Refactor, Ideate intents still route to their own early exits — no interference

## Builds on
- Hub Step 2 workflow identification (`skills/nob/SKILL.md`)
- Hub Step 1.5 spec pre-flight validation
- PM Agent spec-writing mode (`skills/pm-agent/SKILL.md`)
- PM Agent Step 4 "offer implementation" — needs hub-dispatch awareness
- Checkpoint system (`.nob/checkpoint.json`)

## Constraints
- Must not add a new user-facing command — the change is invisible; same `/nob <intent>` entry point
- PM clarifying questions must not be skipped — they are the quality gate for the spec
- Must not require `.nob.yml` to enable — works out of the box

## Error states
- **PM writes spec but missing acceptance criteria**: pre-flight catches it, prints clear error, exits — user fixes the spec and re-runs
- **User abandons mid-clarification (Ctrl+C)**: no spec written, no pipeline started — clean exit, nothing left in `.nob/`
- **`docs/specs/` cannot be created**: PM warns and asks for an alternative path before proceeding
- **PM output does not contain a spec path**: hub prints "PM agent did not produce a spec file path — cannot continue. Run `/nob:pm <idea>` directly to debug." and exits

## Out of scope
- Changing PM's clarifying question format or count
- Auto-generating specs without clarifying questions (no silent spec generation)
- Affecting Venture, Init, Refactor, or Ideate workflows
- Any UI or web changes

## Open questions
- none
