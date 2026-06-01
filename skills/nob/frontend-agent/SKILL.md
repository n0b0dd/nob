---
name: nob-frontend-agent
description: Use when implementing UI/frontend changes in a Nob workflow. Reads [PM-AGENT OUTPUT] and [BACKEND-AGENT OUTPUT] to understand what to build, explores existing frontend codebase, adapts to any stack declared in .nob.yml, and outputs a structured [FRONTEND-AGENT OUTPUT] block. Part of the Nob skill hub.
---

# Nob — Frontend Agent

## Overview
Implement frontend changes by reading requirements from context blocks and the existing codebase. Adapt implementation approach based on `stack.frontend.type` in `.nob.yml`. Never invent patterns — read and follow what already exists.

## Process

### Step 1: Read configuration
Get `stack.frontend.type` and `stack.frontend.path` from the `.nob.yml contents` field in your `[INPUTS]` block. Do not read `.nob.yml` from disk — the hub has already resolved it.

Then adapt your approach based on type:
- **react / vue / next**: look for component files, hooks, API service files under `{path}/src/`
- **flutter**: look for widget files, providers, API client under `{path}/lib/`
- **android**: look for Activities/Fragments, ViewModels, Retrofit interfaces under `{path}/app/src/`
- **ios**: look for SwiftUI views or ViewControllers, network layer under `{path}/`
- **react-native**: look for screens, navigation, API hooks under `{path}/src/`

### Step 1.5: Select stack guidance
Read `stack.frontend.type` from your `[INPUTS]`. Find the matching subsection under `## Stack-specific guidance` at the bottom of this file and use it as your default implementation pattern. If your stack type has no matching subsection, skip this step and rely on codebase exploration alone. Once you read the codebase in Step 4, prefer whatever patterns already exist there — the guidance is a starting point, not a rule.

### Step 2: Read CLAUDE.md
Read `CLAUDE.md` for frontend conventions: component pattern, state management, API client location, styling approach.

### Step 3: Read context blocks
From the current session context:
1. Find and read `[PM-AGENT OUTPUT]` — extract "Frontend changes needed"
2. Find and read `[BACKEND-AGENT OUTPUT]` — extract "New API contracts" and "Updated API contracts"

Use the API contracts from [BACKEND-AGENT OUTPUT] as the source of truth for what endpoints to call. Do NOT assume or invent API contracts.

If there is no [PM-AGENT OUTPUT] in context, stop and output: "Frontend Agent cannot proceed — no [PM-AGENT OUTPUT] found in context."

### Step 4: Explore existing frontend codebase
Before writing any code, read at minimum:
- One existing component/screen/widget similar in complexity to what you are building
- The API client or service file to understand how API calls are made
- The routing/navigation file to understand how screens are registered

Do NOT skip this step. Implementing without reading leads to pattern violations.

### Step 5: Implement
Write the minimum code to satisfy "Frontend changes needed" from [PM-AGENT OUTPUT]. Follow the exact patterns observed in Step 4:
- Same component/widget structure
- Same API client usage
- Same state management approach
- Same styling method

## Output Format

```
[FRONTEND-AGENT OUTPUT]
Stack type: [from .nob.yml]
Frontend path: [from .nob.yml]

Files changed:
- [exact/path/to/file]: [one-sentence reason]

Files created:
- [exact/path/to/file]: [one-sentence reason]

API endpoints consumed:
- [METHOD] [/path]: [how it is used in the UI]

Tests written:
- [exact/path/to/test file]: [what is tested, or: none]

Items not implemented (needs human):
- [specific item and reason, or: none]
[/FRONTEND-AGENT OUTPUT]
```

## Error Handling
- **No [PM-AGENT OUTPUT] in context**: stop with message above
- **No [BACKEND-AGENT OUTPUT] in context**: proceed with API contracts inferred from [PM-AGENT OUTPUT], note "No [BACKEND-AGENT OUTPUT] found — API contracts inferred from spec"
- **.nob.yml frontend.enabled is false**: output "Frontend Agent skipped — frontend disabled in .nob.yml"
- **Stack type not recognized**: default to reading generic source files and flag: "Unrecognized stack type [X] — treated as generic file-based project"

---

## Stack-specific guidance

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

---

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

---

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

---

### flutter

**File structure:**
- Full screens: `lib/screens/<resource>_screen.dart`
- Reusable widgets: `lib/widgets/<name>_widget.dart`
- API/data service: `lib/services/<resource>_service.dart`
- Data models: `lib/models/<resource>.dart`

**State management:**
`Provider` or `Riverpod`. For Provider: extend `ChangeNotifier`, expose via `ChangeNotifierProvider` in the widget tree. For Riverpod: `StateNotifierProvider` with `StateNotifier` subclass.

**API client:**
`http` or `dio` package. Service class with typed async methods:
```dart
Future<Item> createItem(CreateItemInput input) async {
  final res = await _client.post('/items', data: input.toJson());
  return Item.fromJson(res.data);
}
```

**Routing:**
`MaterialApp` routes map for simple apps; `go_router` for named routes:
```dart
GoRoute(path: '/items', builder: (context, state) => const ItemsScreen()),
```

**Test pattern:**
`flutter_test`:
```dart
testWidgets('shows item name', (tester) async {
  await tester.pumpWidget(MaterialApp(home: ItemCard(item: mockItem)));
  expect(find.text(mockItem.name), findsOneWidget);
});
```
Run: `cd {frontend.path} && flutter test`

---

### android

**File structure:**
- Activities / Fragments: `app/src/main/java/{pkg}/ui/<feature>/`
- ViewModels: `app/src/main/java/{pkg}/viewmodel/<Feature>ViewModel.kt`
- Repository + API: `app/src/main/java/{pkg}/data/`
- Navigation graph: `app/src/main/res/navigation/nav_graph.xml`

**State management:**
`ViewModel` + `StateFlow` (preferred) or `LiveData`. ViewModel exposes `StateFlow<UiState>`; Fragment collects it in `lifecycleScope.launch`.

**API client:**
Retrofit interface in `data/remote/<Resource>Api.kt`:
```kotlin
interface ItemApi {
    @POST("items")
    suspend fun createItem(@Body request: CreateItemRequest): ItemResponse
}
```

**Routing:**
Add a `<fragment>` destination to the nav graph XML, then navigate with `findNavController().navigate(R.id.action_...)`.

**Test pattern:**
`JUnit4` + `MockK` for unit tests; `Espresso` for UI tests:
```kotlin
@Test fun `createItem returns success`() = runTest {
    coEvery { api.createItem(any()) } returns mockResponse
    val result = viewModel.createItem(input)
    assertEquals(Result.Success(mockResponse), result)
}
```
Run: `cd {frontend.path} && ./gradlew test`

---

### ios

**File structure:**
- SwiftUI views: `<Feature>/Views/<FeatureName>View.swift`
- View models: `<Feature>/ViewModels/<FeatureName>ViewModel.swift`
- Network services: `Services/<Resource>Service.swift`
- Models: `Models/<Resource>.swift`

**State management:**
`@State` for local view state. `@StateObject` / `@ObservedObject` for `ObservableObject` view models. `@EnvironmentObject` for app-wide shared state.

**API client:**
`URLSession` with `async/await` in a service class:
```swift
func createItem(_ input: CreateItemInput) async throws -> Item {
    var request = URLRequest(url: baseURL.appendingPathComponent("items"))
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(input)
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(Item.self, from: data)
}
```

**Routing:**
`NavigationStack` with `.navigationDestination(for:)` for type-safe routing, or `NavigationLink` for simple cases.

**Test pattern:**
`XCTest`:
```swift
func testCreateItem() async throws {
    let item = try await service.createItem(mockInput)
    XCTAssertEqual(item.name, mockInput.name)
}
```
Run: `xcodebuild test -scheme {AppScheme} -destination 'platform=iOS Simulator,name=iPhone 15'`

---

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
