# Persistent Project Memory & Learning

## Problem statement
Nob's `.nob/project-memory.md` is an append-only Markdown log that agents scan as raw text. There is no structured indexing, no deduplication, and no cross-run pattern recognition — later runs gain little from earlier ones. Tools like Cline and continue.dev maintain rich, queryable memory of which files change together, which patterns the codebase uses, and which agent decisions were later corrected by the user. As a result, nob agents repeat the same codebase discovery work on every run and sometimes contradict decisions made in prior runs.

## Proposed solution
Replace the append-only log with a structured YAML memory file at `.nob/project-memory.yml`. Each run writes structured entries under four indexed sections: `patterns` (coding conventions observed), `routes` (API endpoints created or modified), `file_clusters` (files that changed together), and `corrections` (cases where the user overrode an agent decision). At the start of each run, the hub reads and summarises this file into a concise context block ("Project memory: N patterns, M routes, K corrections") and injects it into every agent prompt. Agents are instructed to reference memory before making decisions about naming, structure, or API design — and to flag when a proposed change contradicts a prior correction.

## YAML schema

`.nob/project-memory.yml` has two top-level scalar fields and four top-level sequence fields. All dates are ISO 8601 (`YYYY-MM-DD`). All `id` values are `sha256:` followed by the first 8 hex characters of the SHA-256 of the entry's `summary` field, lowercased and whitespace-trimmed. `run_id` is formatted as `nob-{YYYYMMDD}-{HHmmss}` derived from the wall-clock time the hub started.

```yaml
version: 1                          # incremented if schema changes
last_updated: "2026-06-03T14:22:00Z"

patterns:                           # coding conventions the agent observed
  - id: "sha256:a1b2c3d4"           # content hash of summary (for dedup)
    run_id: "nob-20260603-142200"
    date: "2026-06-03"
    summary: "API routes use Express Router, grouped by domain under apps/backend/src/routes/"
    detail: "Handlers follow: validate input → call service layer → return JSON"  # optional, 1-2 sentences

routes:                             # API endpoints created or modified
  - id: "sha256:e5f6a7b8"
    run_id: "nob-20260603-142200"
    date: "2026-06-03"
    summary: "POST /api/users/register — creates a new user account"
    method: "POST"                  # HTTP verb, uppercase
    path: "/api/users/register"
    file: "apps/backend/src/routes/users.ts"  # file where handler is defined

file_clusters:                      # files that changed together in one run
  - id: "sha256:c9d0e1f2"
    run_id: "nob-20260603-142200"
    date: "2026-06-03"
    summary: "Auth feature: middleware, route, and user model change together"
    files:
      - "apps/backend/src/middleware/auth.ts"
      - "apps/backend/src/routes/users.ts"
      - "apps/backend/src/models/user.ts"

corrections:                        # agent decisions the user overrode
  - id: "sha256:g3h4i5j6"
    run_id: "nob-20260603-151000"
    date: "2026-06-03"
    summary: "User changed password hashing from bcrypt to argon2id"
    agent_decision: "Use bcrypt for password hashing"
    user_correction: "Use argon2id — it is already a project dependency"
    file: "apps/backend/src/services/auth.ts"  # file where the correction applies, if known
```

**Deduplication rule:** before writing any entry, compute its `id`. If an entry with that `id` already exists under the same section, skip the write entirely. Comparison is case-insensitive on `summary`.

**Summary injection format** (the ≤10-line block injected into agent prompts):

```
Project memory (last updated 2026-06-03):
  Patterns (2): API routes use Express Router; Services use repository pattern
  Routes (3): POST /api/users/register; GET /api/users/:id; DELETE /api/users/:id
  File clusters (1): auth → [middleware/auth.ts, routes/users.ts, models/user.ts]
  Corrections (1): Use argon2id not bcrypt (apps/backend/src/services/auth.ts)
```

Each line under a section shows the count and then the first N summaries that fit within the 10-line budget, oldest entries dropped first when space is tight.

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
