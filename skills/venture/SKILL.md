---
name: venture
description: End-to-end venture validation pipeline. Clarifies the idea, researches the market, designs the business model, builds GTM strategy and financial projection, and validates all artifacts. Invocable via `/nob:venture` or through the Nob hub.
---

# Nob — Venture Pipeline

## Overview
Run the complete venture validation pipeline in one agent. Guide the founder through idea framing, market research, business modeling, GTM strategy, and financial projection. Produce a validated venture spec ready for technical implementation.

## Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided. Do not prompt the user for inputs.
- **Standalone mode** (`[INPUTS]` absent): use the current working directory and the user's message as the venture idea.

## Setup

Read from `[INPUTS]` (or use defaults for standalone):
- `Working directory` → WORKING_DIR
- `Venture idea` → VENTURE_IDEA
- `Checkpoint path` → CHECKPOINT_PATH (default: `.nob/`)
- `Checkpoint enabled` → CHECKPOINT_ENABLED (default: true)

Run `mkdir -p docs/venture`.

If CHECKPOINT_ENABLED is true:
- Run `mkdir -p {CHECKPOINT_PATH}`
- Ensure `.nob/` appears in `.gitignore` at the repo root. If absent, append it.
- Read `{CHECKPOINT_PATH}venture-checkpoint.json`. Store as VENTURE_CHECKPOINT (null if missing/unparseable).
- For each stage: if VENTURE_CHECKPOINT has `stages.[stage-name].status: "completed"`, restore its stored output and skip re-running that stage.

If CHECKPOINT_ENABLED is false: set VENTURE_CHECKPOINT = null. Skip all checkpoint writes.

**Checkpoint write helper** (after each stage, if CHECKPOINT_ENABLED is true): read `{CHECKPOINT_PATH}venture-checkpoint.json` (or start with `{}`), update `stages.[stage-name]` to `{status: "completed", output: "[stage output]"}`, write back.

---

## Stage 1: Idea Framing

Skip this stage if checkpoint shows `stages.idea-framer.status: "completed"` — restore stored output.

### Step 1: Ask clarifying questions
Ask up to 5 questions to understand:
1. What specific problem does this solve? For whom?
2. Who is the primary target user? (role, context, pain point)
3. What is the proposed solution in one sentence?
4. What makes this different from existing solutions?
5. Is this a tech product, physical product, or service?

Wait for the user's answers before proceeding. You may ask them in one batch.

### Step 2: Confirm framing
Write a 3-paragraph summary covering problem statement, target user persona, and solution hypothesis. Present it:

> "Here's how I'd frame your idea: [summary]. Does this capture it accurately, or should I adjust before research begins?"

Wait for confirmation. If the user requests adjustments, revise and re-present.

### Step 3: Write idea-frame.md

Write `docs/venture/idea-frame.md`:

```markdown
# Idea Frame

## Problem Statement
[specific problem, who experiences it, current pain]

## Target User Persona
[role, context, key pain point, current workaround]

## Solution Hypothesis
[proposed solution in 2-3 sentences]

## Differentiation
[what makes this different from existing solutions]

## Summary
[2-paragraph narrative suitable for sharing with co-founders or investors]

## Action Plan
- [ ] Validate problem with 5 target users through 15-min interviews
- [ ] Identify 3 existing alternatives and document their gaps
- [ ] Write a one-page problem statement to share with advisors
```

Store: PROBLEM = [one-sentence problem statement], TARGET_USER = [one-sentence persona], SOLUTION = [one-sentence hypothesis].

Write checkpoint for `idea-framer`.

---

## Stage 2: Market Research

Skip this stage if checkpoint shows `stages.market-researcher.status: "completed"` — restore stored output.

### Step 1: Research market size
Use WebSearch for queries like:
- "[problem domain] market size [current year]"
- "[industry] total addressable market"

Capture TAM (global), SAM (reachable segment), SOM (realistic year 1–3 capture).

### Step 2: Research competitors
Search for 4–6 existing solutions. For each capture: name, positioning, target user, pricing model, key strengths, key weaknesses, recent funding or news.

### Step 3: Research trends and gaps
Search for growth trends, underserved segments, and technology or regulatory shifts creating opportunity.

### Step 4: Assess market health
- **Too small**: TAM < $100M → flag: "⚠ Market appears small (TAM: $X). Validate before proceeding."
- **Too crowded**: 5+ funded competitors with similar positioning → flag: "⚠ Market appears crowded. Verify differentiation before proceeding."
- Otherwise: no flag.

Print findings summary and any flag.

### Step 5: Write market-research.md

Write `docs/venture/market-research.md`:

```markdown
# Market Research

## Market Size
- TAM: [$ estimate with source]
- SAM: [$ estimate with rationale]
- SOM (Year 1–3): [$ estimate with rationale]

## Competitor Matrix
| Competitor | Target User | Pricing | Strengths | Weaknesses |
|---|---|---|---|---|

## Trends & Opportunity Gaps
[2-3 paragraphs on trends, emerging needs, and gaps this idea can fill]

## Market Health Assessment
[VIABLE / SMALL / CROWDED] — [one-sentence rationale]

## Summary
[2-paragraph narrative of market opportunity, suitable for sharing with investors]

## Action Plan
- [ ] Validate TAM estimate with an industry analyst report
- [ ] Interview 2–3 competitors' customers to understand switching willingness
- [ ] Track top 3 competitors' product updates for 30 days
```

Store: TAM, KEY_COMPETITORS, MARKET_HEALTH, MARKET_FLAG (or "none").

Write checkpoint for `market-researcher`.

---

## Stage 3: Business Modeling

Skip this stage if checkpoint shows `stages.business-modeler.status: "completed"` — restore stored output.

### Step 1: Propose revenue models and pause (hard pause)
Based on the idea and market research, propose 2–3 revenue model options. For each include:
- Model name (e.g., SaaS subscription, marketplace commission, freemium, usage-based, one-time license)
- Why it fits this idea and target user
- Typical unit economics: ARPU estimate, CAC estimate, payback period
- Key trade-offs (pros and cons)

Present as a numbered list and ask:
> "Which revenue model fits your vision?"

Wait for the founder's choice. Store as CHOSEN_MODEL.

### Step 2: Build value proposition canvas
Define:
- **Customer jobs**: what the user is trying to accomplish
- **Pains**: frustrations with current solutions
- **Gains**: desired outcomes
- **Products/services**: what this solution offers
- **Pain relievers**: how it addresses the pains
- **Gain creators**: how it delivers desired outcomes

### Step 3: Define key assumptions
List 5–7 measurable assumptions the business model depends on. Include quantified estimates (e.g., "Monthly churn rate: 3–5%", "Average contract value: $200/mo").

### Step 4: Write business-model.md

Write `docs/venture/business-model.md`:

```markdown
# Business Model

## Chosen Revenue Model
[model name and description]

## Value Proposition Canvas

### Customer Profile
- Jobs: [list]
- Pains: [list]
- Gains: [list]

### Value Map
- Products/Services: [list]
- Pain Relievers: [list]
- Gain Creators: [list]

## Key Assumptions
1. [assumption — quantified]
2–7. [...]

## Summary
[2-paragraph narrative of the business model and why it fits this opportunity]

## Action Plan
- [ ] Run a pricing survey with 10 target users to validate price sensitivity
- [ ] Model 3 scenarios (pessimistic / base / optimistic) for year-1 revenue
- [ ] Identify 2–3 early design partners willing to pay before launch
```

Store: REVENUE_MODEL = [chosen model name], KEY_ASSUMPTIONS = [top 3, comma-separated].

Write checkpoint for `business-modeler`.

---

## Stage 4: GTM Strategy

Skip this stage if checkpoint shows `stages.gtm-strategist.status: "completed"` — restore stored output.

### Step 1: Propose channels and pause (hard pause)
Based on the idea, target user, and revenue model, propose 4–6 distribution channels. For each include:
- Channel name (e.g., content marketing, paid social, cold outbound, partnerships, PLG, community, app stores)
- Why it fits this idea and target user
- Effort to test (low / medium / high), Time to first signal (in weeks), Cost to test

Ask:
> "Which 1–2 channels should I prioritize for your launch plan?"

Wait for selection. Store as PRIORITY_CHANNELS.

Note if founder selects 3+ channels: "3+ channels is a common early-stage mistake — recommend focusing on 1–2 for the first 90 days." Proceed with their selection.

### Step 2: Define ideal customer profile (ICP)
Cover: company type or individual demographic, role/decision-maker, trigger (what causes them to look for a solution right now), buying process (how they discover, evaluate, and decide).

### Step 3: Design 30/60/90 day launch sequence
- **Pre-launch (0–30 days)**: validation, waitlist, early adopters
- **Launch (30–60 days)**: first paying customers, initial traction
- **Growth (60–90 days)**: channel optimization, referral loops, retention

### Step 4: Define key metrics
- North Star Metric: the single number that proves the product is working
- Week 4 target: specific, measurable milestone
- Month 3 target: specific, measurable milestone

### Step 5: Write gtm-strategy.md

Write `docs/venture/gtm-strategy.md`:

```markdown
# GTM Strategy

## Ideal Customer Profile
[specific description — role, context, trigger, buying process]

## Priority Channels
1. [channel] — [why, time to signal, cost]
2. [channel] — [why, time to signal, cost]

## Launch Sequence

### Pre-Launch (0–30 days)
- [ ] [specific tactic]

### Launch (30–60 days)
- [ ] [specific tactic]

### Growth (60–90 days)
- [ ] [specific tactic]

## Key Metrics
- North Star Metric: [metric]
- Week 4 target: [specific number]
- Month 3 target: [specific number]

## Summary
[2-paragraph GTM narrative suitable for sharing with advisors or investors]

## Action Plan
- [ ] Identify 20 ICP prospects and reach out within 2 weeks
- [ ] Set up analytics tracking before driving any traffic
- [ ] Define a single call-to-action for the first channel test
```

Store: PRIORITY_CHANNELS_STR, ICP_SUMMARY, NORTH_STAR_METRIC, MONTH_3_TARGET.

Write checkpoint for `gtm-strategist`.

---

## Stage 5: Financial Modeling

Skip this stage if checkpoint shows `stages.financial-modeler.status: "completed"` — restore stored output.

### Step 1: Build monthly projection
Model months 1–12. Revenue formula by model type:
- **SaaS subscription**: cumulative new customers × ARPU (MRR)
- **Marketplace**: GMV × commission rate
- **One-time license**: units sold per month × price
- **Freemium**: free users × conversion rate × ARPU
- **Usage-based**: active users × average usage × unit price

For costs, split into:
- Fixed: team (salaries/contractors), infrastructure, tooling
- Variable: CAC (marketing spend ÷ new customers), support, transaction fees

Calculate per month: Revenue, Costs, Net (Revenue − Costs), Cumulative Net.

### Step 2: Calculate break-even
Find the month where Cumulative Net turns positive. If not within 12 months, flag:
> "⚠ Break-even not reached in year 1 — review cost structure or revenue assumptions."

### Step 3: Surface top assumptions
Identify the 3 assumptions that most affect the projection (e.g., monthly growth rate, churn rate, average deal size). Present them:

> "These 3 assumptions drive most of the projection — do they look reasonable? (No response needed to continue.)"

Continue without waiting for a response.

### Step 4: Write financial-model.md

Write `docs/venture/financial-model.md`:

```markdown
# Financial Model

## Key Assumptions
| Assumption | Value | Sensitivity |
|---|---|---|
| [assumption] | [value] | High / Medium / Low |

## 12-Month Projection (Base Case)
| Month | New Customers | Revenue | Costs | Net | Cumulative |
|---|---|---|---|---|---|
| 1 | [n] | $[x] | $[y] | $[z] | $[total] |
| ... | | | | | |
| 12 | [n] | $[x] | $[y] | $[z] | $[total] |

## Break-Even
Month [N] — [one-sentence explanation]

## Scenarios
- **Pessimistic** (50% of base growth rate): break-even Month [N, or: not in year 1]
- **Base**: break-even Month [N]
- **Optimistic** (150% of base growth rate): break-even Month [N]

## Summary
[2-paragraph narrative of financial outlook, highlighting break-even timeline and key risks]

## Action Plan
- [ ] Validate ARPU/pricing assumption with 5 prospect conversations
- [ ] Identify the largest cost line and find 2 ways to reduce it
- [ ] Model runway: what if Month 1 revenue is $0?
```

Store: BREAK_EVEN_MONTH, TOP_ASSUMPTION, FINANCIAL_FLAG (or "none").

If FINANCIAL_FLAG is not "none", print the flag message. Print: "Financial modeling complete. Running venture review..."

Write checkpoint for `financial-modeler`.

---

## Stage 6: Venture Review

Skip this stage if checkpoint shows `stages.venture-reviewer.status: "completed"` — restore stored output.

### Step 1: Verify all artifact files
Read each file and verify it exists and has content in all sections with no `[TBD]`, `[DATA NOT FOUND]`, or `[NEEDS INPUT]` placeholders:
- `docs/venture/idea-frame.md`
- `docs/venture/market-research.md`
- `docs/venture/business-model.md`
- `docs/venture/gtm-strategy.md`
- `docs/venture/financial-model.md`

### Step 2: Check cross-document consistency
Verify:
- Business model target user matches idea-frame persona
- GTM ICP matches idea-frame target user and business model customer profile
- Financial model revenue formula matches business model's chosen revenue model
- Financial model assumptions are grounded in market research figures (TAM/SAM)
- GTM North Star Metric aligns with the chosen revenue model (e.g., SaaS → MRR, marketplace → GMV)

Flag each inconsistency.

### Step 3: Check assumption quality
Review the top 3 financial assumptions. Flag any that are:
- Not grounded in market research (invented figures)
- Unusually optimistic (>20% monthly growth rate in month 1)
- Missing (placeholder value)

### Step 4: Determine status
- **PASS**: all artifacts exist, no critical gaps, no contradictions
- **NEEDS WORK**: minor gaps or weak assumptions, no blocking contradictions — venture spec is still written
- **FAIL**: one or more artifacts missing, or a fundamental contradiction that invalidates the model

Store STATUS, ISSUES (list of specific issues, or "none").

### Step 5: Write venture-spec.md (on PASS or NEEDS WORK)

Write `docs/venture/venture-spec.md`:

```markdown
# Venture Spec

## Idea
[problem and solution from idea-frame.md]

## Target User
[persona from idea-frame.md]

## Market
[TAM/SAM/SOM and market health from market-research.md]

## Business Model
[chosen revenue model and key assumptions from business-model.md]

## GTM
[priority channels and ICP from gtm-strategy.md]

## Financial Outlook
[break-even month and top assumption from financial-model.md]

## Acceptance Criteria
- [ ] Product solves the stated problem for the target persona
- [ ] Revenue model is implemented and testable in MVP
- [ ] GTM tracking is in place for priority channels
- [ ] Financial model assumptions are testable via product instrumentation

## Implementation Notes
Problem to solve: [one-line from idea-frame.md]
Target user: [one-line persona]
Revenue model: [one-line chosen model]
MVP scope: [2-3 sentences on what the minimum viable product must do]
```

Set NEEDS_DEV = true if the solution requires software. Set NEEDS_DEV = false for non-tech businesses (retail, consulting, physical product, service business).

Write checkpoint for `venture-reviewer`.

---

## Dev Pipeline Handoff

If STATUS is FAIL:
- Print each item from ISSUES. Jump to terminal summary.

If NEEDS_DEV is false:
- Print: "No technical implementation needed for this venture type." Jump to terminal summary.

If NEEDS_DEV is true and STATUS is PASS or NEEDS WORK:
- Print: "Venture pipeline complete. Artifacts saved to `docs/venture/`. Ready to move into technical implementation? (yes / not yet)"
- Wait for response.
- If **yes**: print "Run `/nob docs/venture/venture-spec.md` to start technical implementation."
- Jump to terminal summary.

---

## Terminal Summary

Emit exactly:

```
[VENTURE OUTPUT]
─────────────────────────────────────
  Nob Venture Pipeline — Complete
─────────────────────────────────────

Idea: {PROBLEM}

Stage results:
  Idea Frame       ✓  docs/venture/idea-frame.md
  Market Research  ✓  docs/venture/market-research.md
  Business Model   ✓  docs/venture/business-model.md
  GTM Strategy     ✓  docs/venture/gtm-strategy.md
  Financial Model  ✓  docs/venture/financial-model.md
  Venture Review   {STATUS}

Venture Spec: docs/venture/venture-spec.md
{if NEEDS_DEV is false → "No technical implementation needed."}
{if STATUS is FAIL → "Critical issues found — see above before continuing."}

Checkpoint: {CHECKPOINT_PATH}venture-checkpoint.json
When done: rm {CHECKPOINT_PATH}venture-checkpoint.json
─────────────────────────────────────
[/VENTURE OUTPUT]
```

## Error Handling
- **WebSearch unavailable**: note "WebSearch unavailable — estimates based on general knowledge only." Mark all figures as `[ESTIMATE — NOT VERIFIED]`.
- **No reliable data found**: document gaps explicitly with `[DATA NOT FOUND]` — do not fabricate figures.
- **Idea too vague after 5 questions**: proceed with what you have; add to output: `Flag: Idea requires further clarification — recommend founder workshop before continuing`.
- **Founder's choice is ambiguous**: ask one follow-up clarifying question before proceeding.
- **Checkpoint file corrupted/unparseable**: start fresh, note "venture checkpoint corrupted — fresh run".
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing.
- **Artifact file missing in Stage 6**: mark that artifact ✗ and set STATUS to FAIL.
