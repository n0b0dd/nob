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
Run: `xcodebuild test -scheme {AppScheme} -destination 'platform=iOS Simulator,name=iPhone 16'`
Note: replace `iPhone 16` with a simulator available on the machine (`xcrun simctl list devices available` to check).
