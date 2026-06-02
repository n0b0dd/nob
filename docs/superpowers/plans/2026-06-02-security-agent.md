# Security Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Security Agent that runs after Backend + Frontend and before Reviewer, checks only changed files across OWASP Top 10 / secrets / dependencies / infra categories, and severity-gates the pipeline on critical findings.

**Architecture:** New `security-agent/SKILL.md` follows the existing coordinator pattern (simple path = single-pass, complex path = 4 parallel specialists). Hub gains Phase 2.5 between Phase 2 and Phase 3 with a severity gate. Reviewer gains Step 3.6 to surface medium/low findings in its report.

**Tech Stack:** Markdown skill files only — no build system, no runtime.

---

### Task 1: Create `skills/nob/security-agent/SKILL.md`

**Files:**
- Create: `skills/nob/security-agent/SKILL.md`

- [ ] **Step 1: Create the file with the full skill content**

Write `skills/nob/security-agent/SKILL.md` with exactly this content:

````markdown
---
name: nob-security-agent
description: Use after Backend and Frontend agents complete in a Nob workflow. Reads changed files from implementation outputs and checks them for security issues across four categories: OWASP Top 10, secrets, dependencies, and infra misconfigs. Outputs a structured [SECURITY-AGENT OUTPUT] block. Part of the Nob skill hub.
---

# Nob — Security Agent

## Overview
Review the files changed in this implementation for security issues. Check only what was touched — do not scan the whole codebase. Produce an honest severity-tagged findings list.

## Process

### Step 1: Extract changed files

From context, find and read:
- `[BACKEND-AGENT OUTPUT]` — extract all paths from `Files changed:` and `Files created:`
- `[FRONTEND-AGENT OUTPUT]` — extract all paths from `Files changed:` and `Files created:`

If context contains `[MERGED SLICE OUTPUTS]` instead of individual agent outputs: scan all slice sections and extract all `Files changed:` and `Files created:` entries from every `[BACKEND-AGENT OUTPUT]` and `[FRONTEND-AGENT OUTPUT]` block within the merged block.

Combine all extracted paths into CHANGED_FILES (deduplicated). If CHANGED_FILES is empty after extraction, emit `Status: PASS` with note "No files changed — nothing to scan" and stop.

Also check CHANGED_FILES for the following file types:

- **Dependency files**: `package.json`, `package-lock.json`, `yarn.lock`, `requirements.txt`, `pyproject.toml`, `pubspec.yaml`, `go.mod`, `Gemfile`, `Cargo.toml`
- **Infra/config files**: `Dockerfile`, `docker-compose.yml`, any file under `.github/workflows/`, `.gitlab-ci.yml`, `.env`, `.env.example`, any `*.tf` file, any `*.yaml` or `*.yml` under `k8s/`, `helm/`, or `infra/`

Set HAS_DEP_FILES = true if any dependency files appear in CHANGED_FILES.
Set HAS_INFRA_FILES = true if any infra/config files appear in CHANGED_FILES.

If a `.env` file appears in CHANGED_FILES: this is immediately a CRITICAL finding regardless of path. Record it now: `[CRITICAL] infra | {path} | .env file committed to version control`.

### Step 2: Select execution path

Count entries in CHANGED_FILES:

- Fewer than 10 files AND HAS_DEP_FILES = false AND HAS_INFRA_FILES = false → **simple path** — continue to Step 3.
- Otherwise → **coordinator mode** — skip Steps 3 and 4, go to the **Coordinator Mode** section below.

---

## Coordinator Mode (complex path only)

Enter this section only when the file count or file types require it (Step 2). This replaces Steps 3 and 4. After completing Step 4-C, proceed directly to Step 5 (Output).

### Step 3-C: Dispatch 4 parallel specialist sub-agents

Dispatch all four in the same assistant turn — do not await any before dispatching the others.

**OWASP Specialist** (model: haiku):

```
You are a security specialist focused on OWASP Top 10 vulnerabilities. Read each file listed below and check for:

- SQL injection: string concatenation building query strings (e.g. `"SELECT " + userInput`, f-strings with user data in SQL, template literals in ORM raw() calls)
- XSS: `innerHTML =` assignments, `dangerouslySetInnerHTML`, unescaped user input rendered as HTML, `document.write(userInput)`
- CSRF: POST/PUT/DELETE/PATCH route handlers that modify state but have no CSRF token check and no same-site cookie attribute visible in the file
- Broken authentication: route handlers that access user-specific data but have no visible auth middleware or session check
- Path traversal: `path.join(userInput)`, `fs.readFile(userInput)`, `open(userInput)` without path normalization or whitelist validation
- Insecure deserialization: `pickle.loads` on non-literal input, `JSON.parse` on untrusted network data used in a security-sensitive context (eval, exec, dynamic require)

Files to read and review:
{all paths from CHANGED_FILES that are NOT dependency files and NOT infra/config files}

Output one line per finding in this exact format:
[CRITICAL|MEDIUM|LOW] owasp | {file}:{line} | {one-sentence description of the vulnerability}

Severity guide: SQL injection, broken auth on user data → CRITICAL. XSS, CSRF on state-changing endpoints → MEDIUM. Path traversal with partial mitigation, insecure deserialization in low-risk context → LOW.

If no issues found: output exactly the word: none
```

**Secrets Specialist** (model: haiku):

```
You are a security specialist focused on hardcoded secrets and credentials. Read each file listed below and check for:

- API key patterns hardcoded as string literals: strings starting with `sk-`, `pk_live_`, `AKIA`, `AIza`, `ghp_`, `glpat-`
- Passwords assigned directly to variables: `password = "..."`, `PASSWORD = "..."`, `db_pass = "..."` (not from os.environ or process.env)
- Private key material: `-----BEGIN PRIVATE KEY-----`, `-----BEGIN RSA PRIVATE KEY-----`, `-----BEGIN EC PRIVATE KEY-----`
- Auth tokens hardcoded in request headers: `Authorization: Bearer <literal-token>`
- JWT secrets hardcoded in string literals: `secret = "my-jwt-secret"`, `JWT_SECRET = "hardcoded"`

Files to read and review:
{all paths from CHANGED_FILES}

Output one line per finding in this exact format:
[CRITICAL|MEDIUM|LOW] secrets | {file}:{line} | {one-sentence description}

Severity guide: private keys, live API keys, JWT secrets → CRITICAL. Hardcoded passwords → CRITICAL. Test credentials (strings containing "test", "fake", "example") → LOW.

If no issues found: output exactly the word: none
```

**Dependencies Specialist** (model: haiku):

```
You are a security specialist focused on dependency vulnerabilities. Read each dependency file listed below. For each package that appears to be newly added (not already present in lockfiles or clearly a core dependency), check your training knowledge for known CVEs, vulnerabilities, or security advisories.

Focus on packages with known: prototype pollution, ReDoS (catastrophic backtracking), path traversal, remote code execution, or data exfiltration vulnerabilities. Pay attention to the pinned version — a vulnerable version range is a finding even if a patched version exists.

Files to read and review:
{all dependency file paths from CHANGED_FILES: package.json, requirements.txt, pyproject.toml, pubspec.yaml, go.mod, Gemfile, Cargo.toml}

Output one line per finding in this exact format:
[CRITICAL|MEDIUM|LOW] deps | {file} | {package}@{version}: {vulnerability class and CVE if known}

Severity guide: RCE, credential theft → CRITICAL. Data exposure, path traversal in dep → MEDIUM. ReDoS, prototype pollution in non-critical path → LOW.

If no dependency files were provided or no known vulnerabilities found: output exactly the word: none
```

**Infra Specialist** (model: haiku):

```
You are a security specialist focused on infrastructure misconfigurations. Read each file listed below and check for:

- Dockerfile: no `USER` directive before the final `CMD` or `ENTRYPOINT` (container runs as root) → MEDIUM; `EXPOSE` of ports like 22, 3306, 5432, 27017 without a comment explaining why → LOW
- CI/CD files (.github/workflows/*.yml, .gitlab-ci.yml): plaintext `password:`, `token:`, `secret:` keys with literal values (not `${{ secrets.X }}` or `$ENV_VAR`) → CRITICAL
- docker-compose.yml: services with no `user:` setting AND privileged: true → MEDIUM; volumes mounting host root paths → MEDIUM
- Terraform / k8s YAML: IAM policies with `"*"` as Action or Resource → MEDIUM; `allowPrivilegeEscalation: true` in pod specs → MEDIUM
- CORS configuration: `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` → CRITICAL; wildcard origins on non-public authenticated APIs → MEDIUM

Files to read and review:
{all infra/config file paths from CHANGED_FILES}

Output one line per finding in this exact format:
[CRITICAL|MEDIUM|LOW] infra | {file}:{line} | {one-sentence description}

If no infra files were provided or no issues found: output exactly the word: none
```

### Step 4-C: Merge findings

Collect all output lines from the four specialists. Filter out any "none" responses. Include the `.env` CRITICAL finding from Step 1 if present.

Deduplicate: if two specialists flagged the same file+line for related reasons, keep the higher severity entry.

Group into Critical (all `[CRITICAL]` lines), Medium (all `[MEDIUM]` lines), Low (all `[LOW]` lines).

Set Status = PASS if all lists are empty, else FINDINGS.

Proceed to Step 5 (Output).

---

## Step 3: Simple path — single-pass review

Read all files in CHANGED_FILES. For each file, check all four categories inline:

**OWASP Top 10** — check every source code file for:
- SQL injection: string concatenation building queries (`"SELECT " + userInput`, f-strings with user data in SQL, template literals in ORM raw queries)
- XSS: `innerHTML =`, `dangerouslySetInnerHTML`, unescaped variables in HTML template strings, `document.write(userInput)`
- CSRF: POST/PUT/DELETE handlers that modify state but lack a CSRF token check
- Broken auth: routes accessing user data without auth middleware
- Path traversal: `path.join(userInput)`, `fs.readFile(userInput)`, `open(userInput)` without sanitization
- Insecure deserialization: `pickle.loads` or `JSON.parse` on untrusted input in security-sensitive context

**Secrets** — check every file for:
- API key patterns: strings starting with `sk-`, `pk_live_`, `AKIA`, `AIza`, `ghp_`, `glpat-`
- Variables named `password`, `secret`, `token`, `api_key` assigned string literals (not `process.env.X` or `os.environ["X"]`)
- `-----BEGIN PRIVATE KEY-----` or `-----BEGIN RSA PRIVATE KEY-----` in any file
- Hardcoded Bearer tokens in request headers

**Dependencies** — for each dependency file in CHANGED_FILES, check newly added packages against known CVE patterns from training knowledge.

**Infra** — for each infra/config file in CHANGED_FILES:
- Dockerfile: no `USER` directive → MEDIUM; exposed sensitive ports → LOW
- CI files: plaintext secrets → CRITICAL
- CORS: `Access-Control-Allow-Origin: *` with credentials → CRITICAL; wildcard on non-public endpoints → MEDIUM
- docker-compose: `privileged: true` → MEDIUM

Group all findings into Critical, Medium, Low. Set Status = PASS if none found, else FINDINGS.

## Step 4: Output (simple path)

Emit the `[SECURITY-AGENT OUTPUT]` block as defined in Output Format below.

---

## Output Format

```
[SECURITY-AGENT OUTPUT]
Status: PASS | FINDINGS

Critical issues:
- [CRITICAL] {category} | {file}:{line} | {one-sentence description}
(or: none)

Medium issues:
- [MEDIUM] {category} | {file}:{line} | {one-sentence description}
(or: none)

Low issues:
- [LOW] {category} | {file}:{line} | {one-sentence description}
(or: none)
[/SECURITY-AGENT OUTPUT]
```

If Status is PASS, all three issue lists read "none".

---

## Error Handling
- **No [BACKEND-AGENT OUTPUT] or [FRONTEND-AGENT OUTPUT] or [MERGED SLICE OUTPUTS] in context**: stop with "Security Agent cannot proceed — no implementation output blocks found in context. Ensure Backend and Frontend agents ran before Security Agent."
- **CHANGED_FILES is empty after extraction**: emit `Status: PASS` with note "No files changed — nothing to scan"
- **Coordinator specialist returns no output or an error**: treat that category as "none" for that specialist; note in findings: `[LOW] {category} | n/a | Specialist returned no output — manual check recommended`
````

- [ ] **Step 2: Self-review the skill for completeness**

Read through `skills/nob/security-agent/SKILL.md` and verify:
- Step 1 handles both single-slice context (individual `[BACKEND-AGENT OUTPUT]` / `[FRONTEND-AGENT OUTPUT]`) and fan-out context (`[MERGED SLICE OUTPUTS]`)
- Step 2 correctly gates on file count AND dep/infra file presence
- Coordinator mode dispatches all 4 specialists in the same turn (parallel)
- Simple path covers all 4 categories
- Output format matches the spec exactly
- `.env` detection in Step 1 emits a CRITICAL finding before the path selection

- [ ] **Step 3: Commit**

```bash
git add skills/nob/security-agent/SKILL.md
git commit -m "feat: add security-agent skill (single-pass + coordinator mode)"
```

---

### Task 2: Add `security-agent` model to hub defaults

**Files:**
- Modify: `skills/nob/SKILL.md` (RESOLVED_CONFIG block, ~line 132)
- Modify: `skills/nob/templates/.nob.yml.template`

- [ ] **Step 1: Add security-agent to RESOLVED_CONFIG default models in hub**

In `skills/nob/SKILL.md`, find this block (around line 131):

```
    reviewer: haiku
    init-agent: sonnet
```

Replace with:

```
    reviewer: haiku
    security-agent: haiku
    init-agent: sonnet
```

- [ ] **Step 2: Add security-agent to agents.enabled default list**

In `skills/nob/SKILL.md`, find:

```
  enabled: [planner, pm-agent, backend-agent, frontend-agent, reviewer]
```

Replace with:

```
  enabled: [planner, pm-agent, backend-agent, frontend-agent, security-agent, reviewer]
```

- [ ] **Step 3: Check if .nob.yml.template exists and add security-agent model**

Read `skills/nob/templates/.nob.yml.template`. Find the `models:` section and add `security-agent: haiku` alongside the other agent models. If the template does not contain a `models:` section, skip this step.

- [ ] **Step 4: Commit**

```bash
git add skills/nob/SKILL.md skills/nob/templates/.nob.yml.template
git commit -m "feat: add security-agent to hub defaults and .nob.yml template"
```

---

### Task 3: Add Phase 2.5 (Security dispatch + severity gate) to hub

**Files:**
- Modify: `skills/nob/SKILL.md`

This task inserts a new Phase 2.5 section and wires it into the pipeline flow.

- [ ] **Step 1: Change single-slice path to proceed to Phase 2.5 instead of Phase 3**

In `skills/nob/SKILL.md`, find (around line 657):

```
Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]

Proceed to Phase 3.
```

Replace with:

```
Set SLICE_RESULTS = [{name: "main", pm_output: PM_OUTPUT, backend_output: BACKEND_OUTPUT, frontend_output: FRONTEND_OUTPUT}]

Proceed to Phase 2.5.
```

- [ ] **Step 2: Change fan-out path to proceed to Phase 2.5 instead of Phase 3**

In `skills/nob/SKILL.md`, find:

```
Otherwise: SLICE_RESULTS is now fully populated from in-memory accumulation during dispatch. Proceed to Phase 3.
```

Replace with:

```
Otherwise: SLICE_RESULTS is now fully populated from in-memory accumulation during dispatch. Proceed to Phase 2.5.
```

- [ ] **Step 3: Insert Phase 2.5 section**

In `skills/nob/SKILL.md`, find the line that begins the Phase 3 section header:

```
## Phase 3: Merge review
```

Insert the following block immediately before it (with a blank line before the Phase 3 header):

```
## Phase 2.5: Security review

Skip this phase if `security-agent` is not in `agents.enabled`.

**Prepare Security Agent input:**

If Mode: single — BACKEND_OUTPUT and FRONTEND_OUTPUT are already in context from Phase 2.

If Mode: fan-out — construct a combined view of all changed files:
```
[MERGED SLICE OUTPUTS]
{all SLICE OUTPUT blocks from SLICE_RESULTS concatenated}
[/MERGED SLICE OUTPUTS]
```
Store as MERGED_OUTPUTS. Pass this as both the Backend and Frontend output context to the Security Agent.

**Dispatch Security Agent:**

Read `{SKILL_BASE_DIR}/security-agent/SKILL.md`. Dispatch with `model: agents.models["security-agent"] ?? "haiku"`:

For Mode: single:
```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/security-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

[BACKEND-AGENT OUTPUT]
{BACKEND_OUTPUT}
[/BACKEND-AGENT OUTPUT]

[FRONTEND-AGENT OUTPUT]
{FRONTEND_OUTPUT}
[/FRONTEND-AGENT OUTPUT]
[/INPUTS]
```

For Mode: fan-out:
```
[INSTRUCTIONS]
{full contents of {SKILL_BASE_DIR}/security-agent/SKILL.md}
[/INSTRUCTIONS]

[INPUTS]
Working directory: {current working directory path}

{MERGED_OUTPUTS block}
[/INPUTS]
```

Extract `[SECURITY-AGENT OUTPUT]...[/SECURITY-AGENT OUTPUT]`. Store as SECURITY_OUTPUT.

**Apply severity gate:**

Check SECURITY_OUTPUT for any `[CRITICAL]` lines.

If one or more `[CRITICAL]` lines are present:
1. Count them as N.
2. Print each critical finding to the user.
3. Print: "Security Agent found N critical issue(s) listed above. Fix and re-run, or skip security check? (fix / skip)"
4. Wait for user response.
   - `fix` or any non-skip response: exit. Print "Fix the issues above and re-run `/nob` to continue." Do not proceed to Phase 3.
   - `skip`: set SECURITY_OUTPUT = "[SECURITY-SKIPPED]". Print "Security check skipped — findings will be noted in the Reviewer report." Proceed to Phase 3.

If no `[CRITICAL]` lines: proceed to Phase 3 with SECURITY_OUTPUT as-is.

---

```

- [ ] **Step 4: Add SECURITY_OUTPUT to Reviewer dispatch inputs (single-slice)**

In `skills/nob/SKILL.md`, find the single-slice Reviewer dispatch `[INPUTS]` block (around line 820):

```
{FRONTEND_OUTPUT}
[/INPUTS]
```

(This is the closing of the single-slice Reviewer inputs — the last agent output before `[/INPUTS]`.)

Replace with:

```
{FRONTEND_OUTPUT}

Security Agent output:
{SECURITY_OUTPUT}
[/INPUTS]
```

- [ ] **Step 5: Add SECURITY_OUTPUT to Reviewer dispatch inputs (fan-out)**

In `skills/nob/SKILL.md`, find the fan-out Reviewer dispatch `[INPUTS]` block:

```
{MERGED SLICE OUTPUTS block constructed above}
[/INPUTS]
```

Replace with:

```
{MERGED SLICE OUTPUTS block constructed above}

Security Agent output:
{SECURITY_OUTPUT}
[/INPUTS]
```

- [ ] **Step 6: Add security status to terminal summary**

In `skills/nob/SKILL.md`, find the terminal summary block (around line 1048):

```
Tests:     Backend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT] · Frontend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT]
Review status: [PASS | NEEDS REVIEW | FAIL]
```

Replace with:

```
Tests:     Backend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT] · Frontend [PASS | FAIL | SKIPPED from REVIEWER OUTPUT]
Security:  [PASS | FINDINGS: N medium, M low | SKIPPED from SECURITY_OUTPUT]
Review status: [PASS | NEEDS REVIEW | FAIL]
```

For the Security line: if SECURITY_OUTPUT is `[SECURITY-SKIPPED]` → print "SKIPPED". If `Status: PASS` → print "PASS". If `Status: FINDINGS` → count medium and low lines and print "FINDINGS: N medium, M low".

- [ ] **Step 7: Self-review hub changes**

Read the Phase 2.5 section just inserted and verify:
- Both single and fan-out paths reference Phase 2.5 (not Phase 3) as the next step
- Phase 2.5 correctly dispatches using `{SKILL_BASE_DIR}/security-agent/SKILL.md`
- The severity gate halts on critical, passes medium/low through
- SECURITY_OUTPUT is passed to the Reviewer in both single and fan-out dispatch blocks
- The `skip` guard (`security-agent not in agents.enabled`) allows users to opt out

- [ ] **Step 8: Commit**

```bash
git add skills/nob/SKILL.md
git commit -m "feat: add Phase 2.5 security review to hub pipeline"
```

---

### Task 4: Add Step 3.6 to `skills/nob/reviewer/SKILL.md`

**Files:**
- Modify: `skills/nob/reviewer/SKILL.md`

- [ ] **Step 1: Insert Step 3.6 after Step 3.5**

In `skills/nob/reviewer/SKILL.md`, find:

```
### Step 4: Check each criterion individually
```

Insert the following block immediately before it:

```
### Step 3.6: Read security findings

Check context for `[SECURITY-AGENT OUTPUT]` or `[SECURITY-SKIPPED]`.

- If `[SECURITY-SKIPPED]` is present: store SECURITY_STATUS = "SKIPPED".
- If `[SECURITY-AGENT OUTPUT]` is present:
  - If `Status: PASS`: store SECURITY_STATUS = "PASS". No findings to record.
  - If `Status: FINDINGS`:
    - Extract all `[MEDIUM]` lines. Store as SECURITY_MEDIUM.
    - Extract all `[LOW]` lines. Store as SECURITY_LOW.
    - Store SECURITY_STATUS = "FINDINGS".
    - If SECURITY_MEDIUM is non-empty: the overall review status cannot be PASS — at minimum NEEDS REVIEW. Add each medium finding to "Items for human review".
    - Low findings are informational only — add them to the Security section of the output but do not affect overall status.
- If neither block is present: store SECURITY_STATUS = "NOT RUN — security agent output missing from context".

```

- [ ] **Step 2: Update the Reviewer output format to include a Security section**

In `skills/nob/reviewer/SKILL.md`, find the output format block:

```
Contract check:
  PM → Backend:       [PASS | VIOLATIONS: list | SKIPPED — reason]
  PM → Frontend:      [PASS | VIOLATIONS: list | SKIPPED — reason]
  Backend → Frontend: [PASS | VIOLATIONS: list | SKIPPED — reason]

Criteria check:
```

Replace with:

```
Contract check:
  PM → Backend:       [PASS | VIOLATIONS: list | SKIPPED — reason]
  PM → Frontend:      [PASS | VIOLATIONS: list | SKIPPED — reason]
  Backend → Frontend: [PASS | VIOLATIONS: list | SKIPPED — reason]

Security:
  Status: [PASS | FINDINGS: N medium, M low | SKIPPED — security check was skipped by user | NOT RUN — security agent output missing]
  [if FINDINGS: list each medium finding as "- [MEDIUM] {category} | {file}:{line} | {description}"]
  [if FINDINGS and low items: list each low finding as "- [LOW] {category} | {file}:{line} | {description}"]

Criteria check:
```

- [ ] **Step 3: Update Step 5 (overall status determination) to account for medium security findings**

In `skills/nob/reviewer/SKILL.md`, find:

```
### Step 5: Determine overall status
Apply the status definitions above exactly. Do not soften FAIL to NEEDS REVIEW.
```

Replace with:

```
### Step 5: Determine overall status
Apply the status definitions above exactly. Do not soften FAIL to NEEDS REVIEW.

Additional rule: if SECURITY_STATUS is "FINDINGS" and SECURITY_MEDIUM is non-empty, the overall status is at minimum NEEDS REVIEW — even if all spec criteria are ✓. Security medium findings require human attention before the feature ships.
```

- [ ] **Step 4: Self-review Reviewer changes**

Read through the changes to `skills/nob/reviewer/SKILL.md` and verify:
- Step 3.6 handles all three states: `[SECURITY-SKIPPED]`, `[SECURITY-AGENT OUTPUT]` with PASS, `[SECURITY-AGENT OUTPUT]` with FINDINGS
- Medium security findings force NEEDS REVIEW in Step 5
- Low findings appear in the Security output section but don't change status
- The output format Security block is placed between Contract check and Criteria check
- The `NOT RUN` case is handled for backward compatibility (runs without security agent)

- [ ] **Step 5: Commit**

```bash
git add skills/nob/reviewer/SKILL.md
git commit -m "feat: reviewer surfaces security findings in Step 3.6"
```

---

### Task 5: End-to-end trace verification

No automated tests exist — this is a Markdown skill repo. Verify correctness by reading through the full pipeline flow as a mental trace.

- [ ] **Step 1: Trace the happy path (no findings)**

Mentally trace a run where Security Agent returns `Status: PASS`:
1. Phase 2 completes → BACKEND_OUTPUT and FRONTEND_OUTPUT are set
2. Phase 2.5 dispatches security-agent → returns `[SECURITY-AGENT OUTPUT] Status: PASS`
3. No critical lines → proceeds to Phase 3
4. Phase 3 dispatches Reviewer with SECURITY_OUTPUT included
5. Reviewer Step 3.6 reads `Status: PASS` → sets SECURITY_STATUS = "PASS"
6. Reviewer output shows `Security: PASS`
7. Terminal summary shows `Security: PASS`

Confirm each step is covered by the written instructions.

- [ ] **Step 2: Trace the critical-halt path**

Mentally trace a run where Security Agent finds a critical issue:
1. Phase 2.5 dispatches security-agent → returns `Status: FINDINGS` with `[CRITICAL] secrets | ...`
2. Hub detects `[CRITICAL]` lines → prints findings → prompts user `(fix / skip)`
3. User responds `fix` → hub exits with "Fix the issues above and re-run"
4. User responds `skip` → SECURITY_OUTPUT = "[SECURITY-SKIPPED]" → proceeds to Phase 3
5. Reviewer Step 3.6 reads `[SECURITY-SKIPPED]` → SECURITY_STATUS = "SKIPPED"
6. Reviewer output shows `Security: SKIPPED — security check was skipped by user`

Confirm each step is covered.

- [ ] **Step 3: Trace the medium-findings path**

Mentally trace a run where Security Agent finds only medium/low issues:
1. Phase 2.5 dispatches security-agent → returns `Status: FINDINGS` with `[MEDIUM]` and `[LOW]` lines only (no `[CRITICAL]`)
2. Hub detects no `[CRITICAL]` lines → proceeds to Phase 3 with SECURITY_OUTPUT intact
3. Reviewer Step 3.6 reads FINDINGS → extracts SECURITY_MEDIUM → adds medium items to human review
4. Reviewer Step 5 sees SECURITY_MEDIUM is non-empty → overall status is at minimum NEEDS REVIEW
5. Reviewer output shows Security section with medium and low findings listed
6. Terminal summary shows `Security: FINDINGS: 1 medium, 2 low`

Confirm each step is covered.

- [ ] **Step 4: Trace the security-agent disabled path**

Mentally trace a run where `.nob.yml` has `security-agent` removed from `agents.enabled`:
1. Phase 2.5 checks `security-agent` not in `agents.enabled` → skips the entire phase
2. SECURITY_OUTPUT is never set
3. Phase 3 Reviewer dispatch still includes `Security Agent output: {SECURITY_OUTPUT}` — but SECURITY_OUTPUT is undefined/empty
4. Reviewer Step 3.6 finds neither block → sets SECURITY_STATUS = "NOT RUN"
5. Reviewer output shows `Security: NOT RUN — security agent output missing`

Verify this edge case is handled. If SECURITY_OUTPUT being undefined causes an issue with the Reviewer inputs block, the Phase 2.5 skip guard should set `SECURITY_OUTPUT = ""` so the input field is present but empty.

- [ ] **Step 5: Fix the skip-guard to set SECURITY_OUTPUT empty string**

In `skills/nob/SKILL.md`, find the Phase 2.5 skip guard:

```
Skip this phase if `security-agent` is not in `agents.enabled`.
```

Replace with:

```
If `security-agent` is not in `agents.enabled`: set SECURITY_OUTPUT = "" and skip the rest of this phase. Proceed to Phase 3.
```

- [ ] **Step 6: Commit verification fixes**

```bash
git add skills/nob/SKILL.md
git commit -m "fix: security-agent skip guard sets SECURITY_OUTPUT to empty string"
```
