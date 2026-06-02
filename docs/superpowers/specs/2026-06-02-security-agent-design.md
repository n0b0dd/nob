# Security Agent

## Summary

A new Security Agent that runs after Backend + Frontend and before Reviewer. It checks only the files changed in the current implementation across four categories: OWASP Top 10, secrets, dependencies, and infra misconfigs. Severity-gated: critical issues halt the pipeline, medium/low pass through as warnings to Reviewer.

---

## Pipeline Position

```
Planner → PM Agent → Backend + Frontend (concurrent) → Security Agent → Reviewer
```

The Security Agent reads `[BACKEND-AGENT OUTPUT]` and `[FRONTEND-AGENT OUTPUT]` to extract the list of changed/created files, then reads those files directly from disk.

---

## Severity Gate

- **Critical** — pipeline halts. Hub prints findings and prompts: *"Security Agent found N critical issue(s). Fix and re-run, or skip security check? (fix / skip)"*. If the user chooses skip, hub writes a `[SECURITY-SKIPPED]` marker instead of `[SECURITY-AGENT OUTPUT]`. Reviewer notes this explicitly in its report.
- **Medium / Low** — pipeline continues. Findings are passed to Reviewer via `[SECURITY-AGENT OUTPUT]` and surfaced in its final report.

---

## Check Categories

| Category | Scope |
|---|---|
| **OWASP Top 10** | SQL injection, XSS, CSRF, broken auth/session, insecure deserialization, path traversal, hardcoded credentials in logic |
| **Secrets** | API keys, tokens, passwords, private keys committed or interpolated in changed files — flags exact file path and line number |
| **Dependencies** | Newly added packages (from changed `package.json`, `requirements.txt`, `pubspec.yaml`, etc.) checked against known CVE patterns using training knowledge — flags package name, version, and known vulnerability class |
| **Infra misconfigs** | Unsafe Docker configs (running as root, exposed ports), CI files with plaintext secrets, `.env` files checked in, overly permissive IAM/CORS settings |

Each finding includes: category, severity, file path + line number, and a one-line explanation of the risk.

---

## Complexity-Gated Execution

Mirrors the existing Backend/Frontend coordinator pattern, but complexity is determined by the Security Agent itself — not the Planner — because the actual changed file set is only known after implementation completes.

On entry, the Security Agent counts the files listed in `[BACKEND-AGENT OUTPUT]` and `[FRONTEND-AGENT OUTPUT]` and checks for dependency/infra files:

- **simple** — fewer than ~10 changed files, no new dependency files detected, no infra/config files changed → single-pass: agent reads all files in one context and runs all four checks.
- **complex** — 10+ changed files, or new dependency files detected (`package.json`, `requirements.txt`, etc.), or infra/config files changed → coordinator: spawns 4 parallel specialist sub-agents (one per category), each reads only the relevant file subset, results merged back into one output block.

The coordinator follows the same fan-out/merge shape already established in backend-agent and frontend-agent.

---

## Output Format

```
[SECURITY-AGENT OUTPUT]
Status: PASS | FINDINGS

Critical issues:
- [CRITICAL] secrets | apps/backend/src/config.ts:12 | Hardcoded JWT secret
- [CRITICAL] owasp | apps/backend/src/routes/user.ts:34 | SQL query built with string concatenation

Medium issues:
- [MEDIUM] deps | package.json | lodash@4.17.4 has known prototype pollution CVE
- [MEDIUM] infra | Dockerfile:3 | Container runs as root

Low issues:
- [LOW] owasp | apps/frontend/src/utils/sanitize.ts:8 | innerHTML assignment without sanitization
```

If no issues are found, Status is `PASS` and all issue lists are empty.

---

## Reviewer Integration

Reviewer gains a new **Step 3.5** that reads `[SECURITY-AGENT OUTPUT]` or `[SECURITY-SKIPPED]`:

- If `PASS` → adds a green line to the report: *"Security: no issues found."*
- If `FINDINGS` → lists all medium/low findings under a dedicated "Security" section. Critical issues are never present here (they blocked the pipeline earlier).
- If `[SECURITY-SKIPPED]` → notes explicitly: *"Security check was skipped by user."*

---

## File Changes

| File | Change |
|---|---|
| `skills/nob/security-agent/SKILL.md` | New — single-pass and coordinator mode, all four check categories |
| `skills/nob/SKILL.md` | New dispatch phase after Backend+Frontend: run Security Agent, read output, apply severity gate |
| `skills/nob/planner/SKILL.md` | No change — complexity is self-determined by Security Agent |
| `skills/nob/reviewer/SKILL.md` | Add Step 3.5: read `[SECURITY-AGENT OUTPUT]` or `[SECURITY-SKIPPED]`, surface in report |
