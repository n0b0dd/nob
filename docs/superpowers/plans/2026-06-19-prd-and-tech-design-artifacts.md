# Plan: PRD + Technical Design artifacts (professional-team model)

- **Date:** 2026-06-19
- **Status:** ✅ Done — **reduced cut**, all 4 phases landed in v1.7.0
- **Author:** nob maintainer + Claude

## Chosen scope: REDUCED CUT

Per decision: **keep the `docs/specs/` directory name and all "spec" plumbing** (no rename, minimal vocabulary churn). The two substantive changes are:
1. **PM authors a pure-product document** — drop the technical sections (`## API contracts`, `## Data models`) from the doc PM writes, so it is a PRD *in content* while still living at `docs/specs/<slug>.md`.
2. **Tech Lead persists a Technical Design** to `docs/design/<slug>.md` (new artifact; today ephemeral). This is what delivers the team feel.

Everything else in the "full enumeration" below (rename `docs/specs`→`docs/prd`, workflow vocabulary "Spec→Code"→"PRD→Code", renaming dispatch input fields, checkpoint `spec_path`→`prd_path`) is **deferred / not done** in the reduced cut. The full enumeration is kept for reference only.

### Reduced-cut phases (the ones we execute)
- **Phase 1 — PM pure-product doc.** Drop `## API contracts` + `## Data models` from PM's spec-writing template (`skills/pm/SKILL.md` Step 3). Keep `# Feature:` title and `docs/specs/` location for pipeline familiarity. (spec.template.md — the human superset — keeps its technical sections; only the PM-authored template changes.)
- **Phase 2 — Tech Lead persists design.** New `skills/nob/templates/design.template.md`; Tech Lead writes `docs/design/<slug>.md` (resolve `DESIGN_DIR` from `.nob.yml` `docs.design` → default `docs/design`; `<slug>` from the spec filename); add `Design doc:` to `[TECH LEAD OUTPUT]`.
- **Phase 3 — config + hub + generated docs.** Document `docs.design` in `.nob.yml.reference.yml`; hub terminal summary adds a `Design:` line and the unit-boundary `allow` list includes the design dir; init/refactor generated `CLAUDE.md` folder structure mentions `docs/design`. No checkpoint/field/vocabulary renames.
- **Phase 4 — verify + version bump.** Grep sweep for stray technical sections in PM output and confirm design-doc writes resolve; bump `plugin.json` + `marketplace.json`; changelog.

Execute one phase at a time, pausing for review between phases.

## Motivation

We have already purified the agents so that **PM is pure product** (the *what/why*) and **Tech Lead owns everything technical** (the *how*). But the document model hasn't caught up: there is a single overloaded artifact — the "spec" — that mixes product and technical sections, is authored by PM/human, and whose technical counterpart (Tech Lead's design) is **ephemeral** (lives only in the `[TECH LEAD OUTPUT]` block and disappears after the run).

Real product teams use **two artifacts owned by two roles**:

| Role | Artifact | Contains |
|---|---|---|
| **PM** | **PRD** (`docs/prd/<slug>.md`) | Problem, users, user flow, requirements, acceptance criteria, out of scope — *what/why* |
| **Tech Lead** | **Technical Design** (`docs/design/<slug>.md`) | Interfaces/contracts, data schemas, task breakdown, risks — *how* |

This plan splits the overloaded "spec" into **PRD (PM)** + **Technical Design (Tech Lead)**, and **persists** the design doc so both are reviewable artifacts. The pipeline becomes:

```
PM → docs/prd/<slug>.md → Tech Lead → docs/design/<slug>.md → dev → Reviewer
```

## Key decisions (recommended answers baked into this plan)

1. **Persist the Tech Lead design doc** → **YES.** Tech Lead writes `docs/design/<slug>.md` in addition to emitting `[TECH LEAD OUTPUT]`. This is what makes it a real team workflow (a reviewable engineering doc, not an ephemeral block).
2. **Rename `docs/specs` → `docs/prd`** → **YES, with a legacy fallback.** New PRDs go to `docs/prd/`. The hub/skills still **read** `docs/specs/` if present (deprecated alias) so existing projects don't break. `.nob.yml` gains `docs.prd` and `docs.design`; `docs.specs` is honored as a fallback.
3. **Entry command** stays `/nob implement <path>` — it accepts a PRD path (or a legacy spec path). No new verb.

> If you want a smaller first cut, the fallback-only option is: keep `docs/specs` as the directory name, change only the *content/role* to a PRD, and still persist `docs/design`. That avoids the rename churn. Flagged in "Alternatives" below.

## Backward compatibility

- **Existing `docs/specs/` files**: still readable. Pre-flight and PM/Tech-Lead/Reviewer accept a path under either `docs/prd/` or `docs/specs/`.
- **Existing `.nob.yml` with `docs.specs`**: honored. Resolution order for the PRD dir = `docs.prd` → `docs.specs` → default `docs/prd`. Design dir = `docs.design` → default `docs/design`.
- **`venture`**: `venture-spec.md` is a separate venture artifact; it is renamed to `venture-prd.md` for consistency but keeps its own location (`docs/venture/`). Low risk — self-contained.

## Surface area (full enumeration)

### Templates
- `skills/nob/templates/spec.template.md` → **rename to `prd.template.md`**. Strip the technical sections (`## API contracts`, `## Data models`, `## UI spec` per-platform blocks) — those are the Tech Lead's design, not the PRD. Keep: Summary, Users, Platform targets, User flow, Requirements, Acceptance criteria, Builds on, Constraints, Error states, Out of scope, Open questions.
- **New `skills/nob/templates/design.template.md`** — the Tech Lead's persisted design doc shape (Interfaces/contracts, Data schemas, Task list, Risks). Mirrors the `[TECH LEAD OUTPUT]` fields.
- `.nob.yml.template` + `.nob.yml.reference.yml` — `docs.specs`/`docs.bugs` → document `docs.prd`, `docs.design`, `docs.bugs` (note `docs.specs` accepted as legacy alias).
- `CLAUDE.md.template` — folder-structure references `/docs/specs` → `/docs/prd` + `/docs/design`.

### `skills/pm/SKILL.md`
- Spec-Writing Mode → **PRD-Writing Mode**. Resolve `PRD_DIR` (was SPECS_DIR) from `docs.prd` → `docs.specs` → `docs/prd`.
- Drop `## API contracts` / `## Data models` from the authored template (pure product PRD).
- Title `# PRD: [name]` (was `# Feature:`).
- Output: `Spec written to …` → `PRD written to …`; `[PM SPECWRITER OUTPUT]` `Spec file:` → `PRD file:`.
- Revision loop, "Ready to implement?" prompts → reference PRD.

### `skills/tech-lead/SKILL.md`
- Reads the PRD (`Spec file path/contents` inputs → rename to `PRD file path/contents`).
- **New step (Step 6 or after Step 2): write `docs/design/<slug>.md`** from the design it just produced, using `design.template.md`. Resolve `DESIGN_DIR` from `docs.design` → `docs/design`. Derive `<slug>` from the PRD filename.
- `[TECH LEAD OUTPUT]` gains a `Design doc:` field with the written path.

### `skills/dev/SKILL.md`
- Standalone-input references to a "spec file path" → "PRD file path / design doc". `.nob/pm-output.md` discovery comment unchanged (still ephemeral block).
- No functional change to how dev consumes the task list (it comes via `[TECH LEAD SPEC]`).

### `skills/reviewer/SKILL.md`
- "Read the original source file" → reads the **PRD** (`PRD file path/contents`). Acceptance criteria still from `[PM OUTPUT]`.
- Optionally read `docs/design/<slug>.md` for the contract check instead of only `[TECH LEAD OUTPUT]` (nice-to-have; keep block-based for now to limit scope).

### `skills/ideation/SKILL.md`
- Writes a **PRD** to `PRD_DIR` (already unified onto the PM spec shape — now the PRD shape). Update wording: "spec" → "PRD"; final line `Run: /nob implement {PRD_DIR}/<file>`.

### `skills/init/SKILL.md` & `skills/refactor/SKILL.md`
- `.nob.yml` they generate: `docs:` block documents `prd:`/`design:`/`bugs:` (still minimal — only `units` required, so this is comment/guidance only).
- "Write a spec: docs/specs/your-feature.md" → "Write a PRD: docs/prd/your-feature.md".
- CLAUDE.md they generate: folder structure → `docs/prd` + `docs/design`.

### `skills/nob/SKILL.md` (hub)
- **Vocabulary:** "Spec → Code" workflow → **"PRD → Code"**; "Idea → Spec → Code" → "Idea → PRD → Code". Triggers (`implement [file]`) unchanged.
- **Step 0** branch/run-id derivation from filename — unchanged logic, wording "spec" → "PRD".
- **Step 1.5 pre-flight** — validates the PRD path; still requires `## Acceptance criteria`. Accepts `docs/prd/` or legacy `docs/specs/`.
- **Phase 2 dispatch** — `Spec file path/contents` → `PRD file path/contents` to PM, Tech Lead, Reviewer.
- **Checkpoint** — `spec_path` → `prd_path` (read old `spec_path` as fallback on resume); add `design_path`.
- **Unit-boundary marker `allow`** — add the resolved `docs.design` dir; keep `docs.prd`/`docs.specs`/`docs.bugs`.
- **Terminal summary** — "Source: [spec/bug file path]" → "PRD: …" + new "Design: docs/design/<slug>.md" line.
- **Config defaults / auto-detect** — `docs.prd`, `docs.design`, `docs.bugs` with legacy alias resolution.
- **Auto-PR** — title from PRD filename (unchanged logic).

### Repo's own docs (this plugin)
- `CLAUDE.md` (repo root) — update the "Specs and Plans" section to reflect PRD/design vocabulary where it describes user-project artifacts (the repo's *own* `docs/superpowers/specs|plans` stay as-is — those are about the plugin, not user projects).
- `README.md` — update any spec→PRD vocabulary in the workflow description.

## Execution phases

1. **Config + templates** — define `docs.prd`/`docs.design` resolution (with `docs.specs` fallback); add `prd.template.md` + `design.template.md`; retire `spec.template.md`.
2. **PM** — PRD-writing mode, pure-product template, PRD_DIR resolution, output wording.
3. **Tech Lead** — read PRD; persist `docs/design/<slug>.md`; add `Design doc:` to output.
4. **Hub** — vocabulary, pre-flight, dispatch input names, checkpoint fields, boundary allow-list, terminal summary, config resolution.
5. **Ideation / init / refactor / dev / reviewer / venture** — vocabulary + dir resolution sweep.
6. **Repo docs** — CLAUDE.md, README.
7. **Verification** — grep sweep for residual `docs/specs`, `spec.template`, "Spec→Code", `spec_path`; confirm legacy-fallback reads still resolve.
8. **Version bump** — `plugin.json` + `marketplace.json`; changelog covering this + the session's earlier changes.

## Risks

- **Large surface / vocabulary churn** — every skill touched. Mitigated by the grep-sweep verification step and the legacy fallback (nothing hard-breaks).
- **Resume compatibility** — in-flight runs with a `spec_path` checkpoint: read `spec_path` as fallback for `prd_path`.
- **Two-doc drift** — PRD and design could disagree. Acceptable: design is *derived from* the PRD each run; Reviewer validates implementation against PRD acceptance criteria (single source of truth for "done").
- **Scope creep into Reviewer** reading the design doc — deferred (keep block-based contract check) to bound this change.

## Alternatives considered

- **Rename-only (no design doc)** — cosmetic; rejected, doesn't deliver the team feel.
- **Keep `docs/specs` dir name, change role to PRD + add `docs/design`** — smaller, avoids rename churn; viable as a reduced first cut (see Decision 2 note).
- **Persist design as an appended section in the PRD** — rejected; muddies the PM-owns-PRD boundary.

## Out of scope

- Multi-reviewer / design-review gates before dev.
- Migrating existing user `docs/specs/` files on disk (we read them in place; no bulk rename).
- Changing the `docs/bugs` (Bug→Fix) artifact beyond vocabulary alignment.
