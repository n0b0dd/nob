# Technical Design: [feature name]

<!--
Engineering design authored by the Tech Lead, derived from the PRD at [spec/PRD path].
The PRD owns the *what/why* (requirements, acceptance criteria). This document owns
the *how* (interfaces, schemas, task breakdown). Implementation (dev) and review
trace back to this design + the PRD's acceptance criteria.

One ## section per unit from .nob.yml — e.g. api, web, ios, android, flutter, cli.
Data schemas only appear under units that own persisted data (typically backend units).
-->

## Interfaces / contracts
<!-- Cross-unit contracts. One line per endpoint or shared type.
     [producing unit] → [consuming unit(s)] -->
- [producing unit] → [consuming unit(s)]: [METHOD /path | type name] request: `{ fieldName: type }` → response: `{ fieldName: type }`
<!-- or: none -->

## [unit-name]
<!-- Repeat this section for each unit from .nob.yml that this feature touches -->

### Data schemas
<!-- Only include for units that own persisted data. Otherwise remove this subsection. -->
- [EntityName]: `{ fieldName: type, ... }`  <!-- map to a table/collection if known -->
<!-- or: none -->

### Tasks
- id: t1
  title: [short imperative label — e.g. "Add exportPdf service method"]
  file: [exact file path — one primary file per task; prefer one task per file]
  action: create | edit | delete
  what: [one concrete sentence: what function/endpoint/component to add or change and its exact behavior]
  exports: [what this task produces for others — e.g. "exportPdf(invoiceId, userId): Promise<Buffer>" or "POST /invoices/:id/export", or: none]
  depends_on: []
<!-- One block per task. Keep scope tight: one responsibility, one file.
     "what" must be specific enough for a focused agent to implement without reading the rest of this doc. -->

## [unit-name-2]
<!-- Additional unit section — add as many as needed; remove this block if only one unit -->

### Tasks
- id: t2
  title: [short imperative label]
  file: [exact file path]
  action: create | edit | delete
  what: [one concrete sentence describing the implementation]
  exports: [what this task produces, or: none]
  consumes: [t1 → exportPdf(invoiceId, userId): Promise<Buffer>]
  depends_on: [t1]
<!-- consumes: lists what this task needs from its dependencies — taskId → exported symbol/endpoint.
     Omit if depends_on is empty. -->

## Risks
- [AUTH | MIGRATION | BREAKING | SHARED] [description]
<!-- or: none -->

## Third-party API notes
- [service name]: [resolved API shape / endpoint, or: none]
<!-- or: none -->
