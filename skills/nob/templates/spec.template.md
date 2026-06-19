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

## API contracts
<!-- Include when any HTTP endpoint is created or changed. Otherwise write: not applicable -->
- [METHOD] /exact/path
  - Request: `{ fieldName: type, fieldName: type }`
  - Response: `{ fieldName: type, fieldName: type }`
  - Auth: [required / not required / role: admin]
  - Notes: [idempotent? paginated? rate-limited?]
<!-- One block per endpoint. Unknown types: write `type: unknown` -->

## Data models
<!-- Include when any persisted data is created or changed. Otherwise write: not applicable -->
[EntityName]:
  - fieldName: type   # brief note
  - fieldName: type
<!-- One block per entity. Map to a table name if known. Don't invent fields — write "not specified". -->

## UI spec

### Web
<!-- Remove this section if Web is not checked in Platform targets -->

Route: /exact/path

Designer resources:
- Figma: [URL — or: not provided]
- Assets: [path/to/asset or Figma asset link — or: not provided]

Layout:
<!-- If Figma is provided: reference frame/page name. If not: describe layout in plain text. -->
- Desktop (>1024px): [description]
- Tablet (768–1024px): [description or "same as desktop"]
- Mobile (<768px): [description]

Components:
- [ComponentName] (`path/to/existing/component` or `new`):
  - Purpose: [what this component does in this feature]
  - Props: `{ propName: type }`
  - States: [loading | error | empty | populated | disabled]
  - Interactions: [e.g. "click Export button → POST /invoices/:id/export → show spinner → on success download file"]
  - Design notes: [spacing, color tokens, typography — or: follow design system defaults]

Navigation:
- [e.g. "Entry point: Billing page → Export button. No new route added."]
- [e.g. "Success: stay on page, show toast. Error: show inline error below button."]

---

### Mobile iOS
<!-- Remove this section if Mobile iOS is not checked in Platform targets -->

Screen: [ScreenName]
Navigation: [push | modal | tab | replace stack]

Designer resources:
- Figma: [URL — or: not provided]
- Assets: [path/to/asset or Figma asset link — or: not provided]

Layout:
<!-- If Figma is provided: reference frame/page name. If not: describe layout in plain text. -->
- [Layout description — safe area, scroll behavior, keyboard handling]

Components:
- [WidgetName / ComponentName] (`path/to/existing` or `new`):
  - Purpose: [what this component does in this feature]
  - Props/State: `{ fieldName: type }`
  - States: [loading | error | empty | populated]
  - Interactions: [e.g. "tap Export → show activity indicator → on success show confirmation sheet"]
  - iOS-specific notes: [swipe-to-dismiss, haptic feedback, SF Symbols icon name — or: none]

---

### Mobile Android
<!-- Remove this section if Mobile Android is not checked in Platform targets -->

Screen: [ScreenName]
Navigation: [push | modal | bottom sheet | replace]

Designer resources:
- Figma: [URL — or: not provided]
- Assets: [path/to/asset or Figma asset link — or: not provided]

Layout:
<!-- If Figma is provided: reference frame/page name. If not: describe layout in plain text. -->
- [Layout description — insets, scroll behavior, keyboard handling]

Components:
- [WidgetName / ComponentName] (`path/to/existing` or `new`):
  - Purpose: [what this component does in this feature]
  - Props/State: `{ fieldName: type }`
  - States: [loading | error | empty | populated]
  - Interactions: [e.g. "tap Export → show progress indicator → on success open share sheet"]
  - Android-specific notes: [back button behavior, Material component name — or: none]

---

## Acceptance criteria
- [ ] [Specific, testable. e.g. "GET /invoices/:id/pdf returns 200 with Content-Type: application/pdf"]
- [ ] [Frontend web: e.g. "Export button on InvoicePage is disabled while request is in flight"]
- [ ] [Frontend mobile: e.g. "iOS ExportScreen shows activity indicator during export"]
- [ ] [Error: e.g. "GET /invoices/:id/pdf returns 404 when invoice does not belong to requesting user"]
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
- [Error condition]: [Expected behavior. e.g. "Invoice not found: return 404 with { error: 'not_found' }"]
- [Error condition]: [Expected behavior. e.g. "Export fails: show toast 'Export failed, try again'"]
<!-- Or: none specified -->

## Out of scope
- [Explicitly excluded. e.g. "Bulk export is out of scope."]
<!-- Or: none specified -->

## Open questions
- [Unresolved decision. e.g. "Should PDF generation be server-side or via PDFShift?"]
<!-- Or: none -->
<!-- Resolve before running /nob — open questions become blocking ambiguities flagged by the PM agent. -->
