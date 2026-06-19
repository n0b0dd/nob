# Verify Step and Manual PR — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-PR at the end of the nob pipeline with a verify/push prompt; make auto-PR opt-in via `agents.auto_pr` in `.nob.yml`.

**Architecture:** Two files change — `skills/nob/SKILL.md` (three surgical edits: config extraction, end-of-pipeline prompt, CI polling gate) and `skills/nob/templates/.nob.yml.template` (one new config field). No new files.

**Tech Stack:** Markdown skill files — edits are plain text replacements using the Edit tool.

---

## File Map

| File | Change |
|---|---|
| `skills/nob/SKILL.md` | Add `agents.auto_pr` extraction; replace Auto-PR block; gate CI polling |
| `skills/nob/templates/.nob.yml.template` | Add `auto_pr: false` field under `agents:` |

---

### Task 1: Add `agents.auto_pr` to RESOLVED_CONFIG extraction

**Files:**
- Modify: `skills/nob/SKILL.md` — "Extract from RESOLVED_CONFIG" section

- [ ] **Step 1: Read the file and locate the exact text to change**

  Open `skills/nob/SKILL.md`. Find the "Also extract:" list under **Extract from RESOLVED_CONFIG**. It ends with:
  ```
  - `agents.max_retries` (default: 3 if not present — maximum retry passes in Phase 3.5)
  ```

- [ ] **Step 2: Add `agents.auto_pr` extraction line**

  Using the Edit tool, add one line after the `max_retries` line:

  Old string:
  ```
  - `agents.max_retries` (default: 3 if not present — maximum retry passes in Phase 3.5)
  ```

  New string:
  ```
  - `agents.max_retries` (default: 3 if not present — maximum retry passes in Phase 3.5)
  - `agents.auto_pr` (default: false if not present — set true to opt-in to automatic PR creation after Reviewer PASS)
  ```

- [ ] **Step 3: Verify the edit**

  Read `skills/nob/SKILL.md` around the "Also extract:" section and confirm `agents.auto_pr` appears after `max_retries`.

- [ ] **Step 4: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: extract agents.auto_pr from RESOLVED_CONFIG (default: false)"
  ```

---

### Task 2: Replace Auto-PR block with Verify/Push prompt

**Files:**
- Modify: `skills/nob/SKILL.md` — Step 4 Auto-PR block

- [ ] **Step 1: Locate the Auto-PR block**

  In `skills/nob/SKILL.md`, find this exact block:

  ```
  **Auto-PR** (PASS only):
  Run `gh --version` via the Bash tool to check availability.
  - If available: run `gh pr create --title "{spec filename without path or extension}" --body "{first 3000 characters of REVIEWER_OUTPUT}" --head {WORKTREE_BRANCH}`. Print: `PR created: {returned URL}`.
  - If `gh pr create` fails: print the error and fall through to the git push command below.
  - If `gh` is not available: do nothing here — the push command below suffices.
  - Print: `Next: git push -u origin {WORKTREE_BRANCH}`
  ```

- [ ] **Step 2: Replace with Verify/Push prompt + gated Auto-PR**

  Using the Edit tool, replace the block above with:

  ```
  **Verify / Push prompt** (PASS only — when `agents.auto_pr` is false or absent):

  Print:
  \```
  Implementation complete. What next?
    verify  — run build + test suite in worktree
    push    — print push command (create PR manually)
  \```
  Wait for user response.

  If `verify`:

  Detect build and test commands from the resolved stack type:

  | Stack type | Build command | Test command |
  |---|---|---|
  | `next` / `react` / `vue` / `node` | `npm run build` | `npm test -- --watchAll=false` |
  | `python` | skip build | `pytest` |
  | `go` | `go build ./...` | `go test ./...` |
  | `flutter` | `flutter build apk --debug` | `flutter test` |
  | `android` | `./gradlew assembleDebug` | `./gradlew test` |
  | `ios` | skip build | skip tests |
  | unknown | skip — print "Build step skipped — stack type not recognised." | skip — print "Test step skipped — stack type not recognised." |

  Run build command in WORKTREE_PATH: `cd {WORKTREE_PATH} && {build command}`. Print full output.
  Run test command in WORKTREE_PATH: `cd {WORKTREE_PATH} && {test command}`. Print full output.

  After both commands complete, print:
  \```
  Verify complete.
    push  — print push command
    fix   — leave worktree open for manual edits
  \```
  Wait for user response.
  - `fix` or any non-push response: print `Worktree preserved at {WORKTREE_PATH} for manual edits.` and exit.
  - `push`: fall through to push output below.

  If `push` (from verify result or directly from initial prompt):
  Print:
  \```
  Run this to push your branch:

    git push -u origin {WORKTREE_BRANCH}

  Then create your PR on GitHub.
  \```
  Exit.

  **Auto-PR** (PASS only — when `agents.auto_pr: true`):
  Run `gh --version` via the Bash tool to check availability.
  - If available: run `gh pr create --title "{spec filename without path or extension}" --body "{first 3000 characters of REVIEWER_OUTPUT}" --head {WORKTREE_BRANCH}`. Print: `PR created: {returned URL}`.
  - If `gh pr create` fails: print the error and fall through to the git push command below.
  - If `gh` is not available: do nothing here — the push command below suffices.
  - Print: `Next: git push -u origin {WORKTREE_BRANCH}`
  ```

  Note: remove the backslashes from the triple-backtick fences (`\`\`\``) when writing the actual file — they are escape characters in this plan document only.

- [ ] **Step 3: Verify the edit**

  Read the updated section and confirm:
  - Verify/Push prompt appears before the Auto-PR block
  - Auto-PR block now carries the condition `when agents.auto_pr: true`
  - The stack command table is present
  - `push` output prints `git push -u origin {WORKTREE_BRANCH}` and `Then create your PR on GitHub.`

- [ ] **Step 4: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: replace auto-PR with verify/push prompt (auto_pr defaults to false)"
  ```

---

### Task 3: Gate CI polling behind `agents.auto_pr: true`

**Files:**
- Modify: `skills/nob/SKILL.md` — CI polling block

- [ ] **Step 1: Locate the CI polling block header**

  Find this exact line in `skills/nob/SKILL.md`:

  ```
  **CI polling** (PASS only — after `gh pr create` succeeds):
  ```

- [ ] **Step 2: Add the auto_pr gate**

  Using the Edit tool, replace:

  ```
  **CI polling** (PASS only — after `gh pr create` succeeds):
  ```

  With:

  ```
  **CI polling** (PASS only — after `gh pr create` succeeds, and only when `agents.auto_pr: true`):

  If `agents.auto_pr` is false or absent: skip CI polling entirely.
  ```

- [ ] **Step 3: Verify the edit**

  Read the CI polling section and confirm the gate condition appears at the top of the block.

- [ ] **Step 4: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: skip CI polling when agents.auto_pr is false"
  ```

---

### Task 4: Add `auto_pr` field to `.nob.yml.template`

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`

- [ ] **Step 1: Locate the insertion point**

  Open `skills/nob/templates/.nob.yml.template`. Find this block near the end of the `agents:` section:

  ```yaml
    checkpoint:
      enabled: true           # write/read checkpoint files on disk (default: true)
      path: .nob/             # directory for checkpoint.json
  ```

- [ ] **Step 2: Add the `auto_pr` field**

  Using the Edit tool, replace:

  ```yaml
    checkpoint:
      enabled: true           # write/read checkpoint files on disk (default: true)
      path: .nob/             # directory for checkpoint.json
  ```

  With:

  ```yaml
    checkpoint:
      enabled: true           # write/read checkpoint files on disk (default: true)
      path: .nob/             # directory for checkpoint.json

    auto_pr: false            # set true to auto-create a GitHub PR after Reviewer PASS (default: false — you create the PR manually)
  ```

- [ ] **Step 3: Verify the edit**

  Read the file and confirm `auto_pr: false` appears after the `checkpoint` block with its comment.

- [ ] **Step 4: Commit**

  ```bash
  git add skills/nob/templates/.nob.yml.template
  git commit -m "feat: add agents.auto_pr field to .nob.yml.template (default: false)"
  ```

---

## Self-Review Checklist

- [ ] **Spec coverage:**
  - `agents.auto_pr` defaults to false ✓ Task 1
  - Verify/push prompt shown when `auto_pr: false` ✓ Task 2
  - `verify` runs build + test suite ✓ Task 2
  - `push` prints git push command ✓ Task 2
  - `fix` preserves worktree ✓ Task 2
  - `auto_pr: true` keeps existing behavior ✓ Task 2 (Auto-PR block preserved under gate)
  - CI polling gated ✓ Task 3
  - `.nob.yml.template` updated ✓ Task 4

- [ ] **Placeholder scan:** No TBD, TODO, or incomplete steps — all edits show exact old/new strings.

- [ ] **Consistency:** `agents.auto_pr` naming is consistent across all four tasks. `WORKTREE_PATH` and `WORKTREE_BRANCH` referenced from existing hub context — no new variables introduced.
