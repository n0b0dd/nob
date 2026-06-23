# Feature: [Name — short noun phrase, e.g. "User Login", "Invoice Export"]

## Summary
[One sentence. What is being built and for whom. e.g. "Allow authenticated users to export their invoices as PDF from the billing page."]

## Users
[Who triggers this feature. e.g. "Authenticated users with at least one invoice on their account."]

## Platform targets
- [ ] Web
- [ ] Mobile iOS
- [ ] Mobile Android
<!-- Check all that apply. Unchecked platforms are out of scope for this feature. -->

## User flow
1. [First action the user takes]
2. [System response or next step]
3. [Continue until the happy path ends]
<!-- Alt paths: describe branches inline. e.g. "If no invoices exist, show empty state." -->

## Requirements
- [Single-responsibility requirement. e.g. "PDF includes invoice number, date, line items, and total."]
- [One line per requirement. Split "X and Y" into two separate lines.]

## Data
<!-- Name the entities this feature creates, reads, or changes. One line per entity.
     Don't specify fields or schema — that's the Tech Lead's job. -->
- [EntityName]: [what it represents and why it's needed — e.g. "Invoice: a record of a completed purchase"]
<!-- Or: not applicable -->

## Design resources
<!-- Link any existing Figma frames or assets. The Designer agent produces the full UI spec from these + the requirements above. -->
- Figma: [URL — or: not provided]
- Assets: [path/to/asset or Figma link — or: not provided]

## Acceptance criteria
- [ ] [Specific, testable behavior. e.g. "Authenticated user can download their invoice as a PDF"]
- [ ] [Web: e.g. "Export button is disabled while the request is in flight"]
- [ ] [Mobile: e.g. "iOS ExportScreen shows an activity indicator during export"]
- [ ] [Error: e.g. "Accessing another user's invoice shows an 'Access denied' message"]
<!-- RULES:
     1. This section is REQUIRED — the pipeline halts without it.
     2. One thing per criterion. "X and Y" → two criteria.
     3. Label platform-specific criteria: "[Web]", "[iOS]", "[Android]" prefix when mixed.
     4. Each criterion must be verifiable by reading a file.
     5. Cover: happy path, at least one error state, auth requirement, loading state.
-->

## Builds on
[Existing features, screens, or files this extends. e.g. "BillingPage (apps/frontend/src/pages/billing.tsx), Invoice model (apps/backend/src/models/invoice.ts)"]
<!-- Or: none -->

## Constraints
[Hard constraints. e.g. "No new npm packages. Must work offline on mobile. Response under 200ms at p99."]
<!-- Or: none -->

## Error states
- [Error condition]: [Expected user-visible behavior. e.g. "Invoice not found: show 'Invoice not found' and a back button"]
- [Error condition]: [Expected user-visible behavior. e.g. "Export fails: show toast 'Export failed, try again'"]
<!-- Or: none specified -->

## Out of scope
- [Explicitly excluded. e.g. "Bulk export is out of scope."]
<!-- Or: none specified -->

## Open questions
- [Unresolved decision. e.g. "Should PDF generation be server-side or via PDFShift?"]
<!-- Or: none -->
<!-- Resolve before running /nob — open questions become blocking ambiguities flagged by the PM agent. -->
