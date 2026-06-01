# Agent Stack Specialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stack-specific guidance sections to `backend-agent`, `frontend-agent`, and `qa-agent` so each agent receives opinionated, framework-level direction matched to the user's configured stack.

**Architecture:** Pure Markdown edits to three SKILL.md files. Each file gets a new `Step 1.5` instruction inserted after Step 1, and a `## Stack-specific guidance` section appended at the end. No hub changes, no new files, no build system.

**Tech Stack:** Markdown only — Edit tool for precise insertions.

---

### Task 1: Add stack guidance to backend-agent

**Files:**
- Modify: `skills/nob/backend-agent/SKILL.md`

- [ ] **Step 1: Insert Step 1.5 into backend-agent process**

Find the line `### Step 2: Read CLAUDE.md` in `skills/nob/backend-agent/SKILL.md` and insert the following block immediately before it:

```markdown
### Step 1.5: Select stack guidance
Read `stack.backend.type` from your `[INPUTS]`. Find the matching subsection under `## Stack-specific guidance` at the bottom of this file and follow it throughout your implementation. If your stack type has no matching subsection, skip this step and rely on codebase exploration alone. If the actual codebase contradicts the guidance (e.g., uses a different validation library), the codebase wins.

```

- [ ] **Step 2: Append the stack-specific guidance section to backend-agent**

Append the following block at the very end of `skills/nob/backend-agent/SKILL.md`:

```markdown
---

## Stack-specific guidance

### node

**File structure:**
- Route handlers: `src/routes/<resource>.js` (or `.ts`)
- Middleware: `src/middleware/`
- Models / data layer: `src/models/`

**Validation:**
Use `express-validator`. Declare `check()` chains in the route file, then call `validationResult(req)` at the top of the handler and return 422 if errors exist:
```js
const errors = validationResult(req);
if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });
```

**Error format:**
```js
res.status(400).json({ error: 'Human-readable message' });
```
Never throw — always return with `res`.

**Test pattern:**
`jest` + `supertest`. One `describe` block per route file. Use `beforeEach` to get a fresh app instance; use `afterAll` to close the server.
Run: `cd {backend.path} && npm test`

**Auth pattern:**
Middleware passed as the second argument to the router method:
```js
router.post('/resource', authMiddleware, handler);
```

---

### python

**File structure:**
- Route modules: `app/routers/<resource>.py`
- Pydantic request/response models: `app/schemas/<resource>.py`
- Business logic: `app/services/<resource>.py`
- FastAPI dependencies: `app/dependencies.py`

**Validation:**
Declare a Pydantic model as the function parameter type. FastAPI validates automatically and returns 422 on failure:
```python
class CreateItemRequest(BaseModel):
    name: str
    price: float

@router.post("/items")
async def create_item(body: CreateItemRequest):
    ...
```

**Error format:**
```python
raise HTTPException(status_code=400, detail="Human-readable message")
```

**Test pattern:**
`pytest` + `httpx.AsyncClient`. Use a `@pytest.fixture` that yields the async client:
```python
@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as c:
        yield c
```
Run: `cd {backend.path} && pytest -v`

**Auth pattern:**
FastAPI `Depends` injected as a function parameter:
```python
@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    ...
```

---

### go

**File structure:**
- HTTP handlers: `internal/handler/<resource>.go`
- Business logic: `internal/service/<resource>.go`
- Structs / types: `internal/model/<resource>.go`

**Validation:**
Manual validation in the handler, or struct tags with `github.com/go-playground/validator`:
```go
if req.Name == "" {
    http.Error(w, `{"error":"name is required"}`, http.StatusBadRequest)
    return
}
```

**Error format:**
```go
w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusBadRequest)
json.NewEncoder(w).Encode(map[string]string{"error": "Human-readable message"})
```

**Test pattern:**
Standard `testing` package with `net/http/httptest`:
```go
func TestCreateItem(t *testing.T) {
    req := httptest.NewRequest(http.MethodPost, "/items", body)
    rr := httptest.NewRecorder()
    handler(rr, req)
    if rr.Code != http.StatusCreated { t.Errorf(...) }
}
```
Run: `cd {backend.path} && go test ./...`

**Auth pattern:**
Middleware wraps the handler function:
```go
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // validate token, then:
        next(w, r)
    }
}
```

---

### java

**File structure:**
- Controllers: `src/main/java/{pkg}/controller/<Resource>Controller.java`
- Services: `src/main/java/{pkg}/service/<Resource>Service.java`
- Request/response DTOs: `src/main/java/{pkg}/dto/`
- JPA entities: `src/main/java/{pkg}/model/`

**Validation:**
`jakarta.validation` annotations on DTO fields, `@Valid` on the controller parameter:
```java
public record CreateItemRequest(@NotBlank String name, @Positive double price) {}

@PostMapping("/items")
public ResponseEntity<ItemResponse> create(@Valid @RequestBody CreateItemRequest req) { ... }
```

**Error format:**
`@ControllerAdvice` class with `@ExceptionHandler`:
```java
@ExceptionHandler(MethodArgumentNotValidException.class)
public ResponseEntity<Map<String,String>> handleValidation(MethodArgumentNotValidException ex) {
    return ResponseEntity.badRequest().body(Map.of("error", ex.getMessage()));
}
```

**Test pattern:**
`@WebMvcTest` + `MockMvc`:
```java
@WebMvcTest(ItemController.class)
class ItemControllerTest {
    @Autowired MockMvc mvc;

    @Test void shouldCreateItem() throws Exception {
        mvc.perform(post("/items").content(...).contentType(APPLICATION_JSON))
           .andExpect(status().isCreated());
    }
}
```
Run: `cd {backend.path} && ./mvnw test`

**Auth pattern:**
`@PreAuthorize` on the controller method, or `SecurityFilterChain` bean in a `@Configuration` class:
```java
@PreAuthorize("isAuthenticated()")
@GetMapping("/me")
public UserResponse getMe(...) { ... }
```
```

- [ ] **Step 3: Verify the edits are correct**

Read `skills/nob/backend-agent/SKILL.md` and confirm:
- `### Step 1.5: Select stack guidance` appears between Step 1 and Step 2
- `## Stack-specific guidance` section exists at the end of the file
- All four subsections exist: `### node`, `### python`, `### go`, `### java`
- Original Steps 1–6 and the Error Handling section are untouched

- [ ] **Step 4: Commit**

```bash
git add skills/nob/backend-agent/SKILL.md
git commit -m "feat: add stack-specific guidance to backend-agent"
```

---

### Task 2: Add stack guidance to frontend-agent

**Files:**
- Modify: `skills/nob/frontend-agent/SKILL.md`

- [ ] **Step 1: Insert Step 1.5 into frontend-agent process**

Find the line `### Step 2: Read CLAUDE.md` in `skills/nob/frontend-agent/SKILL.md` and insert the following block immediately before it:

```markdown
### Step 1.5: Select stack guidance
Read `stack.frontend.type` from your `[INPUTS]`. Find the matching subsection under `## Stack-specific guidance` at the bottom of this file and follow it throughout your implementation. If your stack type has no matching subsection, skip this step and rely on codebase exploration alone. If the actual codebase contradicts the guidance, the codebase wins.

```

- [ ] **Step 2: Append the stack-specific guidance section to frontend-agent**

Append the following block at the very end of `skills/nob/frontend-agent/SKILL.md`:

```markdown
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
```

- [ ] **Step 3: Verify the edits are correct**

Read `skills/nob/frontend-agent/SKILL.md` and confirm:
- `### Step 1.5: Select stack guidance` appears between Step 1 and Step 2
- `## Stack-specific guidance` section exists at the end of the file
- All seven subsections exist: `### react`, `### next`, `### vue`, `### flutter`, `### android`, `### ios`, `### react-native`
- Original Steps 1–5 and the Error Handling section are untouched

- [ ] **Step 4: Commit**

```bash
git add skills/nob/frontend-agent/SKILL.md
git commit -m "feat: add stack-specific guidance to frontend-agent"
```

---

### Task 3: Add stack guidance to qa-agent

**Files:**
- Modify: `skills/nob/qa-agent/SKILL.md`

- [ ] **Step 1: Insert Step 1.5 into qa-agent process**

Find the line `### Step 2: Read implementation output blocks` in `skills/nob/qa-agent/SKILL.md` and insert the following block immediately before it:

```markdown
### Step 1.5: Select stack guidance
Read `stack.backend.type` and `stack.frontend.type` from your `[INPUTS]`. Find the matching subsections under `## Stack-specific guidance` at the bottom of this file. Use the listed test commands and pass/fail interpretation for each stack. If a stack type has no matching subsection, fall back to the CLAUDE.md test command or the default `npm test`.

```

- [ ] **Step 2: Replace the hardcoded default commands in Steps 5 and 6**

In `### Step 5: Run backend tests`, replace the default command block:

Old:
```
cd {backend.path} && npm test
```

New:
```
Use the command from `## Stack-specific guidance` for `stack.backend.type`, or fall back to the CLAUDE.md test command.
```

In `### Step 6: Run frontend tests`, replace the default command block:

Old:
```
cd {frontend.path} && npm test
```

New:
```
Use the command from `## Stack-specific guidance` for `stack.frontend.type`, or fall back to the CLAUDE.md test command.
```

- [ ] **Step 3: Append the stack-specific guidance section to qa-agent**

Append the following block at the very end of `skills/nob/qa-agent/SKILL.md`:

```markdown
---

## Stack-specific guidance

### Backend stacks

#### node
**Command:** `cd {backend.path} && npm test`
**Pass:** Exit code 0; output contains `Tests: X passed`
**Fail:** Any line containing `FAIL` or `X failed`; capture the failing test name and error message

#### python
**Command:** `cd {backend.path} && pytest -v`
**Pass:** Last line contains `X passed` with no `failed` or `error` count
**Fail:** Any line starting with `FAILED`; capture test path and assertion message

#### go
**Command:** `cd {backend.path} && go test ./...`
**Pass:** Every package line starts with `ok`
**Fail:** Any line starting with `FAIL`; capture `--- FAIL: TestName` lines for details

#### java
**Command:** `cd {backend.path} && ./mvnw test`
**Pass:** `BUILD SUCCESS` and `Failures: 0, Errors: 0` in surefire summary
**Fail:** `BUILD FAILURE` or non-zero `Failures:` / `Errors:` count; capture failing test class and message

---

### Frontend stacks

#### react / react-native
**Command:** `cd {frontend.path} && npm test -- --watchAll=false`
**Pass:** Exit code 0; output contains `Tests: X passed`
**Fail:** Any line containing `FAIL` or `X failed`

#### next
**Command:** `cd {frontend.path} && npm test -- --watchAll=false`
**Pass / Fail:** Same as react above

#### vue
**Command:** `cd {frontend.path} && npx vitest run`
**Pass:** Output contains `X tests passed` with no failures line
**Fail:** Any line containing `X tests failed`; capture test name and diff

#### flutter
**Command:** `cd {frontend.path} && flutter test`
**Pass:** Final line is `All tests passed!`
**Fail:** Any line containing `FAILED`; capture test description and error

#### android
**Command:** `cd {frontend.path} && ./gradlew test`
**Pass:** `BUILD SUCCESSFUL` and no `X tests failed` in test summary
**Fail:** `BUILD FAILED` or non-zero failure count; check `build/reports/tests/` for HTML report path

#### ios
**Command:** `xcodebuild test -scheme {AppScheme} -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | xcpretty`
**Pass:** Final line is `** TEST SUCCEEDED **`
**Fail:** Final line is `** TEST FAILED **`; capture failing test class and assertion
```

- [ ] **Step 4: Verify the edits are correct**

Read `skills/nob/qa-agent/SKILL.md` and confirm:
- `### Step 1.5: Select stack guidance` appears between Step 1 and Step 2
- Steps 5 and 6 no longer hardcode `npm test` as the default
- `## Stack-specific guidance` section exists at the end with `### Backend stacks` and `### Frontend stacks` subsections
- All four backend stack entries exist: `#### node`, `#### python`, `#### go`, `#### java`
- All six frontend stack entries exist: `#### react / react-native`, `#### next`, `#### vue`, `#### flutter`, `#### android`, `#### ios`
- Original Steps 1–7 and the Error Handling section are otherwise untouched

- [ ] **Step 5: Commit**

```bash
git add skills/nob/qa-agent/SKILL.md
git commit -m "feat: add stack-specific guidance to qa-agent"
```
