# Feature: Skill-Contract Linter

## Summary
A static linter that validates the Nob plugin's own internal contracts — skill paths, output blocks, and the hub's required-field tables — so contract drift is caught before a run breaks, for plugin maintainers.

## Users
Nob plugin maintainers editing skill files, and CI on pull requests against this repo.

## User flow
1. A maintainer edits one or more `SKILL.md` files (or the hub's validation tables) and runs the linter (`tools/lint-skills.sh` or `/nob:lint`).
2. The linter scans every skill under `skills/`, the hub orchestrator, and the plugin metadata.
3. It reports each broken contract with the offending file, line, and a one-line explanation.
4. It exits non-zero if any error is found, zero if all contracts hold; CI uses this exit code to pass/fail the PR.

## Requirements
- Resolve every `{SKILL_BASE_DIR}/../X/SKILL.md` reference in the hub and confirm the target file exists.
- For each agent the hub extracts an `[X OUTPUT]...[/X OUTPUT]` block from, confirm the corresponding sub-skill actually emits that exact block (opening and closing tag present).
- Confirm every required field named in the hub's Output Block Validation table appears as `FieldName:` in the matching sub-skill's emitted output block.
- Flag any `[X OUTPUT]` block referenced by the hub for which no producing sub-skill can be found.
- Flag any sub-skill path the hub dispatches that does not exist on disk.
- Produce a human-readable report listing each violation with file path and a short reason.
- Exit non-zero when one or more errors are found; exit zero when none are found.
- Run with only tools already assumed by the repo (shell + standard unix utilities, or a single self-contained script); introduce no new runtime dependency for the plugin itself.

## API contracts
not applicable — API contracts are defined by the Tech Lead Agent during implementation

## Data models
not applicable — data schemas are defined by the Tech Lead Agent during implementation

## Acceptance criteria
- [ ] Running the linter on the current (passing) repo state exits zero and reports no violations.
- [ ] Deleting or renaming a sub-skill referenced by the hub causes the linter to report a missing-path violation and exit non-zero.
- [ ] Removing a required field from a sub-skill's output block (e.g. dropping `Risks:` from `[TECH LEAD OUTPUT]`) causes the linter to report a missing-field violation naming that field and exit non-zero.
- [ ] Removing an entire `[X OUTPUT]` block from a sub-skill that the hub extracts causes the linter to report a missing-block violation and exit non-zero.
- [ ] Each reported violation includes the offending file path and a one-line reason.
- [ ] The linter runs to completion without requiring any package install beyond what the repo already uses.

## Builds on
- Hub orchestrator and its Output Block Validation Procedure (`skills/nob/SKILL.md`)
- All sub-skill output-block contracts (`skills/pm/SKILL.md`, `skills/tech-lead/SKILL.md`, `skills/dev/SKILL.md`, `skills/reviewer/SKILL.md`, etc.)
- The existing shell-hook precedent (`hooks/unit-boundary.sh`) for a self-contained shell tool in this repo

## Constraints
- No new runtime dependency for the plugin (the repo has no build system or test runner today).

## Error states
- A SKILL.md file is unreadable or missing: report it as a violation rather than crashing.
- The hub's validation table cannot be parsed: report a parse-level warning and continue checking the rest.

## Out of scope
- Validating user-project skill files or `.nob.yml` contents (this linter targets the plugin's own skills only).
- Auto-fixing violations — the linter reports, it does not edit.
- Linting prose quality, spelling, or Markdown formatting.

## Open questions
- Should the linter ship as a standalone `tools/` script, a `/nob:lint` skill, a CI workflow, or some combination? (Defer to Tech Lead.)
