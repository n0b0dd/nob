# Feature: Verify Step and Manual PR

## Summary
Replace the auto-PR step at the end of the nob pipeline with a verify/push prompt — letting users run the actual build and test suite before manually creating a PR — while keeping auto-PR available as an opt-in config flag.

## Users
Developers running `/nob implement` who want to verify the implementation works before creating a PR.

## Platform targets
<!-- Not applicable — this is a CLI pipeline change, not a web/mobile feature -->

## User flow
1. Reviewer returns PASS — pipeline commits changes to the worktree
2. Pipeline prints: `"Implementation complete. What next? (verify / push)"`
3a. User types `verify`:
    - Pipeline runs the build command for the detected stack in WORKTREE_PATH
    - Pipeline runs the test suite for the detected stack in WORKTREE_PATH
    - Pipeline shows combined output
    - Pipeline prompts: `"push / fix"`
      - `push` → print git push command, exit
      - `fix` → preserve worktree, print path, exit
3b. User types `push`:
    - Pipeline prints `git push -u origin {branch}` and exits
    - User creates PR manually on GitHub

## Requirements
- `agents.auto_pr` config key controls whether PR is created automatically (default: false)
- When `agents.auto_pr: false` (default): show verify/push prompt after Reviewer PASS
- When `agents.auto_pr: true`: existing auto-PR behavior is unchanged
- `verify` runs the build command, then the test suite, using stack-appropriate commands
- `verify` shows combined build + test output without truncation
- `verify` result does not block the push option — user always decides
- CI polling only runs when `agents.auto_pr: true`
- `.nob.yml.template` includes `agents.auto_pr: false` with a comment

## API contracts
not applicable

## Data models
not applicable

## Acceptance criteria
- [ ] When `agents.auto_pr` is absent from `.nob.yml`, pipeline defaults to false (no auto-PR)
- [ ] After Reviewer PASS with `auto_pr: false`, pipeline shows "verify / push" prompt instead of creating a PR
- [ ] `verify` runs the build command for the resolved stack type in `WORKTREE_PATH`
- [ ] `verify` runs the test suite for the resolved stack type in `WORKTREE_PATH`
- [ ] `verify` shows full build + test output, then prompts "push / fix"
- [ ] `push` (from verify or directly) prints `git push -u origin {WORKTREE_BRANCH}` and exits
- [ ] `fix` preserves the worktree and prints `Worktree preserved at {WORKTREE_PATH}`
- [ ] When `agents.auto_pr: true`, existing auto-PR and CI polling behavior is unchanged
- [ ] CI polling block is skipped when `agents.auto_pr: false`
- [ ] `.nob.yml.template` includes `auto_pr: false` under `agents:` with an explanatory comment

## Builds on
- `skills/nob/SKILL.md` — Extract from RESOLVED_CONFIG section, Step 4 (Auto-PR block, CI polling block)
- `skills/nob/templates/.nob.yml.template` — agents section

## Constraints
- No new files — all changes are edits to existing files
- Stack command detection reuses the same stack type values already resolved in Step 1
- A failed build or test does not prevent the user from pushing — they always get the push option

## Error states
- Build command not detected for stack type: print "Build step skipped — stack type not recognised." proceed to test
- Test command not detected: print "Test step skipped — stack type not recognised." proceed to push prompt
- Build exits non-zero: print full output, still show "push / fix" prompt
- Test exits non-zero: print full output, still show "push / fix" prompt

## Out of scope
- Visual / screenshot verification
- Deployment to staging
- E2E browser automation
- Changing verify behavior when `agents.auto_pr: true`

## Open questions
- none
