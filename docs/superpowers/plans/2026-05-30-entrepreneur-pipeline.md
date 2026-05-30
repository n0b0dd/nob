# Entrepreneur Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Venture` workflow type to the Nob hub that takes a raw business idea through idea framing → market research → business modeling → GTM strategy → financial modeling → review, then optionally hands off to the existing dev pipeline.

**Architecture:** Six new SKILL.md agents run sequentially under a "Venture Workflow" section in the hub, following the same isolated Agent dispatch pattern as existing sub-agents. Three agents contain built-in hard pauses (founder confirms framing, chooses revenue model, chooses GTM channels). The hub handles checkpointing between stages and prints a Venture terminal summary on completion.

**Tech Stack:** Markdown skill files only — no build system, no test runner. Verification is done by re-reading each file and checking against a spec checklist.

---

## File Map

**New files:**
- `skills/nob/idea-framer/SKILL.md`
- `skills/nob/market-researcher/SKILL.md`
- `skills/nob/business-modeler/SKILL.md`
- `skills/nob/gtm-strategist/SKILL.md`
- `skills/nob/financial-modeler/SKILL.md`
- `skills/nob/venture-reviewer/SKILL.md`

**Modified files:**
- `skills/nob/SKILL.md` — four edits: (1) Step 2 detection table, (2) RESOLVED_CONFIG defaults, (3) Venture early exit routing + full Venture Workflow section, (4) Step 4 terminal summary
- `skills/nob/templates/.nob.yml.template` — add venture config fields

---

## Task 1: Add Venture to hub Step 2 detection table

**Files:**
- Modify: `skills/nob/SKILL.md` (Step 2 table, around line 113)

- [ ] **Step 1: Open the hub**

Read `skills/nob/SKILL.md` lines 108–125.

- [ ] **Step 2: Add Venture row to the detection table**

Find this block:
```
| "nob init", "initialize project", "scaffold project", "init" (standalone) | Init |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
```

Replace with:
```
| "nob init", "initialize project", "scaffold project", "init" (standalone) | Init |
| "I want to build", "I have an idea", "bring to market", "startup", "business idea", "validate my idea", "launch a", "nob venture" | Venture |

If the intent does not clearly match any workflow, ask ONE clarifying question before proceeding:
```

- [ ] **Step 3: Verify**

Re-read lines 108–130 of `skills/nob/SKILL.md`. Confirm:
- Venture row is present with all six trigger phrases
- Existing rows are unchanged
- Table formatting is consistent

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Venture to hub Step 2 detection table"
```

---

## Task 2: Add venture agent models to RESOLVED_CONFIG defaults

**Files:**
- Modify: `skills/nob/SKILL.md` (RESOLVED_CONFIG block, around line 80)

- [ ] **Step 1: Find the RESOLVED_CONFIG defaults block**

Locate the `agents.models` block that contains:
```yaml
    backend-agent: sonnet
    frontend-agent: sonnet
    planner: haiku
    pm-agent: haiku
    qa-agent: haiku
    reviewer: haiku
    init-agent: sonnet
```

- [ ] **Step 2: Add venture agent model entries**

Replace that block with:
```yaml
    backend-agent: sonnet
    frontend-agent: sonnet
    planner: haiku
    pm-agent: haiku
    qa-agent: haiku
    reviewer: haiku
    init-agent: sonnet
    idea-framer: haiku
    market-researcher: sonnet
    business-modeler: haiku
    gtm-strategist: haiku
    financial-modeler: haiku
    venture-reviewer: haiku
```

Note: market-researcher uses `sonnet` because it performs web search and synthesis. All others use `haiku`.

- [ ] **Step 3: Add venture.enabled to RESOLVED_CONFIG**

Find the `max_parallel_slices` line in the RESOLVED_CONFIG block:
```yaml
  max_parallel_slices: 3
  checkpoint:
```

Add venture config after `max_parallel_slices`:
```yaml
  max_parallel_slices: 3
  venture:
    enabled: true
  checkpoint:
```

- [ ] **Step 4: Verify**

Re-read the RESOLVED_CONFIG block. Confirm:
- All 6 venture agents have model entries
- `market-researcher` is `sonnet`, all others `haiku`
- `venture.enabled: true` is present

- [ ] **Step 5: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add venture agent models to hub RESOLVED_CONFIG defaults"
```

---

## Task 3: Add Venture early exit routing to hub

**Files:**
- Modify: `skills/nob/SKILL.md` (after Init early exit section, around line 145)

- [ ] **Step 1: Find the Init early exit section ending**

Locate this line in the hub:
```
- Jump directly to Step 4 (Print terminal summary) using the Init terminal summary format below.
```

- [ ] **Step 2: Add Venture early exit after Init early exit**

After the Init early exit section (after the line above), insert:

```markdown
## Venture workflow early exit

If the identified workflow is `Venture`:
- Read `agents.venture.enabled` from RESOLVED_CONFIG. Default to `true` if absent.
- If `false`: print "Venture mode is disabled in `.nob.yml`. Set `agents.venture.enabled: true` to enable." and exit.
- Skip Phase 0, Phase 1, Phase 2, and Phase 3 entirely.
- Jump directly to the **Venture Workflow** section below.
```

- [ ] **Step 3: Verify**

Re-read the section around Init and Venture early exits. Confirm:
- Venture early exit is placed after Init early exit
- `agents.venture.enabled` check is present with correct default
- Jump instruction points to the Venture Workflow section

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Venture workflow early exit routing to hub"
```

---

## Task 4: Write Idea-Framer SKILL.md

**Files:**
- Create: `skills/nob/idea-framer/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/idea-framer/SKILL.md` with this exact content:

```markdown
---
name: nob-idea-framer
description: First agent in the Venture pipeline. Clarifies the entrepreneur's idea by asking 3-5 focused questions about the problem, target user, and solution. Produces a structured idea frame as the foundation for all downstream research.
---

# Nob — Idea-Framer Agent

## Overview
You are the first agent in a Venture pipeline. Turn a raw idea into a crisp problem/solution frame. Ask focused questions, then write the idea frame document.

## Process

### Step 1: Read inputs
Read the `Idea:` field from your `[INPUTS]` block.

### Step 2: Ask clarifying questions
Ask up to 5 questions, one at a time, to understand:
1. What specific problem does this solve? For whom?
2. Who is the primary target user? (role, context, pain point)
3. What is the proposed solution in one sentence?
4. What makes this different from existing solutions?
5. Is this a tech product, physical product, or service?

Wait for the user's answers to all questions before proceeding to Step 3. You may ask them in one batch if preferred.

### Step 3: Confirm framing
Write a 3-paragraph summary covering problem statement, target user persona, and solution hypothesis. Present it to the user:

> "Here's how I'd frame your idea: [summary]. Does this capture it accurately, or should I adjust before research begins?"

Wait for confirmation. If the user requests adjustments, revise and re-present.

### Step 4: Write idea-frame.md
Once confirmed, create `docs/venture/` if it does not exist (`mkdir -p docs/venture`), then write `docs/venture/idea-frame.md`:

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

## Output Format

Return this exact block:

```
[IDEA-FRAMER OUTPUT]
Idea frame file: docs/venture/idea-frame.md
Problem: [one-sentence problem statement]
Target user: [one-sentence persona]
Solution: [one-sentence hypothesis]
Confirmed by founder: yes
[/IDEA-FRAMER OUTPUT]
```

## Error Handling
- **Idea too vague after 5 questions**: output what you have; add to the output block: `Flag: Idea requires further clarification — recommend founder workshop before continuing`
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-idea-framer`
- [ ] Asks 3–5 questions covering problem, target user, solution, differentiation
- [ ] Hard pause: presents framing and waits for confirmation
- [ ] Writes `docs/venture/idea-frame.md` with all required sections (Problem, Persona, Solution, Differentiation, Summary, Action Plan)
- [ ] Output block is `[IDEA-FRAMER OUTPUT]...[/IDEA-FRAMER OUTPUT]`
- [ ] Output block contains: file path, Problem, Target user, Solution, Confirmed fields
- [ ] Creates `docs/venture/` if missing

- [ ] **Step 3: Commit**

```bash
git add skills/nob/idea-framer/SKILL.md
git commit -m "feat: add idea-framer venture agent"
```

---

## Task 5: Write Market-Researcher SKILL.md

**Files:**
- Create: `skills/nob/market-researcher/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/market-researcher/SKILL.md`:

```markdown
---
name: nob-market-researcher
description: Second agent in the Venture pipeline. Autonomously researches market size, competitors, trends, and gaps using WebSearch and WebFetch. The only venture agent that reaches outside the local project. Flags small or crowded markets before continuing.
---

# Nob — Market-Researcher Agent

## Overview
Research the market for this idea autonomously. Use WebSearch and WebFetch to find real data. Produce a market research document and flag if the market looks too small or crowded.

## Process

### Step 1: Read inputs
Read `Idea frame:` and `Problem:` from your `[INPUTS]` block.

### Step 2: Research market size
Use WebSearch for queries like:
- "[problem domain] market size [current year]"
- "[industry] total addressable market"

Capture TAM (global market), SAM (reachable segment), SOM (realistic year 1–3 capture).

### Step 3: Research competitors
Search for 4–6 existing solutions. For each capture: name, positioning, target user, pricing model, key strengths, key weaknesses, recent funding or news.

Use queries like:
- "[solution type] competitors"
- "[problem domain] tools comparison [year]"
- "best [solution category] software"

### Step 4: Research trends and gaps
Search for:
- Growth trends and forecasts in this space
- Underserved segments or unmet needs
- Regulatory or technology shifts creating opportunity

### Step 5: Assess market health
After research, apply these thresholds:
- **Too small**: TAM < $100M → flag: "⚠ Market appears small (TAM: $X). Founder should validate before proceeding."
- **Too crowded**: 5+ funded competitors with similar positioning → flag: "⚠ Market appears crowded. Founder should verify differentiation before proceeding."
- Otherwise: no flag.

Present findings summary and flag (if any) to the user before writing the document.

### Step 6: Write market-research.md
Create `docs/venture/` if it does not exist, then write `docs/venture/market-research.md`:

```markdown
# Market Research

## Market Size
- TAM: [$ estimate with source]
- SAM: [$ estimate with rationale]
- SOM (Year 1–3): [$ estimate with rationale]

## Competitor Matrix
| Competitor | Target User | Pricing | Strengths | Weaknesses |
|---|---|---|---|---|
| [name] | [user] | [model] | [strengths] | [weaknesses] |

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

## Output Format

```
[MARKET-RESEARCHER OUTPUT]
Market research file: docs/venture/market-research.md
TAM: [$ figure]
Key competitors: [comma-separated names, max 5]
Market health: [VIABLE | SMALL | CROWDED]
Flag: [flag message, or: none]
[/MARKET-RESEARCHER OUTPUT]
```

## Error Handling
- **WebSearch unavailable**: note "WebSearch unavailable — estimates based on general knowledge only. Mark as [ESTIMATE — NOT VERIFIED]." Proceed and mark all figures clearly.
- **No reliable data found**: document gaps explicitly with "[DATA NOT FOUND]" rather than fabricating figures.
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing.
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-market-researcher`
- [ ] Uses WebSearch and WebFetch (noted as only agent reaching outside project)
- [ ] Researches TAM/SAM/SOM, competitors (4–6), trends and gaps
- [ ] Flags small market (TAM < $100M) and crowded market (5+ funded competitors)
- [ ] Soft review: presents findings to user before writing document
- [ ] Writes `docs/venture/market-research.md` with all sections (Market Size, Competitor Matrix, Trends, Health Assessment, Summary, Action Plan)
- [ ] Output block is `[MARKET-RESEARCHER OUTPUT]...[/MARKET-RESEARCHER OUTPUT]`
- [ ] Output block contains: file, TAM, competitors, market health, flag

- [ ] **Step 3: Commit**

```bash
git add skills/nob/market-researcher/SKILL.md
git commit -m "feat: add market-researcher venture agent"
```

---

## Task 6: Write Business-Modeler SKILL.md

**Files:**
- Create: `skills/nob/business-modeler/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/business-modeler/SKILL.md`:

```markdown
---
name: nob-business-modeler
description: Third agent in the Venture pipeline. Proposes 2-3 revenue model options with trade-offs, pauses for the founder's choice, then produces a business model document with value proposition canvas and key assumptions.
---

# Nob — Business-Modeler Agent

## Overview
Design the business model. Propose revenue model options based on the idea and market research, pause for the founder to choose, then document the chosen model in detail.

## Process

### Step 1: Read inputs
Read `Idea frame:`, `Market research summary:`, and `Chosen revenue model:` from `[INPUTS]`. If `Chosen revenue model:` is populated, skip Step 2 and proceed to Step 3.

### Step 2: Propose revenue models and pause (hard pause)
Based on the idea and market research, propose 2–3 revenue model options. For each include:
- Model name (e.g., SaaS subscription, marketplace commission, freemium, one-time license, usage-based)
- Why it fits this idea and target user
- Typical unit economics: ARPU estimate, CAC estimate, payback period
- Key trade-offs (pros and cons)

Present as a numbered list and ask:
> "Which revenue model fits your vision?"

Wait for the founder's choice before proceeding. Store the choice as CHOSEN_MODEL.

### Step 3: Build value proposition canvas
Based on CHOSEN_MODEL, define:
- **Customer jobs**: what the user is trying to accomplish
- **Pains**: frustrations with current solutions
- **Gains**: desired outcomes
- **Products/services**: what this solution offers
- **Pain relievers**: how it addresses the pains
- **Gain creators**: how it delivers desired outcomes

### Step 4: Define key assumptions
List 5–7 measurable assumptions the business model depends on. Include quantified estimates where possible (e.g., "Monthly churn rate: 3–5%", "Average contract value: $200/mo").

### Step 5: Write business-model.md
Create `docs/venture/` if it does not exist, then write `docs/venture/business-model.md`:

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
2. [assumption — quantified]
3. [assumption — quantified]
4. [assumption — quantified]
5. [assumption — quantified]

## Summary
[2-paragraph narrative of the business model and why it fits this opportunity]

## Action Plan
- [ ] Run a pricing survey with 10 target users to validate price sensitivity
- [ ] Model 3 scenarios (pessimistic / base / optimistic) for year-1 revenue
- [ ] Identify 2–3 early design partners willing to pay before launch
```

## Output Format

```
[BUSINESS-MODELER OUTPUT]
Business model file: docs/venture/business-model.md
Revenue model: [chosen model name]
Key assumptions: [top 3 assumptions, comma-separated]
[/BUSINESS-MODELER OUTPUT]
```

## Error Handling
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing.
- **Founder's choice is ambiguous**: ask one follow-up clarifying question before proceeding.
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-business-modeler`
- [ ] Checks `Chosen revenue model:` input and skips proposal step if already set
- [ ] Proposes 2–3 models with unit economics and trade-offs
- [ ] Hard pause: asks "Which revenue model fits your vision?" and waits for answer
- [ ] Builds value proposition canvas
- [ ] Lists 5–7 quantified assumptions
- [ ] Writes `docs/venture/business-model.md` with all sections
- [ ] Output block is `[BUSINESS-MODELER OUTPUT]...[/BUSINESS-MODELER OUTPUT]`

- [ ] **Step 3: Commit**

```bash
git add skills/nob/business-modeler/SKILL.md
git commit -m "feat: add business-modeler venture agent"
```

---

## Task 7: Write GTM-Strategist SKILL.md

**Files:**
- Create: `skills/nob/gtm-strategist/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/gtm-strategist/SKILL.md`:

```markdown
---
name: nob-gtm-strategist
description: Fourth agent in the Venture pipeline. Designs go-to-market strategy covering ICP, channels, launch sequence, and early traction tactics. Pauses for the founder to choose priority channels before drafting the full action plan.
---

# Nob — GTM-Strategist Agent

## Overview
Build the go-to-market strategy. Propose distribution channels, pause for the founder to choose, then produce a full GTM document with a 30/60/90 day action plan.

## Process

### Step 1: Read inputs
Read `Idea frame:`, `Revenue model:`, and `Priority channels:` from `[INPUTS]`. If `Priority channels:` is populated, skip Step 2 and proceed to Step 3.

### Step 2: Propose channels and pause (hard pause)
Based on the idea, target user, and revenue model, propose 4–6 distribution channels. For each include:
- Channel name (e.g., content marketing, paid social, cold outbound, partnerships, PLG, community, app stores)
- Why it fits this idea and target user
- Estimated effort to test (low / medium / high)
- Time to first signal (in weeks)
- Cost to test (free / low / medium / high)

Ask:
> "Which 1–2 channels should I prioritize for your launch plan?"

Wait for the founder's selection. Store as PRIORITY_CHANNELS.

### Step 3: Define ideal customer profile (ICP)
Write a specific ICP covering:
- Company type or individual demographic
- Role or decision-maker
- Trigger: what causes them to look for a solution right now
- Buying process: how they discover, evaluate, and decide

### Step 4: Design 30/60/90 day launch sequence

**Pre-launch (0–30 days)**: validation, waitlist, early adopters
**Launch (30–60 days)**: first paying customers, initial traction
**Growth (60–90 days)**: channel optimization, referral loops, retention

### Step 5: Define key metrics
- North Star Metric: the single number that proves the product is working
- Week 4 target: a specific, measurable milestone
- Month 3 target: a specific, measurable milestone

### Step 6: Write gtm-strategy.md
Create `docs/venture/` if it does not exist, then write `docs/venture/gtm-strategy.md`:

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
- [ ] [specific tactic]

### Launch (30–60 days)
- [ ] [specific tactic]
- [ ] [specific tactic]

### Growth (60–90 days)
- [ ] [specific tactic]
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

## Output Format

```
[GTM-STRATEGIST OUTPUT]
GTM file: docs/venture/gtm-strategy.md
Priority channels: [comma-separated]
ICP summary: [one sentence]
North star metric: [metric name]
Month 3 target: [specific number]
[/GTM-STRATEGIST OUTPUT]
```

## Error Handling
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing.
- **Founder selects more than 2 channels**: note "3+ channels is a common early-stage mistake — recommend focusing on 1–2 for the first 90 days." Proceed with their selection.
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-gtm-strategist`
- [ ] Checks `Priority channels:` input and skips proposal if already set
- [ ] Proposes 4–6 channels with effort, timeline, cost
- [ ] Hard pause: asks which 1–2 channels to prioritize and waits
- [ ] Defines ICP with trigger and buying process
- [ ] Produces 30/60/90 day launch sequence
- [ ] Defines North Star Metric, Week 4 target, Month 3 target
- [ ] Output block is `[GTM-STRATEGIST OUTPUT]...[/GTM-STRATEGIST OUTPUT]`
- [ ] Output block includes: file, channels, ICP summary, North star metric, Month 3 target

- [ ] **Step 3: Commit**

```bash
git add skills/nob/gtm-strategist/SKILL.md
git commit -m "feat: add gtm-strategist venture agent"
```

---

## Task 8: Write Financial-Modeler SKILL.md

**Files:**
- Create: `skills/nob/financial-modeler/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/financial-modeler/SKILL.md`:

```markdown
---
name: nob-financial-modeler
description: Fifth agent in the Venture pipeline. Builds a 12-month revenue and cost projection based on the chosen business model and GTM assumptions. Surfaces the top 3 assumptions for a soft founder sanity check — does not block on response.
---

# Nob — Financial-Modeler Agent

## Overview
Build a realistic 12-month financial projection. Derive numbers from business model assumptions and GTM metrics targets. Surface the top 3 assumptions for founder review, then continue regardless.

## Process

### Step 1: Read inputs
Read `Revenue model:`, `Key assumptions:`, `North star metric:`, and `Month 3 target:` from `[INPUTS]`.

### Step 2: Build monthly projection
Model months 1–12. Use the revenue model to define the revenue formula:
- **SaaS subscription**: `new customers per month × ARPU` (cumulative MRR)
- **Marketplace**: `GMV × commission rate`
- **One-time license**: `units sold per month × price`
- **Freemium**: `free users × conversion rate × ARPU`
- **Usage-based**: `active users × average usage × unit price`

For costs, split into:
- Fixed: team (salaries/contractors), infrastructure, tooling
- Variable: CAC (marketing spend ÷ new customers), support, transaction fees

Calculate per month: Revenue, Costs, Net (Revenue − Costs), Cumulative Net.

### Step 3: Calculate break-even
Find the month where Cumulative Net turns positive. If it does not turn positive within 12 months, flag:
> "⚠ Break-even not reached in year 1 — founder should review cost structure or revenue assumptions."

### Step 4: Soft review — surface top assumptions
Identify the 3 key assumptions that most affect the projection (e.g., monthly growth rate, churn rate, average deal size). Present them to the user:

> "These 3 assumptions drive most of the projection — do they look reasonable? (No response needed to continue.)"

Continue after presenting — do not wait for a response.

### Step 5: Write financial-model.md
Create `docs/venture/` if it does not exist, then write `docs/venture/financial-model.md`:

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
| 2 | ... | ... | ... | ... | ... |
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

## Output Format

```
[FINANCIAL-MODELER OUTPUT]
Financial model file: docs/venture/financial-model.md
Break-even month: [N, or: not within 12 months]
Top assumption: [most sensitive assumption and its value]
Flag: [flag message, or: none]
[/FINANCIAL-MODELER OUTPUT]
```

## Error Handling
- **Missing key inputs**: produce a skeleton model with `[NEEDS INPUT]` placeholders; flag "Financial model incomplete — missing: [list]"
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing.
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-financial-modeler`
- [ ] Covers all four common revenue model formulas
- [ ] Builds 12-month projection with Revenue, Costs, Net, Cumulative
- [ ] Calculates break-even month; flags if not reached in 12 months
- [ ] Soft review: surfaces top 3 assumptions, explicitly does NOT wait for response
- [ ] Produces 3 scenarios (pessimistic / base / optimistic)
- [ ] Output block is `[FINANCIAL-MODELER OUTPUT]...[/FINANCIAL-MODELER OUTPUT]`
- [ ] Output block includes: file, break-even month, top assumption, flag

- [ ] **Step 3: Commit**

```bash
git add skills/nob/financial-modeler/SKILL.md
git commit -m "feat: add financial-modeler venture agent"
```

---

## Task 9: Write Venture-Reviewer SKILL.md

**Files:**
- Create: `skills/nob/venture-reviewer/SKILL.md`

- [ ] **Step 1: Create the file**

Write `skills/nob/venture-reviewer/SKILL.md`:

```markdown
---
name: nob-venture-reviewer
description: Final agent in the Venture pipeline. Validates all five venture artifacts for completeness and cross-document consistency. Flags weak assumptions. Assembles venture-spec.md on PASS or NEEDS WORK for optional dev pipeline handoff.
---

# Nob — Venture-Reviewer Agent

## Overview
Close the loop on the Venture pipeline. Audit all artifacts for completeness and consistency. Produce a pass/fail result and assemble the Venture Spec if status is not FAIL.

## Status definitions
- **PASS**: all five artifacts exist, no critical gaps, no contradictions between documents
- **NEEDS WORK**: minor gaps or weak assumptions, no blocking contradictions — venture spec is still written
- **FAIL**: one or more artifacts missing, or a fundamental contradiction that invalidates the model

## Process

### Step 1: Read all artifact output blocks
Read from `[INPUTS]`: `Idea framer output:`, `Market researcher output:`, `Business modeler output:`, `GTM strategist output:`, `Financial modeler output:`.

Also read these files directly to verify they were written:
- `docs/venture/idea-frame.md`
- `docs/venture/market-research.md`
- `docs/venture/business-model.md`
- `docs/venture/gtm-strategy.md`
- `docs/venture/financial-model.md`

### Step 2: Check completeness
For each artifact, verify:
- File exists and has content in all sections
- No `[TBD]`, `[DATA NOT FOUND]`, or `[NEEDS INPUT]` placeholders remain without an accompanying flag
- Action Plan section is present

### Step 3: Check cross-document consistency
Verify:
- Business model target user matches idea-frame persona
- GTM ICP matches idea-frame target user and business model customer profile
- Financial model revenue formula matches business model's chosen revenue model
- Financial model assumptions are grounded in market research figures (TAM/SAM)
- GTM North Star Metric aligns with the chosen revenue model (e.g., SaaS → MRR, marketplace → GMV)

Flag each inconsistency found.

### Step 4: Check assumption quality
Review the top 3 assumptions from the financial model. Flag any that are:
- Not grounded in market research data (invented figures)
- Unusually optimistic (>20% monthly growth rate in month 1)
- Missing entirely (placeholder value)

### Step 5: Determine overall status
Apply the status definitions from above exactly.

### Step 6: Assemble Venture Spec (on PASS or NEEDS WORK)
Create `docs/venture/` if it does not exist, then write `docs/venture/venture-spec.md`:

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

[PM-AGENT REQUIREMENTS]
Problem: [one-line]
Target user: [one-line]
Revenue model: [one-line]
MVP scope: [2-3 sentences on what the minimum viable product must do]
needs_dev: [true | false]
[/PM-AGENT REQUIREMENTS]
```

Set `needs_dev: true` if the solution requires software. Set `needs_dev: false` for non-tech businesses (retail, consulting, physical product, service business).

### Step 7: Output

```
[VENTURE-REVIEWER OUTPUT]
Status: PASS | NEEDS WORK | FAIL
Idea frame:       ✓ | ✗ | ⚠
Market research:  ✓ | ✗ | ⚠
Business model:   ✓ | ✗ | ⚠
GTM strategy:     ✓ | ✗ | ⚠
Financial model:  ✓ | ✗ | ⚠
Venture spec: docs/venture/venture-spec.md | not written (FAIL)
needs_dev: true | false
Issues:
- [specific issue — or: none]
[/VENTURE-REVIEWER OUTPUT]
```

## Error Handling
- **Artifact file missing**: mark that artifact ✗ and set overall status to FAIL
- **`docs/venture/` missing**: create it with `mkdir -p docs/venture` before writing
- **Conflicting `needs_dev` signals**: default to `needs_dev: true` and note the ambiguity
```

- [ ] **Step 2: Verify against spec**

Re-read the file. Check:
- [ ] Frontmatter name is `nob-venture-reviewer`
- [ ] Three status levels: PASS, NEEDS WORK, FAIL — writes spec on PASS or NEEDS WORK
- [ ] Reads all 5 artifact files directly to verify they exist
- [ ] Checks completeness (all sections, no unresolved placeholders)
- [ ] Checks cross-document consistency (target user, revenue model, assumptions)
- [ ] Checks assumption quality (grounded, not >20% month-1 growth, not missing)
- [ ] Assembles `venture-spec.md` with `[PM-AGENT REQUIREMENTS]` block
- [ ] Sets `needs_dev: true | false`
- [ ] Output block is `[VENTURE-REVIEWER OUTPUT]...[/VENTURE-REVIEWER OUTPUT]`
- [ ] Output block has per-artifact status symbols and issues list

- [ ] **Step 3: Commit**

```bash
git add skills/nob/venture-reviewer/SKILL.md
git commit -m "feat: add venture-reviewer agent"
```

---

## Task 10: Add Venture Workflow dispatch section to hub

**Files:**
- Modify: `skills/nob/SKILL.md` (add new section after Venture early exit, before Phase 0)

- [ ] **Step 1: Find the insertion point**

Locate the `## Phase 0: Resume scan` heading in `skills/nob/SKILL.md`. The new `## Venture Workflow` section goes immediately before it.

- [ ] **Step 2: Insert the Venture Workflow section**

Insert this entire block immediately before `## Phase 0: Resume scan`:

```markdown
---

## Venture Workflow

Run this section only when the identified workflow is `Venture` (routed here from the Venture early exit above).

Store the user's original message as VENTURE_IDEA.

### Checkpoint setup

Create directories if they do not exist:
```bash
mkdir -p docs/venture
mkdir -p {checkpoint.path}
```

Ensure `.nob/` appears in `.gitignore` at the repo root. If the line is absent, append it using the Edit tool.

Read `{checkpoint.path}venture-checkpoint.json` if it exists. Store as VENTURE_CHECKPOINT (null if not found or not parseable).

Stage order: `[idea-framer, market-researcher, business-modeler, gtm-strategist, financial-modeler, venture-reviewer]`

For each stage in order: if VENTURE_CHECKPOINT has `stages.[stage-name].status: "completed"`, restore its output from `stages.[stage-name].output` and skip re-running it.

Helper: write venture checkpoint after each stage completes. Read the current `venture-checkpoint.json` (or start with `{}`), update only `stages.[stage-name]` to `{status: "completed", output: "[extracted output block]", output_file: "[file path]"}`, write back.

---

### Stage 1: Idea-Framer

Skip if VENTURE_CHECKPOINT shows `stages.idea-framer.status: "completed"`. Restore IDEA_FRAMER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/idea-framer/SKILL.md`. Dispatch with `model: agents.models["idea-framer"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/idea-framer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea: {VENTURE_IDEA}
[/INPUTS]
```

Extract `[IDEA-FRAMER OUTPUT]...[/IDEA-FRAMER OUTPUT]`. Store as IDEA_FRAMER_OUTPUT.

Write venture checkpoint for `idea-framer`.

---

### Stage 2: Market-Researcher

Skip if VENTURE_CHECKPOINT shows `stages.market-researcher.status: "completed"`. Restore MARKET_RESEARCHER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/market-researcher/SKILL.md`. Dispatch with `model: agents.models["market-researcher"] ?? "sonnet"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/market-researcher/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Problem: {Problem field from IDEA_FRAMER_OUTPUT}
[/INPUTS]
```

Extract `[MARKET-RESEARCHER OUTPUT]...[/MARKET-RESEARCHER OUTPUT]`. Store as MARKET_RESEARCHER_OUTPUT.

**Soft review**: if `Flag:` in MARKET_RESEARCHER_OUTPUT is not `none`, print the flag message to the user. Then print: "Research complete. Continuing to business modeling..."

Write venture checkpoint for `market-researcher`.

---

### Stage 3: Business-Modeler

Skip if VENTURE_CHECKPOINT shows `stages.business-modeler.status: "completed"`. Restore BUSINESS_MODELER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/business-modeler/SKILL.md`. Dispatch with `model: agents.models["business-modeler"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/business-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Market research summary: {MARKET_RESEARCHER_OUTPUT}
Chosen revenue model:
[/INPUTS]
```

Note: leave `Chosen revenue model:` blank — the agent contains its own hard pause and will ask the founder.

Extract `[BUSINESS-MODELER OUTPUT]...[/BUSINESS-MODELER OUTPUT]`. Store as BUSINESS_MODELER_OUTPUT.

Write venture checkpoint for `business-modeler`.

---

### Stage 4: GTM-Strategist

Skip if VENTURE_CHECKPOINT shows `stages.gtm-strategist.status: "completed"`. Restore GTM_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/gtm-strategist/SKILL.md`. Dispatch with `model: agents.models["gtm-strategist"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/gtm-strategist/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea frame: {IDEA_FRAMER_OUTPUT}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Priority channels:
[/INPUTS]
```

Note: leave `Priority channels:` blank — the agent contains its own hard pause and will ask the founder.

Extract `[GTM-STRATEGIST OUTPUT]...[/GTM-STRATEGIST OUTPUT]`. Store as GTM_OUTPUT.

Write venture checkpoint for `gtm-strategist`.

---

### Stage 5: Financial-Modeler

Skip if VENTURE_CHECKPOINT shows `stages.financial-modeler.status: "completed"`. Restore FINANCIAL_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/financial-modeler/SKILL.md`. Dispatch with `model: agents.models["financial-modeler"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/financial-modeler/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Revenue model: {Revenue model field from BUSINESS_MODELER_OUTPUT}
Key assumptions: {Key assumptions field from BUSINESS_MODELER_OUTPUT}
North star metric: {North star metric field from GTM_OUTPUT}
Month 3 target: {Month 3 target field from GTM_OUTPUT}
[/INPUTS]
```

Extract `[FINANCIAL-MODELER OUTPUT]...[/FINANCIAL-MODELER OUTPUT]`. Store as FINANCIAL_OUTPUT.

**Soft review**: if `Flag:` in FINANCIAL_OUTPUT is not `none`, print the flag message to the user. Then print: "Financial modeling complete. Running venture review..."

Write venture checkpoint for `financial-modeler`.

---

### Stage 6: Venture-Reviewer

Skip if VENTURE_CHECKPOINT shows `stages.venture-reviewer.status: "completed"`. Restore REVIEWER_OUTPUT from checkpoint.

Read `{SKILL_BASE_DIR}/venture-reviewer/SKILL.md`. Dispatch with `model: agents.models["venture-reviewer"] ?? "haiku"`:

```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/venture-reviewer/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}
Idea framer output: {IDEA_FRAMER_OUTPUT}
Market researcher output: {MARKET_RESEARCHER_OUTPUT}
Business modeler output: {BUSINESS_MODELER_OUTPUT}
GTM strategist output: {GTM_OUTPUT}
Financial modeler output: {FINANCIAL_OUTPUT}
[/INPUTS]
```

Extract `[VENTURE-REVIEWER OUTPUT]...[/VENTURE-REVIEWER OUTPUT]`. Store as REVIEWER_OUTPUT.

Write venture checkpoint for `venture-reviewer`.

---

### Dev pipeline handoff

Read `needs_dev:` from REVIEWER_OUTPUT.

If reviewer `Status: FAIL`:
- Print: "Venture review found critical issues. Please address them before proceeding to technical implementation:"
- Print each item from the `Issues:` list in REVIEWER_OUTPUT.
- Jump to Venture terminal summary.

If `needs_dev: false`:
- Print: "No technical implementation needed for this venture type."
- Jump to Venture terminal summary.

If `needs_dev: true` and status is `PASS` or `NEEDS WORK`:
- Print: "Venture pipeline complete. Artifacts saved to `docs/venture/`. Ready to move into technical implementation? (yes / not yet)"
- Wait for response.
- If **yes**: re-run the hub from Step 2 with intent set to `nob docs/venture/venture-spec.md`. This will detect `Spec → Code` workflow and run the full dev pipeline.
- If **not yet**: jump to Venture terminal summary and exit.

---

### Venture terminal summary

Print this block:

```
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
{if needs_dev: false: "No technical implementation needed."}
{if status FAIL: "Critical issues found — see above before continuing."}

Checkpoint: {checkpoint.path}venture-checkpoint.json
When done: rm {checkpoint.path}venture-checkpoint.json
─────────────────────────────────────
```
```

- [ ] **Step 2: Verify the inserted section**

Re-read the hub section you just inserted. Check:
- [ ] Section is placed immediately before `## Phase 0: Resume scan`
- [ ] All 6 stages are present in order
- [ ] Each stage has: skip-if-checkpoint logic, dispatch prompt with `[INSTRUCTIONS]` + `[INPUTS]` blocks, output extraction, checkpoint write
- [ ] Stage 1 (Idea-Framer): no hard pause in hub — agent handles it
- [ ] Stage 2 (Market-Researcher): soft review — hub prints flag if present
- [ ] Stage 3 (Business-Modeler): `Chosen revenue model:` is blank — agent handles pause
- [ ] Stage 4 (GTM-Strategist): `Priority channels:` is blank — agent handles pause
- [ ] Stage 5 (Financial-Modeler): soft review — hub prints flag if present
- [ ] Stage 6 (Venture-Reviewer): FAIL → print issues + summary; `needs_dev: false` → skip dev prompt
- [ ] Dev pipeline handoff: re-runs hub from Step 2 with `venture-spec.md` as input
- [ ] Terminal summary format matches spec (shows all 6 stages with ✓ markers)

- [ ] **Step 3: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Venture Workflow dispatch section to hub"
```

---

## Task 11: Add Venture terminal summary variant to hub Step 4

**Files:**
- Modify: `skills/nob/SKILL.md` (Step 4 terminal summary section)

- [ ] **Step 1: Find the Step 4 terminal summary section**

Locate `## Step 4: Print terminal summary` in the hub. Find the `**If workflow is \`Init\`, use this summary:**` block.

- [ ] **Step 2: Note that Venture summary is already handled**

The Venture terminal summary is printed inline within the `## Venture Workflow` section (Task 10 above) and exits before reaching Phase 0–3 and Step 4. No change to Step 4 is needed.

- [ ] **Step 3: Verify**

Confirm that the Venture Workflow section in the hub contains the terminal summary print block and either jumps out before reaching Step 4, or the Step 4 section clearly lists "Venture — printed inline above" to avoid ambiguity.

If Step 4 does not have a Venture note, add one line under `**If workflow is \`Init\`...**`:

```
**If workflow is `Venture`**: summary is printed inline in the Venture Workflow section above. This section is not reached for Venture runs.
```

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "docs: clarify Venture terminal summary location in hub Step 4"
```

---

## Task 12: Update .nob.yml.template

**Files:**
- Modify: `skills/nob/templates/.nob.yml.template`

- [ ] **Step 1: Find the models block**

Locate the `agents.models` section. Currently ends with:
```yaml
    qa-agent: haiku
    reviewer: haiku
```

- [ ] **Step 2: Add venture agent models**

Replace that ending with:
```yaml
    qa-agent: haiku
    reviewer: haiku
    idea-framer: haiku           # venture pipeline agents
    market-researcher: sonnet    # web research needs sonnet
    business-modeler: haiku
    gtm-strategist: haiku
    financial-modeler: haiku
    venture-reviewer: haiku
```

- [ ] **Step 3: Add venture.enabled field**

Find the `max_parallel_slices` line:
```yaml
  max_parallel_slices: 3    # cap concurrent fan-out pipelines (default: 3)
```

Add after it:
```yaml
  venture:
    enabled: true           # set false to disable /nob venture detection
```

- [ ] **Step 4: Verify**

Re-read `.nob.yml.template`. Check:
- [ ] All 6 venture agent model entries are present with correct model values
- [ ] `venture.enabled: true` is present with a comment
- [ ] Existing fields are unchanged

- [ ] **Step 5: Commit**

```bash
git add skills/nob/templates/.nob.yml.template
git commit -m "feat: add venture config fields to .nob.yml.template"
```

---

## Self-Review

After all tasks are complete, run this checklist:

**Spec coverage:**
- [ ] Section 1 (Venture detection): Tasks 1, 3 cover hub routing ✓
- [ ] Section 2 (6-agent pipeline): Tasks 4–9 cover all 6 agents; Task 10 covers hub dispatch ✓
- [ ] Section 3 (hybrid decision points): Idea-Framer hard pause (Task 4), Business-Modeler hard pause (Task 6), GTM hard pause (Task 7), Market-Researcher soft review (Tasks 5, 10), Financial-Modeler soft review (Tasks 8, 10) ✓
- [ ] Section 4 (dev pipeline integration): Task 10 dev pipeline handoff section ✓
- [ ] Section 5 (output artifacts): All 6 agents write to `docs/venture/`; Venture-Reviewer assembles `venture-spec.md` ✓
- [ ] Checkpointing: Task 10 includes checkpoint setup, per-stage writes, and resume logic ✓
- [ ] `.nob.yml.template`: Task 12 ✓

**Placeholder scan:** No TBDs or TODOs in the plan.

**Type consistency:** All output block names are consistent across agent SKILL.md files and hub dispatch sections:
- `[IDEA-FRAMER OUTPUT]` / `[/IDEA-FRAMER OUTPUT]`
- `[MARKET-RESEARCHER OUTPUT]` / `[/MARKET-RESEARCHER OUTPUT]`
- `[BUSINESS-MODELER OUTPUT]` / `[/BUSINESS-MODELER OUTPUT]`
- `[GTM-STRATEGIST OUTPUT]` / `[/GTM-STRATEGIST OUTPUT]`
- `[FINANCIAL-MODELER OUTPUT]` / `[/FINANCIAL-MODELER OUTPUT]`
- `[VENTURE-REVIEWER OUTPUT]` / `[/VENTURE-REVIEWER OUTPUT]`
