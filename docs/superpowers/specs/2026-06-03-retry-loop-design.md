# Retry Loop — Design Spec

**Date:** 2026-06-03
**Branch:** nob/2026-06-02-ideation-agent-design
**Approach:** Hub-centric retry loop (Approach A)

## Overview

Nob currently allows exactly one targeted retry pass after a FAIL or NEEDS REVIEW result. If that retry still fails, the run stops and the human must intervene. This spec replaces the single-pass Phase 3.5 with a configurable retry loop: the first pass is automatic, subsequent passes are user-gated, and a stuck-detection check stops the loop early if the same failures appear in two consecutive rounds.

---

## What Changes

| File | Change |
|---|---|
| `skills/nob/SKILL.md` | Step 1: extract `agents.max_retries` (default 3) |
| `skills/nob/SKILL.md` | Phase 3.5: replace single-pass with retry loop |
| `skills/nob/SKILL.md` | Step 4 terminal summary: update `Retry:` line |
| `skills/nob/templates/.nob.yml.template` | Add `agents.max_retries: 3` |

No sub-skill changes. No new files.

---

## Step 1 Config Extraction (addition)

Add one extraction line after the existing `max_tokens_per_run` extraction:

```
Extract agents.max_retries from RESOLVED_CONFIG. Default to 3 if absent. Store as MAX_RETRIES.
```

---

## Phase 3.5: Retry Loop (full replacement)

Replace the entire current Phase 3.5 section with the following:

```
## Phase 3.5: Retry loop

Initialize: RETRY_COUNT = 0. PREV_RETRY_ITEMS = []. RETRY_RAN = false.

--- Loop start ---

Read `Overall status:` from REVIEWER_OUTPUT.

If `Overall status: PASS`: exit loop. Proceed to Step 4.

Collect RETRY_ITEMS = all `✗` criterion lines + all `⚠` criterion lines + all CONTRACT VIOLATION lines from REVIEWER_OUTPUT.

**Stuck check** (skip on first iteration):
If RETRY_COUNT > 0 AND RETRY_ITEMS is identical to PREV_RETRY_ITEMS:
  Print:
    "Retry stuck — same N failure(s) appeared in two consecutive passes:
       [RETRY_ITEMS listed one per line]
     Human review required before continuing."
  Set RETRY_RAN = true.
  Exit loop. Proceed to Step 4.

**Max retries check:**
If RETRY_COUNT >= MAX_RETRIES:
  Print:
    "Max retries (MAX_RETRIES) reached. Human review required."
  Set RETRY_RAN = true.
  Exit loop. Proceed to Step 4.

**Determine which agents to re-dispatch** (unchanged logic from prior Phase 3.5):
- `Test results: Backend: FAIL` → RETRY_BACKEND = true
- `Test results: Frontend: FAIL` → RETRY_FRONTEND = true
- For each `✗` or `⚠` criterion line: cross-reference against PM_OUTPUT's `Backend changes needed:` and `Frontend changes needed:`
  - Found in `Backend changes needed:` → RETRY_BACKEND = true
  - Found in `Frontend changes needed:` → RETRY_FRONTEND = true
  - Found in both → set both to true
- Any CONTRACT VIOLATION → RETRY_FRONTEND = true; set CONTRACT_RETRY = true

If RETRY_BACKEND and RETRY_FRONTEND are both false:
  No agent can auto-fix the remaining items. Exit loop. Proceed to Step 4.

**User gate:**
If RETRY_COUNT == 0:
  Print:
    "Reviewer found N item(s) — auto-fixing (pass 1/MAX_RETRIES):
       [RETRY_ITEMS listed one per line]"
  (No user prompt — proceed automatically.)
Else:
  Print:
    "Still failing after pass RETRY_COUNT/MAX_RETRIES:
       [RETRY_ITEMS listed one per line]
     Retry again? (yes / no)"
  Wait for user response.
  If `no` or any non-yes response: exit loop. Proceed to Step 4.

Set PREV_RETRY_ITEMS = RETRY_ITEMS.
Set RETRY_RAN = true.

**Dispatch retry agents** (unchanged prompt structure from prior Phase 3.5):

Dispatch backend and frontend retry agents concurrently in the same assistant turn
(only agents with RETRY_BACKEND = true or RETRY_FRONTEND = true).

Backend retry prompt [INPUTS] block:
  Working directory, .nob.yml, CLAUDE.md, PM_OUTPUT,
  "Reviewer found these failures — fix only these items: {RETRY_ITEMS filtered to backend}"
  {if clarifications: "Clarifications from user: {answers}"}

Frontend retry prompt [INPUTS] block:
  Working directory, .nob.yml, CLAUDE.md, PM_OUTPUT,
  {if CONTRACT_RETRY: "Backend Agent output: {BACKEND_OUTPUT}"}
  "Reviewer found these failures — fix only these items: {RETRY_ITEMS filtered to frontend}"
  {if clarifications: "Clarifications from user: {answers}"}

Extract updated BACKEND_OUTPUT and/or FRONTEND_OUTPUT. Replace prior values.

**Re-run Reviewer** using the same Phase 3 prompt structure. Extract new REVIEWER_OUTPUT.

**Update checkpoint** (if checkpoint.enabled): read checkpoint.json, update `reviewer_output` to new REVIEWER_OUTPUT, write back.

Increment RETRY_COUNT by 1.

Go to Loop start.

--- Loop end ---

**Fan-out mode:** REVIEWER_OUTPUT covers all slices in one combined block. When retry is triggered, re-dispatch all slices as a new batch (same structure as Phase 2 fan-out). After slices complete, merge outputs and re-run Reviewer. Increment RETRY_COUNT. Continue loop.

Note: the Security Agent is not re-dispatched during any retry pass. SECURITY_OUTPUT from Phase 2.5 carries through unchanged.
```

---

## Terminal Summary (updated Retry line)

Replace the existing `Retry:` line in Step 4's terminal summary with:

```
Retry:     [one of the following:]
           N pass(es) → Final review: [Overall status from final REVIEWER_OUTPUT]
           stuck after N pass(es) — same failures in 2 consecutive rounds
           max retries (N) reached
           skipped — no fixable agents
           skipped — user declined
```

---

## .nob.yml Template (addition)

Add under `agents:`, after `max_tokens_per_run`:

```yaml
  max_retries: 3    # max retry passes (1 automatic + user-gated after that; default: 3)
```

---

## Behavior Summary

| Scenario | Behavior |
|---|---|
| PASS on first review | No retry loop entered |
| FAIL/NEEDS REVIEW, first retry | Automatic — no user prompt |
| FAIL/NEEDS REVIEW, 2nd+ retry | User-gated — ask before each pass |
| Same failures two passes in a row | Stop early — "stuck" message |
| RETRY_COUNT reaches MAX_RETRIES | Stop — "max retries" message |
| No backend/frontend failures fixable | Stop — no dispatch |
| User says no at user-gate | Stop — "user declined" |

Default `max_retries: 3` gives: 1 automatic + up to 2 user-gated passes.

---

## Acceptance Criteria

- First retry pass runs automatically with no user prompt, printing the failing items and `(pass 1/N)`
- Second and subsequent retry passes print the failing items and ask `"Retry again? (yes / no)"` before dispatching
- User answering `no` stops the loop and proceeds to Step 4
- If RETRY_ITEMS is identical to PREV_RETRY_ITEMS in two consecutive passes, the loop stops with a "stuck" message
- If RETRY_COUNT reaches MAX_RETRIES, the loop stops with a "max retries" message
- `agents.max_retries` is read from `.nob.yml` in Step 1; defaults to 3 if absent
- The `.nob.yml` template includes `max_retries: 3` with a comment
- The Security Agent is never re-dispatched during retry passes
- The terminal summary `Retry:` line reflects the actual outcome (N passes, stuck, max reached, skipped)
- Fan-out mode respects the same loop logic per retry round
- No sub-skill files are changed
