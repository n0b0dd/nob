# Feature: Interactive Plan Approval (`--plan` flag)

## Summary
An enhanced `--plan` flag that shows the Tech Lead's task list with per-file change previews and requires explicit user approval before Dev starts, giving developers visibility and control before any code is written.

## Users
Developers who want to review and optionally modify the implementation plan before code changes are made — especially on full-path runs touching multiple units.

## User flow
1. Developer runs `/nob implement docs/specs/my-feature.md --plan`.
2. Hub detects `--plan` flag and passes it to the path skill.
3. PM and Tech Lead run as normal. Tech Lead emits `[TECH LEAD OUTPUT]`.
4. Path skill renders a **plan summary** to the terminal:
   - List of tasks (id, unit, description, files to change/create).
   - Estimated scope: N tasks across M units, K files.
   - Any flagged risks from TL output.
5. Prompts: `"Proceed with this plan? (yes / edit / cancel)"`.
6. If `yes`: Dev dispatches immediately.
7. If `edit`: path skill prints `"Edit the plan — type your changes or paste a modified task list, then type 'done'."` User submits edits; path skill applies them (add/remove tasks, change descriptions) and re-renders the updated plan. Prompts again.
8. If `cancel`: hub exits cleanly, worktree is removed, no code is written.
9. Dev runs against the approved plan. Terminal summary includes `Plan approved: yes` and whether any edits were made.

## Requirements
- `--plan` flag is parsed by the hub and passed via `[INPUTS]` to path skills.
- Supported on lite and full paths only. Quick path prints `"--plan not supported on quick path (no TL step)"` and proceeds.
- Plan summary rendering: each task on one line — `[unit] task-id: description (files: path1, path2)`.
- Risks section: if TL output contains risks, render them as a `Risks:` block above the approval prompt.
- `edit` mode: user input is parsed as free-form modification intent (e.g., "remove task 3", "change task 2 to only touch the API layer"). The path skill re-prompts TL with the modification request to produce an updated task list — does not attempt to parse structured diffs.
- `cancel` cleans up the worktree and exits with message `"Run cancelled at plan approval — no changes made."`.
- `--plan` is compatible with `--tdd`: if both flags are active, the plan approval step happens after TL, before the test-writer phase.
- `--plan-only` (existing flag) remains unchanged — it exits after PM output, before TL runs. `--plan` runs TL and then pauses.
- Terminal summary gains a `Plan:` line: `approved (no edits)` | `approved (N edits)` | `cancelled`.

## API contracts
not applicable — API contracts are defined by the Tech Lead Agent during implementation

## Data models
not applicable — data schemas are defined by the Tech Lead Agent during implementation

## Acceptance criteria
- [ ] Running `/nob implement spec.md --plan` on a full-path run renders the plan summary and pauses after Tech Lead.
- [ ] `yes` at the approval prompt resumes Dev dispatch immediately.
- [ ] `cancel` removes the worktree and exits without writing any files.
- [ ] `edit` re-dispatches TL with the modification, re-renders the updated plan, and prompts again.
- [ ] `--plan` on quick path prints the unsupported message and continues as a normal quick run.
- [ ] Terminal summary includes `Plan: approved (no edits)` when approved without changes.
- [ ] `--plan` and `--tdd` together: plan approval happens before test-writer phase.
- [ ] `--plan-only` flag behavior is unchanged by this feature.

## Builds on
- `skills/nob/SKILL.md` — hub flag parsing and `[INPUTS]` passing
- `skills/nob/path-full/SKILL.md` — pause point after TL dispatch, before Dev
- `skills/nob/path-lite/SKILL.md` — same pause point
- `skills/tech-lead/SKILL.md` — `[TECH LEAD OUTPUT]` task list is what gets rendered
- `skills/nob/retry/SKILL.md` — retry skill inherits the approved plan (no re-approval on retry)

## Constraints
- No new agent dispatch for the approval step — it is handled inline by the path skill.
- Edit mode re-dispatches TL as an agent call (one re-dispatch only); does not attempt freeform task list patching in the path skill itself.
- Plan approval state (approved / edited / cancelled) must be recorded in the checkpoint so resume flows know whether approval already happened.

## Error states
- TL output missing task list: render whatever fields are present, note `incomplete plan`, still prompt for approval.
- User provides no response within the session: treat as `cancel` after a reminder prompt.
- Edit re-dispatch fails or returns malformed output: show error, prompt `"Retry edit or proceed with original plan? (retry / proceed / cancel)"`.

## Out of scope
- Allowing the user to write task implementation details (file content) at approval time.
- Persisting approved plans across sessions (beyond the checkpoint file).
- Visual diff previews of proposed file changes (that would require Dev to run speculatively).

## Open questions
- Should the plan approval prompt also show estimated token cost for the Dev phase? Defer to Tech Lead.
- On retry runs (Phase 3.5), should the approval prompt re-appear with the revised plan, or skip automatically? Defer to Tech Lead.
