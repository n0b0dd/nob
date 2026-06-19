# Technical Design: [feature name]

<!--
Engineering design authored by the Tech Lead, derived from the PRD at [spec/PRD path].
The PRD owns the *what/why* (requirements, acceptance criteria). This document owns
the *how* (interfaces, schemas, task breakdown). Implementation (dev) and review
trace back to this design + the PRD's acceptance criteria.
-->

## Affected units
[comma-separated unit names]

## Interfaces / contracts
- [producing unit] → [consuming unit(s)]: [METHOD /path | type name] request: `{ fieldName: type }` → response: `{ fieldName: type }`
<!-- or: none -->

## Data schemas
- [EntityName]: `{ fieldName: type, ... }`  <!-- map to a table/collection if known -->
<!-- or: none -->

## Task list
- id: t1
  title: [short title]
  unit: [unit name from .nob.yml units list]
  files: [known target paths, or: unknown]
  depends_on: [list of task ids, or: empty]
<!-- one block per task; ids stable in acceptance-criteria order -->

## Risks
- [AUTH | MIGRATION | BREAKING | SHARED] [description]
<!-- or: none -->

## Third-party API notes
- [service name]: [resolved API shape / endpoint, or: none]
<!-- or: none -->
