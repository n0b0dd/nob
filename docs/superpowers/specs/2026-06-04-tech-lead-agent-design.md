# Tech Lead Agent — Pipeline Restructure Spec

**Date:** 2026-06-04  
**Status:** Draft  

---

## Problem

The current Nob pipeline splits technical orchestration awkwardly across two agents:

- **Planner** plans upfront then disappears — no mid-flight presence
- **Hub** coordinates mechanically — no technical judgment

Neither agent actively manages the dev team. When Backend or Frontend hits a blocker, the pipeline either halts for human input or silently proceeds with a bad assumption. There is no agent that holds technical authority end-to-end over the dev phase.

---

## Goal

Restructure the pipeline to match a real engineering team:

- **PM** owns product requirements — user stories, acceptance criteria, feature scope
- **Tech Lead** owns everything technical — architecture, contracts, sequencing, active dev team management, escalation decisions
- **Dev Team** (Backend + Frontend) implements under Tech Lead direction

---

## Pipeline Structure

**Before:**
```
Hub → Planner → PM → Backend + Frontend (parallel) → Security → Reviewer
```

**After:**
```
Hub → PM → Tech Lead → Security → Reviewer
               ↓↑ (active loop)
        Backend ‖ Frontend (parallel)
```

Hub becomes a thin chain. Planner is retired. Tech Lead is the active orchestrator of the dev phase.

---

## Agent Responsibilities

### PM Agent (narrowed)

**Owns:** Product requirements only.

**Produces:**
- User stories
- Acceptance criteria
- Feature scope and constraints
- Non-technical edge cases

**No longer produces:** API contracts, data schemas, or technical task breakdowns. Those move to Tech Lead.

---

### Tech Lead Agent (new)

**Owns:** Everything technical from spec to implementation completion.

**On receiving PM output:**
1. Reads PM product requirements
2. Writes API contracts and data schemas
3. Breaks requirements into per-layer technical tasks (Backend tasks, Frontend tasks)
4. Flags risks: `[AUTH]`, `[MIGRATION]`, `[BREAKING]`, `[SHARED]`
5. Determines run mode: single pipeline or fan-out slices
   - **Single:** dispatches one Backend + one Frontend concurrently
   - **Fan-out:** dispatches N parallel slice mini-pipelines (each a Backend + Frontend pair scoped to one slice); Tech Lead coordinates blockers across all slices and merges all slice outputs before releasing to Security
6. Dispatches Backend and Frontend concurrently

**Active loop (during implementation):**

```
Tech Lead dispatches Backend + Frontend in parallel

Loop until both emit [DONE]:
  - [BLOCKER] received →
      Technical decision (naming, schema, approach)  → Tech Lead resolves autonomously → agent resumes
      Spec ambiguity unresolvable from PM output      → escalate to human with proposed answer
      Cross-layer dependency                          → Tech Lead coordinates between agents
      Risk flag ([AUTH], [MIGRATION], [BREAKING])     → escalate to human with proposed resolution
  - [DONE] received → hold output, wait for other layer

When both [DONE]:
  - Merge Backend + Frontend outputs
  - Run cross-layer contract check (PM→Backend, PM→Frontend, Backend→Frontend)
  - Release merged output to Security
```

**Escalation policy:**
- Tech Lead resolves any blocker answerable from spec + technical context
- Escalates to human only when: (a) the decision requires product intent outside its authority, or (b) the risk flag is high ([AUTH], [BREAKING])
- Human receives one concise question with a proposed answer — approve or override
- After resolution, pipeline resumes without full restart

---

### Backend Agent (updated)

- Receives Tech Lead's technical spec (not PM output directly)
- Implements API endpoints, database layer, tests
- Runs in parallel with Frontend
- Emits `[BLOCKER]` with structured reason if blocked, or `[DONE]` with implementation output

---

### Frontend Agent (updated)

- Receives Tech Lead's technical spec
- Prioritizes Tech Lead's API contracts over any other source
- Implements UI, state management, API integration
- Runs in parallel with Backend
- Emits `[BLOCKER]` with structured reason if blocked, or `[DONE]` with implementation output

---

### Security Agent (unchanged)

Receives Tech Lead's merged and reviewed output. Reviews for security findings. Critical findings gate Reviewer.

---

### Reviewer Agent (unchanged)

Validates merged implementation against acceptance criteria from PM output and contracts from Tech Lead output. On FAIL, emits structured failure report to Hub. Hub re-invokes Tech Lead with the failure report; Tech Lead re-dispatches only the failing layer(s), runs the active loop again, and releases updated output to Security → Reviewer. Max 3 retries; stuck detection (same failures twice) escalates to human.

---

## Files Changed

| File | Change |
|---|---|
| `skills/planner/SKILL.md` | Retired — content merged into Tech Lead |
| `skills/nob/SKILL.md` | Slimmed — removes coordination logic, chains PM → Tech Lead → Security → Reviewer |
| `skills/pm/SKILL.md` | Narrowed — drops API contract and schema writing |
| `skills/backend/SKILL.md` | Updated — receives Tech Lead spec, emits `[BLOCKER]` or `[DONE]` |
| `skills/frontend/SKILL.md` | Updated — same as Backend |
| `skills/tech-lead/SKILL.md` | **New** — Tech Lead skill |
| `skills/nob/templates/.nob.yml.template` | Add `agents.tech_lead` model config field |
| `CLAUDE.md` | Update repo structure table and pipeline description |

---

## Blocker Output Format

Backend and Frontend agents emit blockers using this structured block:

```
[BLOCKER]
type: technical | ambiguity | cross-layer | risk
flag: AUTH | MIGRATION | BREAKING | SHARED | none
description: <one sentence>
proposed_resolution: <Tech Lead's proposed answer, if applicable>
blocking_layer: backend | frontend | both
[/BLOCKER]
```

Tech Lead reads this block and decides: resolve autonomously, coordinate, or escalate.

---

## .nob.yml Changes

```yaml
agents:
  tech_lead:
    model: claude-sonnet-4-6   # default
    enabled: true
```

---

## Success Criteria

- PM output contains zero technical artifacts (no contracts, no schemas)
- Tech Lead produces API contracts and data schemas before dispatching dev agents
- Backend and Frontend run in parallel throughout
- Blockers route to Tech Lead, not Hub, and do not halt the full pipeline
- Human is only interrupted for: spec ambiguity unresolvable from PM output, high-risk flags
- Planner skill is fully retired with no orphaned references
- All existing fan-out / slice-runner behavior preserved under Tech Lead coordination

---

## Out of Scope

- UI or CLI changes to how users invoke `/nob`
- Changes to Security or Reviewer agent logic
- Changes to checkpoint/resume behavior
- New model tiers or cost optimization
