---
name: lint
description: "Run the skill-contract linter to validate the Nob plugin's internal contracts (sub-skill paths, output blocks, required fields). Triggers on: 'nob lint', 'lint skills', 'check skill contracts', 'validate skills'."
---

# Nob — Skill-Contract Linter

## Overview
Runs `tools/lint-skills.sh` against the plugin repo to validate that all skill contracts are intact:
- Every sub-skill path the hub references exists on disk.
- Every producing sub-skill emits the `[X OUTPUT]` / `[/X OUTPUT]` block the hub expects.
- Every required field named in the hub's Output Block Validation table appears in the corresponding sub-skill.
- No `[X OUTPUT]` block is referenced by the hub without a known producing sub-skill.

Reports each violation with file path and a one-line reason. Exits non-zero on any error so CI can use the exit code directly.

---

## Step 1: Resolve repo root

Read the system context for a line starting with `Base directory for this skill:`. Extract the path and store it as SKILL_BASE_DIR. The repo root is two levels up: `{SKILL_BASE_DIR}/../..`.

Store as REPO_ROOT.

---

## Step 2: Run the linter

Run via the Bash tool:

```bash
bash {REPO_ROOT}/tools/lint-skills.sh {REPO_ROOT}
```

Capture stdout, stderr, and the exit code.

---

## Step 3: Report results

Print the full output of the linter verbatim.

If exit code is 0: print "lint-skills: all contracts are valid."

If exit code is non-zero: print the violations and the summary line, then print:
```
Run `tools/lint-skills.sh` locally to reproduce.
Fix each violation listed above before merging.
```

---

## Error Handling

- **Script not found** (`tools/lint-skills.sh` does not exist): print "lint-skills: ERROR: tools/lint-skills.sh not found — is the plugin installed correctly?" and exit.
- **Script not executable**: run `bash {REPO_ROOT}/tools/lint-skills.sh {REPO_ROOT}` (explicit bash invocation) to avoid permission errors.
- **Script exits with unexpected error** (exit code > 1): print raw output and note "lint-skills encountered an unexpected error — check the script directly."
