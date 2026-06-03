### react-native

**File structure:**
- Screen components: `src/screens/<ScreenName>.tsx`
- Reusable UI: `src/components/<ComponentName>.tsx`
- Navigation config: `src/navigation/<Stack|Tab>Navigator.tsx`
- API service files: `src/services/<resource>.ts`

**State management:**
`useState` / `useReducer` for local state. `zustand` or `Redux Toolkit` for shared state. Read existing store setup before adding.

**API client:**
`axios` instance in `src/services/api.ts`, per-resource files:
```ts
export const createItem = (data: CreateItemInput) =>
  apiClient.post<Item>('/items', data).then(r => r.data);
```

**Routing:**
`@react-navigation` — add screen to `Stack.Navigator` or `Tab.Navigator`:
```tsx
<Stack.Screen name="Items" component={ItemsScreen} />
```

**Test pattern:**
`@testing-library/react-native` + `jest`:
```tsx
it('renders item name', () => {
  const { getByText } = render(<ItemCard item={mockItem} />);
  expect(getByText(mockItem.name)).toBeTruthy();
});
```
Run: `cd {frontend.path} && npm test -- --watchAll=false`
