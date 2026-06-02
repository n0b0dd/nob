# Critical Production Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Patch four critical reliability gaps in Nob's skill pipeline — execution-grounded test results, strict inter-agent output contracts, git worktree isolation per run, and timeout/hang recovery.

**Architecture:** Hub-centric enforcement — all validation, worktree management, and recovery logic lives in `skills/nob/SKILL.md`. Sub-agent files change only their output sections and test-capture steps. No new files are created; every change is an edit to an existing SKILL.md.

**Tech Stack:** Pure Markdown skill files. No runtime, no build step. Verification is read-back of the edited section.

---

## Task 1: Backend agent — test output capture + Deferred items + output format rule

**Files:**
- Modify: `skills/nob/backend-agent/SKILL.md`

- [ ] **Step 1: Read the current Step 5.5 and output format sections**

  Read `skills/nob/backend-agent/SKILL.md` lines 196–239 to confirm current content before editing.

- [ ] **Step 2: Replace Step 5.5 with verbatim-capture version**

  Find this exact block in `skills/nob/backend-agent/SKILL.md`:

  ```
  ### Step 5.5: Run tests and verify

  Run the full backend test suite using the command for your stack (see Stack-specific guidance). Capture the output.

  Record:
  - **New tests**: PASS / FAIL (number failed)
  - **Existing tests (regression)**: PASS / FAIL (number failed, list file names)

  If tests fail: attempt to fix. If the fix requires more than ~5 lines of non-obvious changes, stop and flag it in "Items not implemented (needs human)" — do not spiral.
  ```

  Replace with:

  ```
  ### Step 5.5: Run tests and verify

  Run the full backend test suite using the command for your stack (see Stack-specific guidance). Then run the type-checker/compiler if applicable:
  - TS: `npx tsc --noEmit`
  - Go: `go build ./...`
  - Python: `mypy .` (if mypy is installed)

  Capture stdout + stderr combined. If output exceeds 80 lines, keep the last 80 lines and prepend `[truncated — showing last 80 lines]`.

  Record:
  - **New tests**: PASS / FAIL (number failed)
  - **Existing tests (regression)**: PASS / FAIL (number failed, list file names)

  Include the verbatim captured output in `Test output:` in your output block. If no test command is detected, write `SKIPPED — no test command found`.

  If tests fail: attempt to fix. If the fix requires more than ~5 lines of non-obvious changes, stop and flag it in "Items not implemented (needs human)" — do not spiral.
  ```

- [ ] **Step 3: Add `Test output:` and `Deferred items:` fields to the output format block**

  Find this exact block in the `## Output Format` section:

  ```
  Test results:
    Command: [exact command run]
    New tests: [PASS | FAIL — N failed]
    Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]

  Items not implemented (needs human):
  - [specific item and reason, or: none]
  [/BACKEND-AGENT OUTPUT]
  ```

  Replace with:

  ```
  Test results:
    Command: [exact command run]
    New tests: [PASS | FAIL — N failed]
    Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]

  Test output:
    [verbatim last 80 lines of test runner + compiler stdout/stderr]
    (or: SKIPPED — no test command found)
    (or: SKIPPED — compile-only project, no test suite)

  Deferred items:
  - [item not implemented due to scope limit, or: none]

  Items not implemented (needs human):
  - [specific item and reason, or: none]
  [/BACKEND-AGENT OUTPUT]
  ```

- [ ] **Step 4: Add the OUTPUT FORMAT REQUIREMENT block before `## Output Format`**

  Find the line `## Output Format` in `skills/nob/backend-agent/SKILL.md`.

  Insert this block immediately before it:

  ```
  ## Output Format Requirement

  Your output block must:
  - Begin with `[BACKEND-AGENT OUTPUT]` on its own line (no leading spaces or characters)
  - End with `[/BACKEND-AGENT OUTPUT]` on its own line
  - Include every required field: `Files changed:`, `New API contracts:`, `Items not implemented:`, `Test results:`, `Test output:`
  - Use the exact field names listed — no synonyms, no omissions

  Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

  ```

- [ ] **Step 5: Verify the edit**

  Read `skills/nob/backend-agent/SKILL.md` lines 196–250. Confirm:
  - `Test output:` field appears in Step 5.5 prose
  - `Test output:` and `Deferred items:` fields appear in the output format block
  - `## Output Format Requirement` section is present above `## Output Format`
  - No unclosed code fences or broken Markdown

- [ ] **Step 6: Commit**

  ```bash
  git add skills/nob/backend-agent/SKILL.md
  git commit -m "feat: add test output capture and deferred items to backend-agent"
  ```

---

## Task 2: Frontend agent — test output capture + Deferred items + output format rule

**Files:**
- Modify: `skills/nob/frontend-agent/SKILL.md`

- [ ] **Step 1: Read the current Step 5.5 and output format sections**

  Read `skills/nob/frontend-agent/SKILL.md` lines 210–248 to confirm current content before editing.

- [ ] **Step 2: Replace Step 5.5 with verbatim-capture version**

  Find this exact block in `skills/nob/frontend-agent/SKILL.md`:

  ```
  ### Step 5.5: Run tests and verify

  Run the full frontend test suite using the command for your stack (see Stack-specific guidance). Capture the output.

  Record:
  - **New tests**: PASS / FAIL (number failed)
  - **Existing tests (regression)**: PASS / FAIL (number failed, list file names)

  If tests fail: attempt to fix. If the fix requires more than ~5 lines of non-obvious changes, stop and flag it in "Items not implemented (needs human)" — do not spiral.
  ```

  Replace with:

  ```
  ### Step 5.5: Run tests and verify

  Run the full frontend test suite using the command for your stack (see Stack-specific guidance). Then run the type-checker if applicable:
  - TS/TSX: `npx tsc --noEmit`
  - Flutter: `flutter analyze`

  Capture stdout + stderr combined. If output exceeds 80 lines, keep the last 80 lines and prepend `[truncated — showing last 80 lines]`.

  Record:
  - **New tests**: PASS / FAIL (number failed)
  - **Existing tests (regression)**: PASS / FAIL (number failed, list file names)

  Include the verbatim captured output in `Test output:` in your output block. If no test command is detected, write `SKIPPED — no test command found`.

  If tests fail: attempt to fix. If the fix requires more than ~5 lines of non-obvious changes, stop and flag it in "Items not implemented (needs human)" — do not spiral.
  ```

- [ ] **Step 3: Add `Test output:` and `Deferred items:` fields to the output format block**

  Find this exact block in the `## Output Format` section of `skills/nob/frontend-agent/SKILL.md`:

  ```
  Test results:
    Command: [exact command run]
    New tests: [PASS | FAIL — N failed]
    Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]

  Items not implemented (needs human):
  - [specific item and reason, or: none]
  [/FRONTEND-AGENT OUTPUT]
  ```

  Replace with:

  ```
  Test results:
    Command: [exact command run]
    New tests: [PASS | FAIL — N failed]
    Regression check: [PASS | FAIL — N failed, list files | SKIPPED — reason]

  Test output:
    [verbatim last 80 lines of test runner + type-checker stdout/stderr]
    (or: SKIPPED — no test command found)
    (or: SKIPPED — compile-only project, no test suite)

  Deferred items:
  - [item not implemented due to scope limit, or: none]

  Items not implemented (needs human):
  - [specific item and reason, or: none]
  [/FRONTEND-AGENT OUTPUT]
  ```

- [ ] **Step 4: Add the OUTPUT FORMAT REQUIREMENT block before `## Output Format`**

  Find the line `## Output Format` in `skills/nob/frontend-agent/SKILL.md`.

  Insert this block immediately before it:

  ```
  ## Output Format Requirement

  Your output block must:
  - Begin with `[FRONTEND-AGENT OUTPUT]` on its own line (no leading spaces or characters)
  - End with `[/FRONTEND-AGENT OUTPUT]` on its own line
  - Include every required field: `Files changed:`, `API endpoints consumed:`, `Items not implemented:`, `Test results:`, `Test output:`
  - Use the exact field names listed — no synonyms, no omissions

  Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

  ```

- [ ] **Step 5: Verify the edit**

  Read `skills/nob/frontend-agent/SKILL.md` lines 210–260. Confirm:
  - `Test output:` field appears in Step 5.5 prose
  - `Test output:` and `Deferred items:` fields appear in the output format block
  - `## Output Format Requirement` section is present above `## Output Format`

- [ ] **Step 6: Commit**

  ```bash
  git add skills/nob/frontend-agent/SKILL.md
  git commit -m "feat: add test output capture and deferred items to frontend-agent"
  ```

---

## Task 3: Reviewer — corroborate test results + handle Deferred items

**Files:**
- Modify: `skills/nob/reviewer/SKILL.md`

- [ ] **Step 1: Read Steps 2 and 3 of the reviewer**

  Read `skills/nob/reviewer/SKILL.md` lines 28–58 to confirm current content before editing.

- [ ] **Step 2: Replace Step 3 test-reading logic with corroboration logic**

  Find this exact block:

  ```
  For each block, extract:
  - Files changed/created
  - Items not implemented
  - `Test results:` section — store as BACKEND_TEST_RESULTS and FRONTEND_TEST_RESULTS

  If either test result is FAIL, overall tests are FAIL — the overall review status cannot be PASS. List each failing test as a human review item.
  ```

  Replace with:

  ```
  For each block, extract:
  - Files changed/created
  - Items not implemented
  - `Test results:` section — store as BACKEND_TEST_RESULTS and FRONTEND_TEST_RESULTS
  - `Test output:` section — store as BACKEND_TEST_OUTPUT and FRONTEND_TEST_OUTPUT

  **Test output corroboration (apply to each layer independently):**
  - If `Test output:` is absent → mark that layer's tests as `SKIPPED — agent did not provide raw test output`.
  - If `Test results: PASS` but `Test output:` contains any of the following strings: `ERROR`, `FAILED`, `panic`, `tsc error`, `SyntaxError`, `TypeError`, `AssertionError` → downgrade to `FAIL` and add to "Items for human review": "Test results claim PASS but Test output contains failure indicators — verify manually."
  - If `Test results: FAIL` → copy the first 10 lines of `Test output:` verbatim into "Items for human review".
  - Never infer PASS from `Test results:` alone — it must be corroborated by `Test output:`.

  If either test result is FAIL (after corroboration), overall tests are FAIL — the overall review status cannot be PASS.
  ```

- [ ] **Step 3: Add Step 2.5 for Deferred items handling**

  Find the line `### Step 3: Read all implementation output blocks` and insert this new step immediately before it:

  ```
  ### Step 2.5: Read Deferred items

  Check `[BACKEND-AGENT OUTPUT]` and `[FRONTEND-AGENT OUTPUT]` for a `Deferred items:` field.

  For each deferred item listed (any line that is not `none`):
  - Find the acceptance criterion in `[PM-AGENT OUTPUT]` that most closely matches the deferred item description.
  - Mark that criterion `⚠ partial` with reason: "deferred by agent due to scope limit — [deferred item text]".
  - Add to "Items for human review": "Deferred: [deferred item text]".

  If `Deferred items:` is absent or reads `none` for both agents, skip this step.

  ```

- [ ] **Step 4: Verify the edit**

  Read `skills/nob/reviewer/SKILL.md` lines 28–75. Confirm:
  - Step 2.5 appears between Step 2 and Step 3
  - Corroboration logic (error string matching, PASS downgrade) appears in Step 3
  - `Test output:` extraction appears in Step 3

- [ ] **Step 5: Commit**

  ```bash
  git add skills/nob/reviewer/SKILL.md
  git commit -m "feat: add test output corroboration and deferred items handling to reviewer"
  ```

---

## Task 4: Add output format rule to Planner, PM Agent, and Security Agent

**Files:**
- Modify: `skills/nob/planner/SKILL.md`
- Modify: `skills/nob/pm-agent/SKILL.md`
- Modify: `skills/nob/security-agent/SKILL.md`

- [ ] **Step 1: Add output format rule to Planner**

  In `skills/nob/planner/SKILL.md`, find the line `## Output Format`.

  Insert this block immediately before it:

  ```
  ## Output Format Requirement

  Your output block must:
  - Begin with `[PLAN OUTPUT]` on its own line (no leading spaces or characters)
  - End with `[/PLAN OUTPUT]` on its own line
  - Include every required field: `Workflow:`, `Mode:`, `Affected layers:`, `Risks:`, `Ambiguities:`
  - Use the exact field names listed — no synonyms, no omissions

  Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

  ```

- [ ] **Step 2: Add output format rule to PM Agent**

  In `skills/nob/pm-agent/SKILL.md`, find the `## Output Format` section for requirements-extraction mode (search for `[PM-AGENT OUTPUT]` in the output format section).

  Add this block immediately before that `## Output Format` heading:

  ```
  ## Output Format Requirement

  Your output block must:
  - Begin with `[PM-AGENT OUTPUT]` on its own line (no leading spaces or characters)
  - End with `[/PM-AGENT OUTPUT]` on its own line
  - Include every required field: `Requirements:`, `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:`
  - Use the exact field names listed — no synonyms, no omissions

  Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

  ```

- [ ] **Step 3: Add output format rule to Security Agent**

  In `skills/nob/security-agent/SKILL.md`, find the `## Output Format` section (search for `[SECURITY-AGENT OUTPUT]`).

  Add this block immediately before that `## Output Format` heading:

  ```
  ## Output Format Requirement

  Your output block must:
  - Begin with `[SECURITY-AGENT OUTPUT]` on its own line (no leading spaces or characters)
  - End with `[/SECURITY-AGENT OUTPUT]` on its own line
  - Include every required field: `Status:`, `Findings:`
  - Use the exact field names listed — no synonyms, no omissions

  Missing or misformatted fields will cause your output to be rejected and re-requested by the hub.

  ```

- [ ] **Step 4: Verify all three edits**

  Read the `## Output Format Requirement` section from each file to confirm it was inserted correctly and the heading hierarchy is intact.

- [ ] **Step 5: Commit**

  ```bash
  git add skills/nob/planner/SKILL.md skills/nob/pm-agent/SKILL.md skills/nob/security-agent/SKILL.md
  git commit -m "feat: add output format requirement blocks to planner, pm-agent, security-agent"
  ```

---

## Task 5: Hub — git worktree isolation

**Files:**
- Modify: `skills/nob/SKILL.md`

- [ ] **Step 1: Read hub Step 0**

  Read `skills/nob/SKILL.md` lines 22–35 (the current Step 0: Git branch safety block) to confirm content before editing.

- [ ] **Step 2: Add worktree creation to Step 0**

  Find the end of the Step 0 block — the line that reads:

  ```
  If git is not available or the working directory is not a git repo, skip this step and note it in the terminal summary.
  ```

  Insert this new sub-step immediately after that line:

  ```

  ### Step 0.1: Create worktree

  After confirming the current branch (or creating a new one above):

  1. Derive run-id by taking the branch name, replacing `/` with `-`, then appending `-` and the source filename without extension.
     - Example: branch `nob/user-profile` + spec `user-profile.md` → run-id `nob-user-profile-user-profile`
     - For workflows with no source file (Init, Venture, Refactor, Ideate): use `<branch-name-with-dashes>-<workflow-lowercase>`

  2. Run: `git worktree add .nob/worktrees/<run-id> <current-branch-name>`
     - If the path `.nob/worktrees/<run-id>` already exists: this is a resumed run — reuse it, skip creation.
     - If a different collision: append `-2`, `-3`, etc. to run-id until unique.
     - If `git worktree add` fails for any other reason: print the error and exit.

  3. Store `WORKTREE_PATH = .nob/worktrees/<run-id>` and `WORKTREE_BRANCH = <current-branch-name>`.

  4. Ensure `.nob/` and `.nob/worktrees/` appear in `.gitignore` at the repo root. If absent, append:
     ```
     .nob/
     ```
     using the Edit tool.

  5. From this point on, all agent dispatches must use `Working directory: {WORKTREE_PATH}` instead of the current directory path.

  If git is not available or not a git repo: skip Step 0.1 entirely. Set WORKTREE_PATH = current working directory. Note "No worktree created — not a git repo" in the terminal summary.
  ```

- [ ] **Step 3: Add worktree restoration to Phase 0 (resume scan)**

  Find the Phase 0 block. Locate the paragraph that begins:

  ```
  If the file exists and is valid JSON:
  ```

  After the numbered list items in that paragraph (items 1, 2, 3), add:

  ```
  4. If `worktree_path` is set in the checkpoint: restore `WORKTREE_PATH` from it. If the path does not exist on disk, re-create the worktree: `git worktree add {worktree_path} {worktree_branch}`.
  ```

- [ ] **Step 4: Add worktree teardown to Step 4 (terminal summary)**

  Find the start of `## Step 4: Print terminal summary`. Locate the **For all other workflows** terminal summary block — the one that ends with:

  ```
  - Then: git push -u origin <branch-name>
  ```

  After that closing line (still inside the code fence), add:

  ```

  [if worktree was created:]
  Worktree: .nob/worktrees/<run-id>
  ```

  Then, after the closing ` ``` ` of the terminal summary code fence, add this new block:

  ```

  **Worktree teardown** (run after printing the summary above):

  If `Overall status: PASS`:
  - Run: `git -C {WORKTREE_PATH} add -A`
  - Run: `git -C {WORKTREE_PATH} commit -m "nob: {run-id}"` (skip if nothing to commit)
  - Run: `git worktree remove .nob/worktrees/<run-id>`
  - Print: `Worktree committed and removed. Branch: {WORKTREE_BRANCH}`
  - Print: `Next: git push -u origin {WORKTREE_BRANCH}`

  If `Overall status: FAIL` or `NEEDS REVIEW`:
  - Preserve the worktree for inspection.
  - Print: `Worktree preserved at .nob/worktrees/<run-id> for inspection.`
  - Print: `To clean up: git worktree remove .nob/worktrees/<run-id> --force`

  If run was cancelled or hit an unrecoverable error (reached via the Error Handling section):
  - Run: `git worktree remove .nob/worktrees/<run-id> --force`
  - Print: `Run cancelled — worktree cleaned up.`

  If WORKTREE_PATH equals the current working directory (git not available): skip teardown.
  ```

- [ ] **Step 5: Update checkpoint schema in Phase 1**

  Find the Phase 1 checkpoint write block — the JSON shown in:

  ```json
  {
    "run_id": "{current-branch}-{source-filename-without-extension}",
  ```

  Replace that JSON block with:

  ```json
  {
    "run_id": "{run-id derived in Step 0.1}",
    "worktree_path": "{WORKTREE_PATH}",
    "worktree_branch": "{WORKTREE_BRANCH}",
    "workflow": "{workflow value from PLAN_OUTPUT}",
    "source": "{source file path}",
    "phases_completed": ["phase1"],
    "slices": {
      "{slice-name}": {
        "status": "pending",
        "timed_out_at": null,
        "pm_output": null,
        "backend_output": null,
        "frontend_output": null
      }
    },
    "reviewer_output": null
  }
  ```

- [ ] **Step 6: Verify all worktree edits**

  Read the following sections of `skills/nob/SKILL.md` and confirm each change is present:
  - Step 0.1 block exists after the git-not-available note in Step 0
  - Phase 0 has item 4 restoring `worktree_path`
  - Step 4 has the worktree teardown block
  - Phase 1 checkpoint JSON has `worktree_path` and `worktree_branch` fields

- [ ] **Step 7: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: add git worktree isolation to hub (step 0.1, phase 0 resume, step 4 teardown)"
  ```

---

## Task 6: Hub — output validation after every agent dispatch

**Files:**
- Modify: `skills/nob/SKILL.md`

- [ ] **Step 1: Read the current Phase 1 dispatch block**

  Read `skills/nob/SKILL.md` lines 529–585 (Planner dispatch section) to understand the current extraction pattern before editing.

- [ ] **Step 2: Add the shared validation procedure definition**

  Find the line `## Phase 0: Resume scan` in `skills/nob/SKILL.md`.

  Insert this new section immediately before it (before Phase 0):

  ```
  ## Output Block Validation Procedure

  After extracting any `[X OUTPUT]...[/X OUTPUT]` block from an agent result, apply this procedure before passing the output to the next agent. The required fields per agent are:

  | Agent | Required fields |
  |---|---|
  | Planner | `Workflow:`, `Mode:`, `Affected layers:`, `Risks:`, `Ambiguities:` |
  | PM Agent | `Requirements:`, `API contracts:`, `Backend changes needed:`, `Frontend changes needed:`, `Acceptance criteria:` |
  | Backend Agent | `Files changed:`, `New API contracts:`, `Items not implemented:`, `Test results:`, `Test output:` |
  | Frontend Agent | `Files changed:`, `API endpoints consumed:`, `Items not implemented:`, `Test results:`, `Test output:` |
  | Security Agent | `Status:`, `Findings:` |
  | Reviewer | `Overall status:`, `Test results:`, `Criteria check:`, `Items for human review:` |

  **Validation steps:**
  1. Check that every required field for this agent appears as `FieldName:` on its own line within the extracted block.
  2. If all required fields are present: proceed normally.
  3. If any required field is missing:
     - Re-dispatch the agent once, prepending to the original prompt:
       > "Your previous response was missing these required fields: [list the missing fields].
       > Re-emit the complete [X OUTPUT] block with ALL required fields present.
       > Do not omit any field even if its value is 'none' or 'n/a'."
  4. If still missing after re-dispatch: mark the agent/slice status as `malformed`. Do not pass a malformed block to downstream agents. Treat `malformed` the same as `failed` for all pipeline flow decisions.

  Apply this procedure after every agent dispatch in Phases 1, 2, 2.5, and 3.

  ---

  ```

- [ ] **Step 3: Add validation call-out after each major agent extraction**

  Find the line in Phase 1 that reads (after the Planner dispatch block):

  ```
  Extract `[PLAN OUTPUT]...[/PLAN OUTPUT]` from the result. Store as PLAN_OUTPUT.
  ```

  Append to that line:

  ```
   Apply the **Output Block Validation Procedure** for Planner before proceeding.
  ```

  Find the line in Phase 2 (single-slice PM Agent section):

  ```
  Extract `[PM-AGENT OUTPUT]...[/PM-AGENT OUTPUT]`. Store as PM_OUTPUT.
  ```

  Append:

  ```
   Apply the **Output Block Validation Procedure** for PM Agent before proceeding.
  ```

  Find the line in Phase 2.5:

  ```
  Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT.
  ```

  Append:

  ```
   Apply the **Output Block Validation Procedure** for Security Agent before proceeding.
  ```

  Find the line in Phase 3:

  ```
  Extract `[REVIEWER OUTPUT]...[/REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT.
  ```

  Append:

  ```
   Apply the **Output Block Validation Procedure** for Reviewer before proceeding.
  ```

- [ ] **Step 4: Verify the validation section**

  Read the new `## Output Block Validation Procedure` section. Confirm:
  - Required fields table is complete for all 6 agents
  - Steps 1–4 are present with the re-dispatch prompt text
  - The `malformed` status is defined

- [ ] **Step 5: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: add output block validation procedure to hub"
  ```

---

## Task 7: Hub — scope cap, timed_out status, and terminal summary updates

**Files:**
- Modify: `skills/nob/SKILL.md`

- [ ] **Step 1: Read Phase 2 backend + frontend dispatch prompts**

  Read `skills/nob/SKILL.md` lines 620–690 (the Backend Agent and Frontend Agent dispatch blocks in Phase 2) to locate where to inject the scope cap.

- [ ] **Step 2: Inject scope cap into Backend Agent dispatch prompt**

  In the single-slice Backend Agent dispatch block (Phase 2), find the `[INPUTS]` section of the prompt. It currently ends before the closing ` ``` `. Find the line:

  ```
  {if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
  [/INPUTS]
  ```
  (in the Backend Agent dispatch prompt)

  Insert the scope cap before `[/INPUTS]`:

  ```

  SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
  ```

- [ ] **Step 3: Inject scope cap into Frontend Agent dispatch prompt**

  Find the equivalent `[/INPUTS]` closing line in the single-slice **Frontend Agent** dispatch prompt and insert the same scope cap block before it.

- [ ] **Step 3.5: Inject scope cap into fan-out slice runner prompts**

  In the fan-out path (Phase 2 `### Fan-out path` section), find the embedded **Backend Agent call prompt** inside the slice runner's `[INSTRUCTIONS]` block. It has an `[INPUTS]` section ending with:

  ```
  {if clarifications: Clarifications from user: {answers}}
  [/INPUTS]
  ```
  (inside the Backend Agent call prompt, inside the slice runner prompt)

  Insert the same scope cap before that `[/INPUTS]`:

  ```

  SCOPE LIMIT: If completing this task requires touching more than 15 files, implement the highest-priority items first (core logic, primary happy path, critical data model changes). Stop before reaching the limit. List any remaining unimplemented work under Deferred items: in your output block. A focused partial result is better than a timeout with no output.
  ```

  Repeat the same insertion for the **Frontend Agent call prompt** `[/INPUTS]` inside the same slice runner block.

- [ ] **Step 4: Update missing-output-block handling to use `timed_out`**

  Find the section in the **Error Handling** block (bottom of the hub) that reads:

  ```
  - **Non-slice agent result missing expected output block**: re-dispatch once; if still missing, report raw agent output and stop
  ```

  Replace with:

  ```
  - **Non-slice agent result missing expected output block**: re-dispatch once; if still missing after re-dispatch, mark status `timed_out` (store `timed_out_at: "<phase>/<agent-name>"`). Do NOT pass null output to downstream agents. For fan-out: skip this slice and continue remaining slices. For single mode: stop pipeline and skip Reviewer.
  ```

  Also find:

  ```
  - **Slice agent returns no [SLICE OUTPUT] block**: re-dispatch that slice once; if still missing, mark `status: failed`, continue other slices, report in terminal summary (Phase 2)
  ```

  Replace with:

  ```
  - **Slice agent returns no [SLICE OUTPUT] block**: re-dispatch that slice once; if still missing, mark `status: timed_out` (store `timed_out_at: "phase2/slice-runner"`), continue other slices, report in terminal summary (Phase 2)
  ```

- [ ] **Step 5: Add timed_out and malformed to the terminal summary**

  In the **For all other workflows** terminal summary code fence, find the line:

  ```
  [if NEEDS REVIEW or FAIL: list items from REVIEWER OUTPUT "Items for human review" section]
  ```

  Insert after it (still inside the code fence):

  ```

  [if any slice status is timed_out:]
  Timed out:
    [slice-name]: timed out at [timed_out_at value]
    Re-run `/nob [spec-file]` to resume — checkpoint skips completed slices.

  [if any slice status is malformed:]
  Malformed output:
    [slice-name]: [agent-name] returned invalid output block after two attempts
    Check agent output above, then re-run `/nob [spec-file]` to retry.
  ```

- [ ] **Step 6: Verify all Gap 4 edits**

  Read the relevant sections of `skills/nob/SKILL.md` and confirm:
  - Scope cap text appears in both Backend and Frontend dispatch prompts
  - Error Handling section uses `timed_out` (not `failed`) for missing output blocks
  - Terminal summary includes `timed_out` and `malformed` display blocks

- [ ] **Step 7: Commit**

  ```bash
  git add skills/nob/SKILL.md
  git commit -m "feat: add scope cap, timed_out status, and terminal summary for Gap 4"
  ```

---

## Self-Review Checklist

After all tasks are complete, verify spec coverage:

| Spec requirement | Task that implements it |
|---|---|
| Backend/frontend agents capture verbatim test output | Tasks 1, 2 |
| Reviewer corroborates Test results: claim with Test output: | Task 3 |
| Deferred items: treated as ⚠ partial by reviewer | Tasks 1, 2, 3 |
| Output format requirement block in all sub-agents | Tasks 1, 2, 4 |
| Hub validates required fields after every dispatch | Task 6 |
| Hub re-dispatches with repair prompt on missing fields | Task 6 |
| `malformed` status defined and propagated | Task 6 |
| `git worktree add` in Step 0.1 | Task 5 |
| All agents use WORKTREE_PATH as working directory | Task 5 |
| Worktree restored on Phase 0 resume | Task 5 |
| Worktree committed + removed on PASS | Task 5 |
| Worktree preserved on FAIL/NEEDS REVIEW | Task 5 |
| Checkpoint schema includes worktree_path, worktree_branch | Task 5 |
| Scope cap (15-file soft limit) injected into agent prompts | Task 7 |
| Missing output block → `timed_out` (not just `failed`) | Task 7 |
| `timed_out_at` stored in checkpoint | Task 7 |
| Terminal summary shows timed_out/malformed with resume instructions | Task 7 |
