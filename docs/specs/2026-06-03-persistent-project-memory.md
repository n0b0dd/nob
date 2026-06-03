# Persistent Project Memory & Learning

## Problem statement
Nob's `.nob/project-memory.md` is an append-only Markdown log that agents scan as raw text. There is no structured indexing, no deduplication, and no cross-run pattern recognition — later runs gain little from earlier ones. Tools like Cline and continue.dev maintain rich, queryable memory of which files change together, which patterns the codebase uses, and which agent decisions were later corrected by the user. As a result, nob agents repeat the same codebase discovery work on every run and sometimes contradict decisions made in prior runs.

## Proposed solution
Replace the append-only log with a structured YAML memory file at `.nob/project-memory.yml`. Each run writes structured entries under four indexed sections: `patterns` (coding conventions observed), `routes` (API endpoints created or modified), `file_clusters` (files that changed together), and `corrections` (cases where the user overrode an agent decision). At the start of each run, the hub reads and summarises this file into a concise context block ("Project memory: N patterns, M routes, K corrections") and injects it into every agent prompt. Agents are instructed to reference memory before making decisions about naming, structure, or API design — and to flag when a proposed change contradicts a prior correction.

## Acceptance criteria
- `.nob/project-memory.yml` is created on first successful run and updated on every subsequent PASS run
- The file contains at minimum four top-level keys: `patterns`, `routes`, `file_clusters`, `corrections`
- Each entry includes a `run_id`, `date`, and a short `summary` string
- The hub reads the file at Step 1 and injects a ≤10-line summary into every agent's `[INPUTS]` block under `Project memory:`
- Entries from different runs are deduplicated by content hash — the same route or pattern is not written twice
- When an agent proposes something that contradicts a `corrections` entry, it must note the conflict in its output block under a `Memory conflicts:` field
- Legacy `project-memory.md` files are migrated to `.yml` on first run after upgrade (the hub reads `.md` if `.yml` is absent, converts, writes `.yml`, removes `.md`)

## Affected files
- `skills/nob/SKILL.md` — update Step 1 to read `.nob/project-memory.yml`; update Step 4.5 to write structured YAML instead of Markdown
- `skills/nob/backend-agent/SKILL.md` — add `Memory conflicts:` field to output block spec
- `skills/nob/frontend-agent/SKILL.md` — add `Memory conflicts:` field to output block spec
- `skills/nob/templates/.nob.yml.template` — document `memory.structured: true` flag

## Out of scope
- Vector embedding or semantic search over memory
- Cloud sync or shared memory across team members
- Automatic memory pruning or TTL (entries accumulate indefinitely)
