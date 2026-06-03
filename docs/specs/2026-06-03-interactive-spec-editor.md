# Interactive Spec Editor (Conversational Spec Refinement)

## Problem statement
PM Agent currently produces a spec in a single linear pass — the user either accepts it or discards it and starts over. Tools like GitHub Copilot Workspace and Cursor's Composer allow back-and-forth revision: the agent proposes a plan, the user comments on individual sections, and the agent surgically updates only those parts. Without this loop, nob forces all ambiguity resolution upfront, making spec quality dependent entirely on the quality of the initial prompt.

## Proposed solution
Add a revision loop to PM Agent's spec-writing mode. After the agent writes the initial spec, it presents it section by section and asks: "Any changes? (describe a section to edit, or 'done' to proceed)". The user can say things like "change the API contract to use PATCH instead of POST" or "remove the email notification requirement". PM Agent applies targeted edits to only the named section, re-displays the changed section, and loops until the user says "done". The final confirmed spec is then written to `docs/specs/` and passed downstream. The ideation agent's `--plan-only` escape hatch remains unchanged.

## Acceptance criteria
- After PM Agent writes the initial spec, it prints the full spec and prompts the user for revisions
- User can reference a section by name ("acceptance criteria", "API contracts", "problem statement") or describe the change in natural language
- PM Agent applies the edit to only the referenced section without touching others
- The revision loop continues until the user types "done", "looks good", or any affirmative
- The written spec file reflects the final confirmed version, not the initial draft
- If the user types "done" immediately, PM Agent proceeds without any revision (no forced interaction)

## Affected files
- `skills/nob/pm-agent/SKILL.md` — add revision loop after spec is drafted; read section names, apply targeted edits, loop until user confirms
- `skills/pm-agent/SKILL.md` — same change for standalone PM Agent usage

## Out of scope
- Diff display between spec versions (just re-print the changed section)
- Version history or undo functionality
- Revision loop for requirements-extraction mode (only applies to spec-writing mode)
