# Technical Design: Skill-Contract Linter

<!--
Engineering design authored by the Tech Lead, derived from the PRD at docs/specs/2026-06-19-skill-contract-linter.md.
The PRD owns the *what/why* (requirements, acceptance criteria). This document owns
the *how* (interfaces, schemas, task breakdown). Implementation (dev) and review
trace back to this design + the PRD's acceptance criteria.
-->

## Affected units
root

## Interfaces / contracts

CLI contract for `tools/lint-skills.sh`:

```
Usage: tools/lint-skills.sh [REPO_ROOT]

Arguments:
  REPO_ROOT   Optional. Path to the repository root to lint.
              Defaults to the directory containing tools/ (resolved
              from the script's own location via $0).

Exit codes:
  0  — Clean: no violations found.
  1  — Violations found: one or more errors reported.

Output format (stdout):
  One violation per line:
    <relative-file-path>: <one-line reason>
  Summary line:
    lint-skills: N violation(s) found.   (exit 1)
    lint-skills: OK — no violations.     (exit 0)

Parse-level warnings (stdout, non-fatal):
  lint-skills: WARNING: <description>
```

No cross-unit HTTP interfaces or shared type interfaces — this is a self-contained shell tool.

## Data schemas
none

## Task list
- id: t1
  title: implement tools/lint-skills.sh (core linter)
  unit: root
  files: tools/lint-skills.sh
  depends_on: empty

- id: t2
  title: implement skills/lint/SKILL.md (thin skill wrapper)
  unit: root
  files: skills/lint/SKILL.md
  depends_on: t1

- id: t3
  title: implement .github/workflows/lint-skills.yml (CI workflow)
  unit: root
  files: .github/workflows/lint-skills.yml
  depends_on: t1

## Risks
none

## Third-party API notes
none
