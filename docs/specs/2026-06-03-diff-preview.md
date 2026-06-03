# Multi-File Diff Preview Before Commit

## Problem statement
Nob writes all agent-proposed file changes directly into the worktree and only surfaces them in the terminal summary after the fact. While worktree isolation prevents changes from landing on the main branch without a commit, developers cannot review a consolidated diff before that commit happens. Tools like Aider, Cursor, and Cline present a per-file approve/reject step before writing anything — this is now a trust baseline developers expect from AI coding tools. The absence of a preview step means users must run `git diff` themselves or trust the terminal summary's file list without seeing content.

## Proposed solution
Add a `--diff-only` flag to the nob hub. When set, implementation agents run normally and write their changes to the worktree — but instead of committing, the hub runs `git -C {WORKTREE_PATH} diff HEAD` and prints the full diff to the terminal. It then asks: "Apply these changes? (yes / no)". If the user says yes, the hub commits and continues to the PR step. If no, it runs `git -C {WORKTREE_PATH} checkout .` to discard all worktree changes and exits with status `CANCELLED`. Without the flag, the existing auto-commit behaviour is unchanged.

## Acceptance criteria
- `--diff-only` flag is recognised in the user's message and stored as `DIFF_PREVIEW = true`
- When `DIFF_PREVIEW = true`, after all impl agents complete, the hub runs `git -C {WORKTREE_PATH} diff HEAD` and prints the output
- The diff is followed by a confirmation prompt: "Apply these changes? (yes / no)"
- If yes: hub commits the worktree (`git -C {WORKTREE_PATH} commit -m "nob: {run-id}"`) and continues normally
- If no: hub discards changes (`git -C {WORKTREE_PATH} checkout .`), removes the worktree, and prints "Changes discarded."
- Without `--diff-only`, existing behaviour is unchanged
- If the diff output exceeds 200 lines, the hub prints the first 200 lines and adds: "... and N more lines. Run `git -C {WORKTREE_PATH} diff HEAD` to see the full diff."

## Affected files
- `skills/nob/SKILL.md` — detect `--diff-only` flag at Step 1; add diff preview step between Phase 3 and worktree teardown in Step 4; handle yes/no branching

## Out of scope
- Per-file or per-hunk approve/reject (only whole-diff accept or discard)
- Diff preview in fan-out mode (only single-slice mode in the first version)
- Saving the diff to a file
