# Retry Diagnostic — Design Spec

**Date:** 2026-06-03
**Branch:** nob/2026-06-02-ideation-agent-design
**Approach:** Haiku diagnostic step before retry dispatch

## Overview

When Phase 3.5 retry triggers, Nob currently re-dispatches the full Backend or Frontend agent (sonnet, 15-file budget) with a list of failing items but no guidance about which specific files need to change. The agent must re-read the codebase to figure out where to look, burning most of its 15-file budget on re-exploration rather than fixing.

This spec inserts a cheap haiku diagnostic step at the start of each retry pass. The diagnostic reads the failing items and the previously changed files, identifies the 2–5 files most likely to fix the failures, and outputs a scoped fix list. The retry agents then receive a tight `SCOPE: fix only these files` directive instead of the generic 15-file budget.

**Token economics:**
- Diagnostic cost per retry pass: ~1–2k tokens (haiku, reads 3–8 files)
- Retry agent savings: 15-file budget → 3–5 file budget ≈ 60–70% reduction per retry dispatch
- Break-even: diagnostic pays for itself on the first retry pass; saves significantly on 2nd+ passes

---

## What Changes

| File | Change |
|---|---|
| `skills/nob/SKILL.md` | Phase 3.5: insert diagnostic dispatch before retry agent dispatch |
| `skills/nob/SKILL.md` | Phase 3.5: pass `Fix scope:` from diagnostic into retry agent INPUTS |

No new sub-skill files. No new config keys. No changes to retry loop structure.

---

## Diagnostic Step (inserted in Phase 3.5, before retry agent dispatch)

Insert after the user gate (after "Set RETRY_RAN = true") and before the Backend/Frontend retry dispatch. Replace the existing **Backend retry** and **Frontend retry** dispatch section with:

```
**Retry diagnostic:**

Run `date +%s` and store as DIAG_START_EPOCH.

Read `{SKILL_BASE_DIR}/reviewer/SKILL.md`. Dispatch a sub-agent with `model: haiku` and
this prompt:

[INSTRUCTIONS]
You are a focused retry diagnostic agent. Your only job is to read a small set of files
and determine which specific files need to change to fix the listed failures. Do NOT
implement anything. Do NOT read any file not listed below.

Failing items to fix:
{RETRY_ITEMS listed one per line}

Files changed in the previous pass:
{all paths from BACKEND_OUTPUT "Files changed:" and "Files created:" if RETRY_BACKEND = true}
{all paths from FRONTEND_OUTPUT "Files changed:" and "Files created:" if RETRY_FRONTEND = true}

Read each of the files listed above. For each failing item, identify which 1–2 files
from the list above are most directly responsible for the failure. If a failing item is
a test failure, include both the source file and the test file.

Emit exactly this block:

[RETRY-DIAGNOSTIC OUTPUT]
Backend fix scope:
  - {path}: {one sentence: what specifically needs to change}
  (or: none — backend fix not needed)

Frontend fix scope:
  - {path}: {one sentence: what specifically needs to change}
  (or: none — frontend fix not needed)

Root cause summary: {1–2 sentences: why these files are the source of the failures}
[/RETRY-DIAGNOSTIC OUTPUT]
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

Failing items:
{RETRY_ITEMS listed one per line}

Backend files from previous pass:
{paths from BACKEND_OUTPUT "Files changed:" and "Files created:", or: none}

Frontend files from previous pass:
{paths from FRONTEND_OUTPUT "Files changed:" and "Files created:", or: none}
[/INPUTS]

Extract `[RETRY-DIAGNOSTIC OUTPUT]...[/RETRY-DIAGNOSTIC OUTPUT]`. Store as DIAG_OUTPUT.

If extraction fails: set DIAG_OUTPUT = null. Proceed with retry dispatch using the
standard 15-file scope (graceful fallback — diagnostic failure does not block the retry).

Run `date +%s` and store as DIAG_END_EPOCH. Append to RUN_LOG_PATH:
  {date -u +%FT%TZ}  retry-diagnostic  haiku  OK  {(DIAG_END_EPOCH - DIAG_START_EPOCH) × 1000}ms

**Parse fix scope from DIAG_OUTPUT:**

If DIAG_OUTPUT is non-null:
- Extract all paths under `Backend fix scope:` as BACKEND_FIX_SCOPE (empty list if "none")
- Extract all paths under `Frontend fix scope:` as FRONTEND_FIX_SCOPE (empty list if "none")
- If BACKEND_FIX_SCOPE is empty and RETRY_BACKEND = true: set BACKEND_FIX_SCOPE = null
  (fallback: retry agent uses standard scope)
- If FRONTEND_FIX_SCOPE is empty and RETRY_FRONTEND = true: set FRONTEND_FIX_SCOPE = null

If DIAG_OUTPUT is null:
- Set BACKEND_FIX_SCOPE = null
- Set FRONTEND_FIX_SCOPE = null

**Backend retry** (only if RETRY_BACKEND = true):

Read `{SKILL_BASE_DIR}/backend-agent/SKILL.md`. Dispatch with
`model: agents.models["backend-agent"] ?? "haiku"`:

[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/backend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Backend changes needed, plus backend test failures}

{if BACKEND_FIX_SCOPE is non-null:
SCOPE: Fix only these files — do not read or modify any other files:
{BACKEND_FIX_SCOPE listed one path per line}
Scope limit: {count of BACKEND_FIX_SCOPE} files maximum.
}
{if BACKEND_FIX_SCOPE is null:
SCOPE LIMIT: If completing this fix requires touching more than 5 files, implement
the highest-priority items first. Stop before reaching the limit. List any remaining
unimplemented work under Deferred items.
}

Root cause (from diagnostic):
{DIAG_OUTPUT "Root cause summary:" line, or: "Diagnostic not available — use your judgment"}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]

Extract `[BACKEND-AGENT OUTPUT]...[/BACKEND-AGENT OUTPUT]`. Replace BACKEND_OUTPUT with
this result.

**Frontend retry** (only if RETRY_FRONTEND = true):

Read `{SKILL_BASE_DIR}/frontend-agent/SKILL.md`. Dispatch with
`model: agents.models["frontend-agent"] ?? "haiku"`:

[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/frontend-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

.nob.yml contents:
{.nob.yml content}

CLAUDE.md contents:
{CLAUDE.md content, or: "CLAUDE.md not found"}

Requirements from PM Agent:
{PM_OUTPUT}

{if CONTRACT_RETRY = true:
Backend Agent output (use these API contracts as the authoritative source of truth):
{BACKEND_OUTPUT}
}

Reviewer found these failures — fix only these items:
{RETRY_ITEMS filtered to items found in Frontend changes needed, frontend test failures,
and contract violations}

{if FRONTEND_FIX_SCOPE is non-null:
SCOPE: Fix only these files — do not read or modify any other files:
{FRONTEND_FIX_SCOPE listed one path per line}
Scope limit: {count of FRONTEND_FIX_SCOPE} files maximum.
}
{if FRONTEND_FIX_SCOPE is null:
SCOPE LIMIT: If completing this fix requires touching more than 5 files, implement
the highest-priority items first. Stop before reaching the limit. List any remaining
unimplemented work under Deferred items.
}

Root cause (from diagnostic):
{DIAG_OUTPUT "Root cause summary:" line, or: "Diagnostic not available — use your judgment"}

{if planner had ambiguities and user answered: "Clarifications from user: {answers}"}
[/INPUTS]

Extract `[FRONTEND-AGENT OUTPUT]...[/FRONTEND-AGENT OUTPUT]`. Replace FRONTEND_OUTPUT
with this result.
```

---

## Fallback behaviour

The diagnostic is best-effort. If it fails (no output block extracted), the retry agents fall back to a tighter 5-file scope limit (reduced from the Phase 2 15-file limit). This ensures retries are always more focused than original implementation passes, even without diagnostic output.

| Diagnostic result | Retry agent scope |
|---|---|
| DIAG_OUTPUT with valid scope | Named files only (2–5 files) |
| DIAG_OUTPUT with empty scope for that layer | Fallback: 5-file limit |
| DIAG_OUTPUT = null (extraction failed) | Fallback: 5-file limit |

---

## Placement in Phase 3.5

The diagnostic slot fits between the existing user gate and the retry dispatches:

```
Loop start
  ↓ Overall status check
  ↓ RETRY_ITEMS collection
  ↓ Stuck check
  ↓ Max retries check
  ↓ Determine RETRY_BACKEND / RETRY_FRONTEND
  ↓ User gate (first pass: automatic; subsequent: ask)
  ↓ [NEW] Retry diagnostic dispatch (haiku)   ← inserted here
  ↓ Backend retry dispatch (conditional)
  ↓ Frontend retry dispatch (conditional)
  ↓ Reviewer re-dispatch
  ↓ Checkpoint write
  ↓ Increment RETRY_COUNT
Loop back
```

---

## Token estimates per retry pass

| Component | Model | Estimated tokens |
|---|---|---|
| Diagnostic dispatch | haiku | ~1–2k total |
| Backend retry (scoped, 3–5 files) | sonnet/haiku | ~15–25k (vs ~40–60k unscoped) |
| Frontend retry (scoped, 3–5 files) | sonnet/haiku | ~15–25k (vs ~40–60k unscoped) |
| **Net saving per retry pass** | | **~40–70k tokens** |

At 3 retry passes the saving is ~120–210k tokens — roughly the cost of one full implementation run.

---

## Acceptance Criteria

- On every retry pass, a haiku diagnostic agent is dispatched before the Backend or Frontend retry agents
- The diagnostic reads only the files listed in the previous pass's `Files changed:` and `Files created:` fields
- The diagnostic emits `[RETRY-DIAGNOSTIC OUTPUT]` with `Backend fix scope:`, `Frontend fix scope:`, and `Root cause summary:` fields
- If `[RETRY-DIAGNOSTIC OUTPUT]` is successfully extracted, the retry Backend/Frontend agents receive a `SCOPE: Fix only these files` directive listing the scoped paths
- If diagnostic extraction fails, the retry agents receive a 5-file scope limit (reduced from Phase 2's 15-file limit) — no retry is blocked by a diagnostic failure
- The diagnostic is logged to RUN_LOG_PATH with duration
- The root cause summary from the diagnostic is injected into the retry agent INPUTS
- Fan-out retry: diagnostic is dispatched once per slice before that slice's retry agents
- The diagnostic does not replace the Reviewer's contract check or test corroboration
- No new SKILL.md sub-skill files are created — the diagnostic runs inline in the hub
