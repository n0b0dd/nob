---
name: venture-workflow
description: Orchestrates the 6-stage Nob Venture pipeline. Dispatched by the Nob hub for Venture runs.
---

# Venture Workflow Orchestrator

## Setup

Read [INPUTS]:
- `Working directory` → WORKING_DIR
- `Skill base dir` → SKILL_BASE_DIR
- `Venture idea` → VENTURE_IDEA
- `Checkpoint path` → CHECKPOINT_PATH (default: `.nob/`)
- `Checkpoint enabled` → CHECKPOINT_ENABLED (default: true)
- `Agent models` → AGENT_MODELS (key→value pairs)

## Checkpoint setup

Run `mkdir -p docs/venture`.

If CHECKPOINT_ENABLED is true:
- Run `mkdir -p {CHECKPOINT_PATH}`
- Ensure `.nob/` in `.gitignore` at repo root. If absent, append it.
- Read `{CHECKPOINT_PATH}venture-checkpoint.json`. Store as VENTURE_CHECKPOINT (null if missing/unparseable).

If CHECKPOINT_ENABLED is false: set VENTURE_CHECKPOINT = null. Skip all checkpoint writes.

For each stage below: if VENTURE_CHECKPOINT has `stages.[stage-name].status: "completed"`, restore its output from `stages.[stage-name].output` and skip re-running it.

**Checkpoint write helper** (after each stage, if CHECKPOINT_ENABLED is true): Read `{CHECKPOINT_PATH}venture-checkpoint.json` (or start with `{}`), update only `stages.[stage-name]` to `{status: "completed", output: "[extracted block]"}`, write back.

---

## Stage 1: Idea-Framer

Read `{SKILL_BASE_DIR}/idea-framer/SKILL.md`. Dispatch with `model: {AGENT_MODELS["idea-framer"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/idea-framer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Idea: {VENTURE_IDEA}
[/INPUTS]
```

Extract `[IDEA-FRAMER OUTPUT]...[/IDEA-FRAMER OUTPUT]`. Store as IDEA_FRAMER_OUTPUT. Write checkpoint for `idea-framer`.

---

## Stage 2: Market-Researcher

Read `{SKILL_BASE_DIR}/market-researcher/SKILL.md`. Dispatch with `model: {AGENT_MODELS["market-researcher"] ?? "sonnet"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/market-researcher/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Idea frame: {IDEA_FRAMER_OUTPUT}
Problem: {Problem field from IDEA_FRAMER_OUTPUT}
[/INPUTS]
```

Extract `[MARKET-RESEARCHER OUTPUT]...[/MARKET-RESEARCHER OUTPUT]`. Store as MARKET_RESEARCHER_OUTPUT.

If `Flag:` in MARKET_RESEARCHER_OUTPUT is not `none`, print the flag message. Print: "Research complete. Continuing to business modeling..."

Write checkpoint for `market-researcher`.

---

## Stage 3: Business-Modeler

Read `{SKILL_BASE_DIR}/business-modeler/SKILL.md`. Dispatch with `model: {AGENT_MODELS["business-modeler"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/business-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Idea frame: {IDEA_FRAMER_OUTPUT}
Market research summary: {MARKET_RESEARCHER_OUTPUT}
Chosen revenue model:
[/INPUTS]
```

Note: `Chosen revenue model:` is left blank — the Business-Modeler agent will ask the founder directly.

Extract `[BUSINESS-MODELER OUTPUT]...[/BUSINESS-MODELER OUTPUT]`. Store as BUSINESS_MODELER_OUTPUT. Write checkpoint for `business-modeler`.

---

## Stage 4: GTM-Strategist

Read `{SKILL_BASE_DIR}/gtm-strategist/SKILL.md`. Dispatch with `model: {AGENT_MODELS["gtm-strategist"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/gtm-strategist/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Idea frame: {IDEA_FRAMER_OUTPUT}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Priority channels:
[/INPUTS]
```

Note: `Priority channels:` is left blank — the GTM-Strategist agent will ask the founder directly.

Extract `[GTM-STRATEGIST OUTPUT]...[/GTM-STRATEGIST OUTPUT]`. Store as GTM_OUTPUT. Write checkpoint for `gtm-strategist`.

---

## Stage 5: Financial-Modeler

Read `{SKILL_BASE_DIR}/financial-modeler/SKILL.md`. Dispatch with `model: {AGENT_MODELS["financial-modeler"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/financial-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Key assumptions: {Key assumptions field from BUSINESS_MODELER_OUTPUT}
North star metric: {North star metric field from GTM_OUTPUT}
Month 3 target: {Month 3 target field from GTM_OUTPUT}
[/INPUTS]
```

Extract `[FINANCIAL-MODELER OUTPUT]...[/FINANCIAL-MODELER OUTPUT]`. Store as FINANCIAL_OUTPUT.

If `Flag:` in FINANCIAL_OUTPUT is not `none`, print the flag message. Print: "Financial modeling complete. Running venture review..."

Write checkpoint for `financial-modeler`.

---

## Stage 6: Venture-Reviewer

Read `{SKILL_BASE_DIR}/venture-reviewer/SKILL.md`. Dispatch with `model: {AGENT_MODELS["venture-reviewer"] ?? "haiku"}`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/venture-reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {WORKING_DIR}
Idea framer output: {IDEA_FRAMER_OUTPUT}
Market researcher output: {MARKET_RESEARCHER_OUTPUT}
Business modeler output: {BUSINESS_MODELER_OUTPUT}
GTM strategist output: {GTM_OUTPUT}
Financial modeler output: {FINANCIAL_OUTPUT}
[/INPUTS]
```

Extract `[VENTURE-REVIEWER OUTPUT]...[/VENTURE-REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT. Write checkpoint for `venture-reviewer`.

---

## Dev pipeline handoff

Read `needs_dev:` and `Status:` from REVIEWER_OUTPUT.

If `Status: FAIL`:
- Print each item from the `Issues:` list. Jump to terminal summary.

If `needs_dev: false`:
- Print: "No technical implementation needed for this venture type." Jump to terminal summary.

If `needs_dev: true` and status is `PASS` or `NEEDS WORK`:
- Print: "Venture pipeline complete. Artifacts saved to `docs/venture/`. Ready to move into technical implementation? (yes / not yet)"
- Wait for response.
- If **yes**: Print "Run `/nob docs/venture/venture-spec.md` to start technical implementation."
- Jump to terminal summary.

---

## Terminal summary

Emit exactly:

```
[VENTURE OUTPUT]
─────────────────────────────────────
  Nob Venture Pipeline — Complete
─────────────────────────────────────

Idea: {Problem field from IDEA_FRAMER_OUTPUT}

Stage results:
  Idea Frame       ✓  docs/venture/idea-frame.md
  Market Research  ✓  docs/venture/market-research.md
  Business Model   ✓  docs/venture/business-model.md
  GTM Strategy     ✓  docs/venture/gtm-strategy.md
  Financial Model  ✓  docs/venture/financial-model.md
  Venture Review   {Status from REVIEWER_OUTPUT}

Venture Spec: docs/venture/venture-spec.md
{if needs_dev: false → "No technical implementation needed."}
{if Status: FAIL → "Critical issues found — see above before continuing."}

Checkpoint: {CHECKPOINT_PATH}venture-checkpoint.json
When done: rm {CHECKPOINT_PATH}venture-checkpoint.json
─────────────────────────────────────
[/VENTURE OUTPUT]
```
