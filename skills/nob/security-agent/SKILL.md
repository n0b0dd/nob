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
