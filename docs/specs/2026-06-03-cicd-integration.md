# CI/CD Integration & Auto-PR Status Tracking

## Problem statement
Nob creates a worktree, commits code, and optionally opens a PR — but treats the task as done the moment the Reviewer outputs `Overall status: PASS`. This conflates local test success with CI success. A green local run with a broken CI pipeline (type errors on a different Node version, a flaky integration test, a missing env var in CI) is indistinguishable from a true success. Tools like Sweep AI and Devin treat CI feedback as the authoritative acceptance signal and won't mark a task complete until all checks pass. Nob has no equivalent.

## Proposed solution
After `gh pr create` succeeds in the worktree teardown step, the hub enters a CI polling loop using `gh run watch`. It polls the most recent workflow run on the PR branch every 30 seconds (up to a configurable timeout, default 10 minutes). If all checks pass, it prints the green summary and exits normally. If any check fails, it extracts the failing step name and logs from `gh run view --log-failed`, surfaces them to the user, and asks: "CI failed on [check name]. Re-trigger retry loop? (yes / skip)". If the user says yes, the hub re-dispatches only the relevant impl agent(s) with the CI log as additional context, then re-commits and re-pushes. If the user says skip or timeout is reached, it exits with status `NEEDS REVIEW` and prints the CI failure summary.

## Acceptance criteria
- After a successful `gh pr create`, the hub runs `gh run watch --exit-status` on the PR's head SHA
- Polling interval is 30 seconds; timeout is configurable via `.nob.yml` under `agents.ci.timeout_minutes` (default: 10)
- On CI pass: terminal summary shows `CI: PASS` and exits
- On CI failure: hub extracts failed step logs via `gh run view --log-failed` and prints them
- User is prompted to re-trigger the retry loop with the CI logs as additional context
- If `gh` is not available or no CI workflow exists on the repo, this step is skipped silently with `CI: SKIPPED (gh unavailable)` in the summary
- If `agents.ci.enabled: false` in `.nob.yml`, CI polling is skipped entirely
- The retry loop invoked from CI failure uses the same Phase 3.5 logic, with `CI log:` injected into the impl agent prompt

## Affected files
- `skills/nob/SKILL.md` — add CI polling step after worktree teardown; add `CI:` line to terminal summary format; extend Phase 3.5 to accept CI log as retry context
- `skills/nob/templates/.nob.yml.template` — document `agents.ci.enabled` and `agents.ci.timeout_minutes` fields

## Out of scope
- Support for CI providers other than GitHub Actions (GitLab CI, CircleCI, etc.)
- Parsing structured test output from CI logs (only the raw failed-step log is surfaced)
- Auto-merging the PR after CI passes
