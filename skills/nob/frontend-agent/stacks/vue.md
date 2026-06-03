### vue

**File structure:**
- Reusable components: `src/components/<ComponentName>.vue`
- Page-level views: `src/views/<PageName>.vue`
- Pinia stores: `src/stores/use<Resource>Store.ts`
- API service files: `src/api/<resource>.ts`

**State management:**
Pinia — `defineStore('resource', () => { ... })` composition-style store. Read existing stores before adding one.

**API client:**
`axios` instance in `src/api/axios.ts`, per-resource files export typed functions:
```ts
export const fetchItems = () => axiosInstance.get<Item[]>('/items').then(r => r.data);
```

**Routing:**
Add to `src/router/index.ts`:
```ts
{ path: '/items', name: 'items', component: () => import('@/views/ItemsView.vue') }
```

**Test pattern:**
`@vue/test-utils` + `vitest`:
```ts
it('shows item name', () => {
  const wrapper = mount(ItemCard, { props: { item: mockItem } });
  expect(wrapper.text()).toContain(mockItem.name);
});
```
Run: `cd {frontend.path} && npx vitest run`
