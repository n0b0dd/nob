### react

**File structure:**
- UI components: `src/components/<ComponentName>.tsx`
- Page-level components: `src/pages/<PageName>.tsx`
- Custom hooks: `src/hooks/use<Name>.ts`
- API service files: `src/services/<resource>.ts`

**State management:**
`useState` / `useReducer` for local state. For shared state use `Context` + `useReducer`, or `zustand` (`create()` store). Read existing stores before adding a new one.

**API client:**
`axios` instance or `fetch` wrapper in `src/services/api.ts`. Individual resource files call it:
```ts
export const createItem = (data: CreateItemInput) =>
  apiClient.post<Item>('/items', data).then(r => r.data);
```

**Routing:**
`react-router-dom` v6 — add a `<Route path="..." element={<Page />} />` inside the existing router in `src/App.tsx` or `src/router.tsx`.

**Test pattern:**
`@testing-library/react` + `jest`:
```tsx
it('renders item name', () => {
  render(<ItemCard item={mockItem} />);
  expect(screen.getByText(mockItem.name)).toBeInTheDocument();
});
```
Run: `cd {frontend.path} && npm test -- --watchAll=false`
