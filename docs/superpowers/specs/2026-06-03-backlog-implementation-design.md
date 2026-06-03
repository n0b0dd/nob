# Nob Backlog Implementation — Design Spec

**Date:** 2026-06-03
**Branch:** nob/2026-06-02-ideation-agent-design
**Approach:** Single-pass hub update (Approach A)

## Overview

Implements eight backlog items from `docs/backlog.md`. All changes concentrate in two files:

- `skills/nob/SKILL.md` — hub orchestrator
- `skills/nob/templates/.nob.yml.template` — user config template

M2 (CI/CD webhook trigger) is deferred — pure documentation, not a plugin change.

---

## Items in scope

| ID | Title | Priority |
|----|-------|----------|
| H1 | Token / cost visibility (model-per-agent + budget guard) | High |
| H2 | Observability / audit trail | High |
| H3 | Spec pre-flight validation | High |
| M1 | Auto-PR creation | Medium |
| M3 | Dry-run / plan preview (`--plan-only`) | Medium |
| L1 | Cross-run memory | Lower |
| L2 | Long-run push notification | Lower |
| L3 | Complexity-based model selection | Lower |

---

## Pipeline placement

```
Step 0:    Git branch + worktree (unchanged)
Step 0.5:  Structure check (unchanged)
Step 1:    Read config
           → Extract agents.max_tokens_per_run (H1)
           → Extract project-memory if .nob/project-memory.md exists (L1)

Step 1.5:  Pre-flight validation [NEW] (H3)
           → Spec→Code and Bug→Fix workflows only
           → Verify: spec path non-empty, file readable, file non-empty,
             contains "## Acceptance criteria" (case-insensitive)
           → On failure: print specific error, exit before any agent dispatch

Step 2:    Identify workflow type (unchanged)
           → Detect --plan-only flag in user message (M3)

Phase 0:   Resume scan (unchanged)
Phase 1:   Planner dispatch
           → On return: apply L3 complexity model override
           → Initialize run log .nob/run-<run-id>.log (H2)
           → Add run_start_time and agents{} to checkpoint (H2)

           [if --plan-only]: print PLAN_OUTPUT, exit (M3)

           [if fan-out + max_tokens_per_run set]: budget guard (H1)

Phase 2:   Agent dispatch
           → Record started_at before each dispatch (H2)
           → After each return: update agents[name] in checkpoint (H2)
           → Pass "Project memory:" field in each agent's [INPUTS] (L1)

Phase 2.5: Security review (unchanged)
Phase 3:   Merge review (unchanged)
Phase 3.5: Targeted retry (unchanged)

Step 4:    Terminal summary
           → New line: Agents: planner(haiku) · backend-agent(sonnet) · ... (H1)
           → New line: Timing: backend-agent 14s · reviewer 8s · ... (H2)
           → On PASS: run gh pr create (M1)
           → Send PushNotification (L2)

Step 4.5:  Post-run memory write [NEW] (L1)
           → PASS only
           → Extract test runner, key routes, primary files changed
           → Append dated entry to .nob/project-memory.md
           → Append final summary line to run log (H2)
```

---

## Feature specifications

### H1 — Model visibility + budget guard

**Config field** (new in `.nob.yml`):
```yaml
agents:
  max_tokens_per_run: 500000   # optional; no default (guard disabled if absent)
```

**Budget guard** (pre-fan-out, Phase 1):
- Only fires when `max_tokens_per_run` is set AND `Mode: fan-out`.
- Estimate: sonnet slice = 2 units, haiku slice = 1 unit. Total = sum across all slices.
- Map each slice's agent model to its unit value. If slice model is sonnet → 2, haiku → 1.
- If total units × 100 000 > max_tokens_per_run: print warning and ask `(yes / abort)`.
- Rough heuristic only — prints "estimated ~N units" not exact token counts.

**Terminal summary line**:
```
Agents:  planner(haiku) · pm-agent(haiku) · backend-agent(sonnet) · frontend-agent(sonnet) · security-agent(haiku) · reviewer(haiku)
```
List only agents that actually ran (skip disabled/skipped agents).

---

### H2 — Observability / audit trail

**Checkpoint schema additions**:
```json
{
  "run_start_time": "2026-06-03T10:00:00Z",
  "agents": {
    "planner": { "model": "haiku", "started_at": "...", "duration_ms": 4200, "error": null },
    "pm-agent": { "model": "haiku", "started_at": "...", "duration_ms": 3100, "error": null },
    "backend-agent": { "model": "sonnet", "started_at": "...", "duration_ms": 18000, "error": null }
  }
}
```

**Run log** — written to `.nob/run-<run-id>.log`:
- Created at Phase 1 checkpoint write using the Write tool.
- Hub appends a line (read + edit) after each agent completes:
  ```
  2026-06-03T10:00:04Z  planner         haiku   OK      4200ms
  2026-06-03T10:00:07Z  pm-agent        haiku   OK      3100ms
  2026-06-03T10:00:25Z  backend-agent   sonnet  OK     18000ms
  2026-06-03T10:00:33Z  reviewer        haiku   OK      7800ms
  ```
- Final line appended at end of Step 4:
  ```
  2026-06-03T10:00:34Z  run             -       PASS   33100ms total
  ```
- Log file is NOT cleaned up on PASS (persists alongside checkpoint for audit).

**Timing in terminal summary**:
```
Timing:  planner 4s · pm-agent 3s · backend-agent 18s · reviewer 8s
```
Show only agents that ran. Omit milliseconds — round to nearest second.

**Timestamps**: Hub records timestamps by running `date -u +%FT%TZ` via the Bash tool before and after each agent dispatch. Duration = end_epoch - start_epoch, computed via `date +%s`. Both calls are cheap single-line Bash commands. Duration display in the terminal summary rounds to nearest second.

---

### H3 — Spec pre-flight validation

**New Step 1.5** — runs only for `Spec→Code` and `Bug→Fix` workflows (skip for Init, Venture, Refactor, Ideate, `--plan-only`).

Checks in order:
1. Spec file path is present in the user's message (not empty string).
2. Read tool can open the file (file exists).
3. File content length > 0 characters.
4. File content contains `## acceptance criteria` (case-insensitive substring match).

On first failure, print the specific error and exit:
- Path missing: `"Error: no spec file path provided. Usage: /nob implement <path-to-spec.md>"`
- File not found: `"Error: spec file not found: <path>. Check the path and try again."`
- File empty: `"Error: spec file is empty: <path>."`
- Missing acceptance criteria: `"Error: spec file has no ## Acceptance criteria section: <path>. Add one before running nob."`

No agents dispatched on any of these failures.

---

### M1 — Auto-PR creation

**After worktree teardown on PASS only.**

1. Run `gh --version` to check availability.
2. If available:
   - Run:
     ```
     gh pr create \
       --title "<spec filename without path and extension>" \
       --body "<first 3000 characters of REVIEWER_OUTPUT>" \
       --head <WORKTREE_BRANCH>
     ```
   - Print: `PR created: <returned URL>`
3. If not available: print the existing `git push -u origin <branch>` command as today.

The PR body is truncated at 3000 characters to stay within `gh` CLI limits.

---

### M3 — `--plan-only` flag

**Detection**: hub checks the user's original message for the string `--plan-only` before Step 1.

**Behavior when flag detected**:
- Run Steps 0, 0.1, 0.5, Step 1 normally.
- Skip Step 1.5 (pre-flight) — plan-only is exploratory; no need to gate on acceptance criteria.
- Run Phase 1 (Planner only).
- After extracting PLAN_OUTPUT: print it verbatim to the terminal.
- Print: `"Plan-only run complete. Re-run without --plan-only to execute."`
- Exit. No PM, Backend, Frontend, Security, or Reviewer dispatch.

No checkpoint is written for plan-only runs. No worktree teardown needed (nothing was committed).

---

### L1 — Cross-run memory

**Read phase** (Step 1, after config extraction):
- Check whether `.nob/project-memory.md` exists using the Read tool.
- If found and non-empty: store as PROJECT_MEMORY.
- Pass to every agent via a `Project memory:` field appended to the `[INPUTS]` block:
  ```
  Project memory:
  {PROJECT_MEMORY, or: "none"}
  ```

**Write phase** (Step 4.5 — new, runs after terminal summary, PASS only):
- Extract from agent outputs:
  - **Test runner**: scan BACKEND_OUTPUT `Test output:` for known runner names: `jest`, `vitest`, `pytest`, `go test`, `rspec`, `mocha`. First match wins. Default: `unknown`.
  - **Key routes**: extract `New API contracts:` lines from BACKEND_OUTPUT (up to 5).
  - **Primary files changed**: top 3 paths from `Files changed:` in BACKEND_OUTPUT, top 3 from FRONTEND_OUTPUT.
- Append to `.nob/project-memory.md` (read existing content or start empty, append new entry, write back):
  ```markdown
  ## Run: <run-id> (<YYYY-MM-DD>)
  Spec: <spec file path>
  Test runner: <detected>
  Key routes: <list, or none>
  Backend files: <top 3, or none>
  Frontend files: <top 3, or none>
  ```

---

### L2 — Push notification

At the end of Step 4, after printing the terminal summary and worktree teardown:

Use the `PushNotification` tool with:
- `title`: `"Nob complete"`
- `body`: `"<workflow> · <spec filename> · <Overall status from REVIEWER_OUTPUT>"`

For Init/Refactor/Ideate/Venture workflows, use their respective status field values.

If `PushNotification` is not available (tool not found), skip silently.

---

### L3 — Complexity-based model selection

**Applied after extracting PLAN_OUTPUT in Phase 1**, before any agent dispatch.

Rules:
1. Read `Complexity.backend` and `Complexity.frontend` from PLAN_OUTPUT.
2. If `Complexity.backend = "simple"` AND `.nob.yml` did NOT explicitly set `agents.models.backend-agent`: override backend-agent's resolved model to `haiku`.
3. If `Complexity.frontend = "simple"` AND `.nob.yml` did NOT explicitly set `agents.models.frontend-agent`: override frontend-agent's resolved model to `haiku`.
4. If `.nob.yml` explicitly set a model (i.e., the key is present in the `agents.models` map): always respect it, regardless of complexity.

"Explicitly set" = the key `backend-agent` or `frontend-agent` appears in the `.nob.yml` `agents.models` block. Auto-detected configs (no `.nob.yml`) never have explicit overrides; L3 applies freely.

L3 overrides are reflected in the H1 terminal summary line.

---

## .nob.yml template changes

Add one new field under `agents`:

```yaml
agents:
  max_tokens_per_run: 500000  # optional; omit to disable budget guard
```

Add a comment under the existing `models` block noting L3:
```yaml
  # Models can be overridden per-agent. For simple specs, nob automatically
  # downgrades to haiku unless you set a model explicitly here.
```

---

## Error handling additions

| Scenario | Behaviour |
|----------|-----------|
| Pre-flight fails (H3) | Print specific error, exit immediately |
| `gh pr create` fails (M1) | Print error output, fall back to git push command |
| `.nob/project-memory.md` unreadable (L1) | Skip memory injection silently; note in terminal summary |
| `PushNotification` tool unavailable (L2) | Skip silently |
| Run log write fails (H2) | Skip silently; do not block pipeline |
| PLAN_OUTPUT missing Complexity fields (L3) | Default to no override (treat as if complex) |

---

## Acceptance criteria

- [ ] H1: `agents.max_tokens_per_run` field parsed from `.nob.yml`; fan-out budget warning fires when set and estimated units exceed limit; terminal summary includes `Agents:` line with model per agent.
- [ ] H2: checkpoint.json gains `run_start_time` and `agents{}` fields; `.nob/run-<run-id>.log` created at Phase 1 and appended after each agent; terminal summary includes `Timing:` line.
- [ ] H3: Step 1.5 added for Spec→Code and Bug→Fix; four specific error messages printed and exit on failure; no agents dispatched on invalid spec.
- [ ] M1: After PASS worktree teardown, hub checks `gh --version`; if available runs `gh pr create` and prints URL; if not, prints git push command.
- [ ] M3: `--plan-only` detected before Step 1; runs only Planner; prints PLAN_OUTPUT; exits without dispatching other agents.
- [ ] L1: `.nob/project-memory.md` read at Step 1 and injected into all agent `[INPUTS]`; on PASS, hub appends run summary to memory file.
- [ ] L2: `PushNotification` called at end of Step 4 with workflow, spec name, and status; skipped silently if tool unavailable.
- [ ] L3: After PLAN_OUTPUT extraction, backend-agent and frontend-agent models overridden to haiku when complexity is `simple` and no explicit `.nob.yml` override exists; override reflected in H1 terminal summary.
