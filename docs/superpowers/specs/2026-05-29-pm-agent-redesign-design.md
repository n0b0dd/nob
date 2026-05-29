# PM Agent Redesign — Dual-Mode Standalone Skill

## Summary

Redesign PM Agent from a Nob-internal sub-skill into a standalone invokable skill that supports two modes: spec-writing (idea → spec file) and requirements extraction (spec file → structured requirements block). The Nob hub continues to use it unchanged.

## Mode Detection

When PM Agent is invoked, it inspects its input:

- Input contains `/` or ends in `.md` → **requirements extraction mode**
- Input is plain text → **spec-writing mode**
- Ambiguous → ask: "Are you giving me a spec file path or a rough idea to turn into a spec?"

## Spec-Writing Mode (new)

Triggered when the user invokes PM Agent directly with a plain-text idea.

**Flow:**

1. **Read codebase context** — reads `CLAUDE.md`, `.nob.yml`, runs stack auto-detection (same logic as Nob hub)
2. **Ask clarifying questions one at a time:**
   - Who are the users of this feature?
   - What is the core action they are trying to do?
   - Any constraints (auth required, mobile only, etc.)?
   - What is explicitly out of scope?
3. **Write spec file** to `docs/specs/YYYY-MM-DD-<feature-slug>.md`
4. **Ask:** "Ready to implement? Run `/nob implement <spec-path>`?" (yes/no)
   - Yes → invokes the `nob` skill directly with `implement <spec-path>`
   - No → stops; user reviews the spec manually

## Requirements Extraction Mode (unchanged)

Current PM Agent behavior. No changes to logic or output format.

- Reads the spec file at the path provided in `[PLAN OUTPUT]`
- Extracts: feature name, summary, acceptance criteria, backend changes, frontend changes, edge cases, out of scope, ambiguities
- Outputs a structured `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]` block

## Spec File Format

```markdown
# Feature: [name]

## Summary
[one sentence]

## Users
[who uses this feature]

## Requirements
- [requirement]
- [requirement]

## Out of scope
- [item]

## Open questions
- [anything unresolved flagged for human review]
```

Saved to `docs/specs/YYYY-MM-DD-<feature-slug>.md`.

## Nob Hub Integration

No changes to the Nob hub (`skills/nob/SKILL.md`). The hub continues to read `pm-agent/SKILL.md` and pass its contents as instructions to an Agent tool call. The updated SKILL.md handles both modes — the hub always invokes it in requirements extraction mode by passing a spec file path.

## Files Changed

- `skills/nob/pm-agent/SKILL.md` — rewritten to support dual-mode detection, spec-writing flow, and clarifying questions
