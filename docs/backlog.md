# Nob — Remaining Gaps Backlog

Critical gaps are done. These are the next tiers, ordered by impact.

---

## High Impact

### H1: Token / cost visibility
Fan-out runs with many slices can burn hundreds of thousands of tokens silently. No budget guardrail exists.
- Add `max_tokens_per_run` field to `.nob.yml`
- Report per-agent token usage in the terminal summary
- Warn before dispatching fan-out if estimated cost exceeds budget

### H2: Observability / audit trail
The checkpoint captures agent outputs but not: which model ran, how long it took, how many tokens it used, or what error it hit. No debugging surface when a run fails.
- Extend checkpoint schema with per-agent metadata: `model`, `duration_ms`, `tokens`, `error`
- Write a structured run log to `.nob/run-<run-id>.log` alongside `checkpoint.json`

### H3: Spec pre-flight validation
The Planner reads whatever the user passes with no validation. A missing file, a broken path reference, or a blank spec produces garbage output silently.
- Add a pre-flight step before Phase 1: confirm spec file exists, is non-empty, and contains an `## Acceptance criteria` section
- If validation fails: print specific error and exit before dispatching any agents

---

## Medium Impact

### M1: Auto-PR creation
The terminal summary tells the user to `git push` manually. A pipeline that already ran Planner → PM → Backend → Frontend → Security → Reviewer should auto-create the PR.
- On `Overall status: PASS`, after worktree teardown: run `gh pr create` with reviewer output as the PR body and spec path as context
- Gate on `gh` being available; fall back to printing the push command if not

### M2: CI/CD / webhook trigger
Nob only runs interactively inside Claude Code. It can't be triggered from a GitHub PR comment, a GitHub Action, or a Slack command.
- Design a thin webhook → Claude Code CLI bridge
- At minimum: document how to invoke `claude -p "/nob implement <spec>"` from a GitHub Action

### M3: Dry-run / plan preview
No way to see what the Planner would produce — slice count, ambiguities, scope — without committing to a full run. For large specs this matters.
- Add `--plan-only` flag support: run Phase 1 only, print PLAN_OUTPUT, exit
- Hub detects `--plan-only` in the user's message before Step 1

---

## Lower Priority

### L1: Cross-run memory
Agents rediscover the same project patterns (test runner, auth pattern, migration tooling) on every run. No accumulation across sessions.
- Write a `.nob/project-memory.md` after each completed run with observed patterns
- Include it in the CLAUDE.md / `.nob.yml` contents passed to each agent

### L2: Long-run notifications
Fan-out runs with many slices can take 20+ minutes. No notification when done.
- Use Claude Code's push notification support at the end of Step 4

### L3: Model cost defaults
`backend-agent` and `frontend-agent` default to `sonnet` on every run. For simple specs this is expensive.
- Add complexity-based model selection: Planner's `Complexity: simple` → use `haiku` for that agent
- Document recommended `.nob.yml` model overrides for cost-conscious teams
