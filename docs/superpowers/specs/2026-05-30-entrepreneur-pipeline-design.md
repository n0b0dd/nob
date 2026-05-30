# Entrepreneur Pipeline — Design Spec

**Date:** 2026-05-30
**Status:** Approved

---

## Overview

Expand the Nob hub to support entrepreneurs bringing ideas to life — covering business validation, market research, business modeling, go-to-market strategy, and financial modeling — before optionally handing off to the existing technical dev pipeline. The entrepreneur workflow is triggered automatically when `/nob` detects a raw business idea rather than a spec or bug report.

---

## Section 1: Workflow Detection & Entry Point

The Nob hub adds `Venture` as a new first-class workflow type, slotted alongside `Init`, `feature`, and `bug` in the Step 2 detection logic.

**Detection heuristics** — input is classified as `Venture` when:
- No file path or spec reference is present
- Intent contains idea-framing language: "I want to build", "I have an idea", "bring to market", "startup", "business idea", "validate my idea", "launch a"
- Explicitly typed as `nob venture [idea]`

When `Venture` is detected, the hub skips the dev pipeline and enters the Venture workflow. After the Venture pipeline completes, it prompts: *"Ready to move into technical implementation?"* — if yes, it re-enters the hub using the Venture Spec as the spec input for the normal dev workflow.

**New `.nob.yml` config field:**
```yaml
agents:
  venture:
    enabled: true   # default true; set false to disable venture mode
```

---

## Section 2: The Venture Agent Pipeline

Six agents run in sequence. Each is a `SKILL.md` file under `skills/nob/`, following the same isolated Agent dispatch pattern as existing sub-agents.

```
Idea-Framer → Market-Researcher → Business-Modeler → GTM-Strategist → Financial-Modeler → Venture-Reviewer
                                                                                                    ↓
                                                                              (optional) Dev Pipeline
```

| Agent | Role | Primary Output |
|---|---|---|
| **Idea-Framer** | Clarifies problem, target user, and solution. Asks 3–5 focused questions. | `idea-frame.md` — problem statement, user persona, solution hypothesis |
| **Market-Researcher** | Autonomously researches market size, competitors, trends, and gaps using web search. Requires `WebSearch` and `WebFetch` tools — the only venture agent that reaches outside the local project. | `market-research.md` — TAM/SAM/SOM, competitor matrix, opportunity analysis |
| **Business-Modeler** | Proposes 2–3 revenue model options with trade-offs, pauses for founder choice. | `business-model.md` — chosen model, value prop canvas, key assumptions |
| **GTM-Strategist** | Designs go-to-market: channels, ICP, launch sequence, early traction tactics. Pauses on channel priority. | `gtm-strategy.md` — GTM doc + 30/60/90 day action plan |
| **Financial-Modeler** | Builds a 12-month projection from chosen business model and GTM assumptions. | `financial-model.md` — revenue/cost projections, break-even estimate |
| **Venture-Reviewer** | Validates all artifacts against the original idea. Flags gaps, contradictions, weak assumptions. | Pass/fail + gap list; assembles `venture-spec.md` on pass |

All artifacts are written to `docs/venture/` in the user's project.

---

## Section 3: Hybrid Decision Points

Three stages are **hard pauses** — the pipeline waits for founder input before continuing:

1. **After Idea-Framer** — Confirms the problem/solution framing before any research begins: *"Here's how I'd frame your idea: [summary]. Does this capture it accurately, or should I adjust before I start researching?"*

2. **Inside Business-Modeler** — After presenting 2–3 revenue model options with trade-offs, asks: *"Which revenue model fits your vision?"* The choice is locked as input for GTM and Financial agents.

3. **Inside GTM-Strategist** — After drafting channel options, asks: *"Which 1–2 channels should I prioritize for your launch plan?"* Prevents a generic strategy that spreads effort too thin.

Two stages are **soft reviews** — the pipeline surfaces key findings and continues unless the founder objects:

- **Market-Researcher** flags if the market appears too small or too crowded before moving on.
- **Financial-Modeler** surfaces its top 3 assumptions for a sanity check but does not block on response.

**Venture-Reviewer** runs fully autonomously — its role is audit, not collaboration.

---

## Section 4: Integration with the Dev Pipeline

The handoff is bridged by the **Venture Spec** (`docs/venture/venture-spec.md`), assembled by the Venture-Reviewer on a pass. It synthesizes all five agent outputs into the spec format the existing PM Agent expects — a structured requirements block — so the Planner → PM Agent → Backend + Frontend → QA → Reviewer chain runs unchanged.

**Handoff flow:**

1. Venture-Reviewer writes `venture-spec.md` and prompts: *"Venture pipeline complete. Artifacts saved to `docs/venture/`. Ready to move into technical implementation? (yes / not yet)"*
2. **Yes** → hub reads `venture-spec.md` as spec input, creates branch `nob/<idea-slug>`, and runs the normal dev workflow.
3. **Not yet** → pipeline exits cleanly. Founder can re-enter later with `nob docs/venture/venture-spec.md`.

**Non-tech ideas**: if the idea has no technical component, Venture-Reviewer sets `needs_dev: false` in the spec and the dev pipeline prompt is suppressed.

---

## Section 5: Output Artifacts

All artifacts are written to `docs/venture/` in the user's project:

```
docs/venture/
  idea-frame.md          — problem, persona, solution hypothesis
  market-research.md     — TAM/SAM/SOM, competitor matrix, opportunity gaps
  business-model.md      — chosen revenue model, value prop, key assumptions
  gtm-strategy.md        — channels, ICP, 30/60/90 day action plan
  financial-model.md     — 12-month projections, break-even, top assumptions
  venture-spec.md        — synthesized spec ready for dev pipeline (on pass)
```

Each document contains two sections:
- **Summary** — key finding or decision (2–3 paragraphs, shareable with co-founders or investors)
- **Action Plan** — concrete checklist of next steps the founder can execute independently

The hub prints a **Venture Summary** to the terminal after the pipeline completes — one paragraph per stage plus paths to all artifacts.

---

## New Files

```
skills/nob/idea-framer/SKILL.md
skills/nob/market-researcher/SKILL.md
skills/nob/business-modeler/SKILL.md
skills/nob/gtm-strategist/SKILL.md
skills/nob/financial-modeler/SKILL.md
skills/nob/venture-reviewer/SKILL.md
```

Updates to existing files:
- `skills/nob/SKILL.md` — add `Venture` workflow type detection and dispatch sequence
- `skills/nob/templates/.nob.yml.template` — add `agents.venture.enabled` field

---

## Checkpointing

The venture pipeline participates in the existing `.nob/checkpoint.json` system. The hub writes a checkpoint after each agent completes, recording the stage name and the path to its output artifact. If a run is interrupted, re-running `/nob` with the same idea detects the checkpoint and resumes from the last completed stage rather than starting over.

---

## Out of Scope

- Pitch deck generation (visual tooling not available in CLI)
- Fundraising CRM or investor outreach automation
- Multi-session memory across separate `/nob` runs (checkpoint system handles this within a run)
