### next

**File structure:**
- Server components (default): `app/<route>/page.tsx`
- Client components (interactive): `app/<route>/<Component>.tsx` with `'use client'` at top
- API route handlers: `app/api/<resource>/route.ts`
- Shared UI: `components/<ComponentName>.tsx`

**State management:**
Server state via `fetch` directly in server components (no client lib needed). Client state via `useState`. Shared client state via `zustand` or `Context`.

**API client:**
In server components, use native `fetch()` with `{ cache: 'no-store' }` for dynamic data. In client components, use `fetch` or `axios` in a service file.

**Routing:**
File-based — create `page.tsx` in the correct `app/` subdirectory. For dynamic routes: `app/items/[id]/page.tsx`.

**Test pattern:**
`@testing-library/react` + `jest` for client components. For server components or route handlers, use `jest` with `node` environment:
```ts
import { GET } from '@/app/api/items/route';
it('returns items', async () => {
  const res = await GET(new Request('http://test/api/items'));
  expect(res.status).toBe(200);
});
```
Run: `cd {frontend.path} && npm test -- --watchAll=false`
