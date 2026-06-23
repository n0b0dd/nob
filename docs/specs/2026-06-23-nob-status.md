# Feature: `/nob:status` — Run Inspector

## Summary
A standalone `/nob:status` skill that reads `.nob/checkpoint.json` and git history to display the current run state, completed/pending tasks, last Reviewer verdict, and a 5-run recent history — giving developers a clear answer to "what's in progress?" without digging into internal files.

## Users
Developers who have run or are running `/nob implement` and want to inspect what happened, what's in progress, or what recently completed.

## User flow
1. Developer runs `/nob:status` in a project directory.
2. Agent reads `.nob/checkpoint.json` (if present) to determine current run state.
3. Agent reads git log to find recent nob branches (branches matching `nob/*`).
4. Agent prints the status report: current run section (state, spec, branch, task progress) followed by a recent history section (last 5 completed runs with branch name, spec, Reviewer verdict, and date).
5. If no checkpoint exists and no nob branches are found: prints `"No nob runs found in this project."` and exits.
6. Developer reads the output — no further interaction required.

## Requirements
- Invokable standalone as `/nob:status` from the project root.
- Reads `.nob/checkpoint.json` to extract: `branch`, `spec_file`, `tasks` (with statuses), `reviewer_output`, `created_at`, `completed_at`.
- Current run section shows: state (`none` | `in-progress` | `completed` | `interrupted`), spec file, branch, task progress (N completed / M total), and Reviewer verdict if present.
- Recent history section shows the last 5 nob branches from git log (branches matching `nob/*`), each with branch name, date of last commit, and Reviewer verdict extracted from the branch tip's checkpoint (if readable).
- If `.nob/checkpoint.json` is absent: current run section shows `State: none`.
- `--unit <name>` flag filters task progress display to tasks belonging to the named unit only.
- `--json` flag emits a machine-readable JSON object instead of the human-readable report (for scripting/CI use).
- Output is read-only: no writes, no side effects.
- `agents.models.status` configurable in `.nob.yml`; default: `haiku`.

## API contracts
not applicable — API contracts are defined by the Tech Lead Agent during implementation

## Data models
not applicable — data schemas are defined by the Tech Lead Agent during implementation

## Acceptance criteria
- [ ] `/nob:status` in a project with an active checkpoint prints `State: in-progress` and task progress (N completed / M total).
- [ ] `/nob:status` in a project with a completed checkpoint prints `State: completed` and the Reviewer verdict.
- [ ] `/nob:status` in a project with no checkpoint file prints `State: none`.
- [ ] Recent history section lists up to 5 past nob branches with branch name and last-commit date.
- [ ] `--unit api` filters task progress to only tasks belonging to the `api` unit.
- [ ] `--json` emits a valid JSON object with the same fields as the human-readable output.
- [ ] `/nob:status` writes to no file and modifies no git state.
- [ ] In a directory with no `.nob/` folder and no nob branches found in git, prints `"No nob runs found in this project."` and exits cleanly.

## Builds on
- `.nob/checkpoint.json` — checkpoint schema written by `skills/nob/path-full/SKILL.md` (Phase 2); fields: `branch`, `spec_file`, `tasks`, `reviewer_output`, `created_at`, `completed_at`
- `skills/nob/SKILL.md` — hub branch naming convention (`nob/YYYY-MM-DD-slug`) used to identify nob branches in git log
- `skills/nob/path-full/SKILL.md` — checkpoint write logic defines the schema this skill reads

## Constraints
- No new runtime dependencies for the plugin.
- Strictly read-only: must not write to any file or modify any git state.

## Error states
- `.nob/checkpoint.json` exists but is malformed JSON: print `"Checkpoint file is corrupt — run /nob implement --fresh to start over."` and exit.
- Git binary not available: skip the recent history section, print a one-line warning, and show checkpoint-only output.
- No read permission on `.nob/checkpoint.json`: print `"Cannot read checkpoint — check file permissions."` and exit.

## Out of scope
- Modifying or resetting checkpoint state (that is `--fresh`'s job).
- Displaying file diffs or changed-file contents from past runs.
- Integration with external CI systems or remote branch inspection.

## Open questions
- Should recent history scan only local branches, or also fetch remote `nob/*` branches? Defer to Tech Lead.
