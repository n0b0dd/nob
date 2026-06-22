---
name: path-quick
description: 'Quick path inline implementation. Hub dispatches here when ROUTE = quick (≤3 files, single unit, no new contracts). Reads affected files, implements directly, verifies, commits, and emits [QUICK PATH OUTPUT]. No sub-agents dispatched.'
---

# Nob — Quick Path

Dispatched by the Nob hub when ROUTE = quick. Hub has already identified affected files via scope scan. Implement the change inline — no sub-agents.

---

## Setup

Set WORKTREE_PATH from `Working directory:` in [INPUTS].
Set RUN_ID from `Run ID:` in [INPUTS].

---

## Step 1: Read affected files

Read each file listed under `Affected files:` in [INPUTS] using the Read tool.

If no affected files are listed: run one targeted search before proceeding.
- Extract the most specific identifier from `User intent:` in [INPUTS] (a symbol name, route path, or component name).
- Run `grep -rn "<identifier>" {WORKTREE_PATH} --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" --include="*.rb" -l 2>/dev/null | head -10`.
- Read the first matching file. If nothing found: emit `[QUICK PATH OUTPUT]` with `Status: FAIL` and `Summary: No files found to modify — check the intent or re-run with --lite.` and exit.

---

## Step 2: Implement

Make all changes directly using Edit or Write tools. Apply the change exactly as described in `User intent:` in [INPUTS]. Do not dispatch any Agent tool calls — this path is fully inline.

---

## Step 3: Quick verify

Detect the stack from `Stack type:` in [INPUTS] (or infer from the file extensions read in Step 1).

Run the appropriate type-check in WORKTREE_PATH:

| Stack | Command |
|---|---|
| next / react / vue / node | `npx tsc --noEmit 2>/dev/null` |
| python | `python -m py_compile <changed files, space-separated>` |
| go | `go build ./...` |
| others | skip |

If the check exits non-zero: attempt one self-correction — re-read the failing file, fix the error, re-run the check once. If still failing: VERIFY_STATUS = FAIL. If it passes: VERIFY_STATUS = PASS. If skipped: VERIFY_STATUS = SKIPPED.

---

## Step 4: Commit to worktree

Run:
- `git -C {WORKTREE_PATH} add -A`
- `git -C {WORKTREE_PATH} commit -m "nob: {RUN_ID}"`

If the working tree is clean (nothing to commit), skip the commit and note it in the output.

---

## Step 5: Emit output

Emit exactly this block with all fields filled in:

```
[QUICK PATH OUTPUT]
Status: PASS
Files changed:
  - {each changed file path, one per line; "none" if nothing changed}
Summary: {1–2 sentences describing what was changed and why}
Check: {PASS | FAIL | SKIPPED}
Stack: {stack type used for the check, or: unknown}
[/QUICK PATH OUTPUT]
```
