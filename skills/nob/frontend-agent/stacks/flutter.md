### flutter

**File structure:**
- Full screens: `lib/screens/<resource>_screen.dart`
- Reusable widgets: `lib/widgets/<name>_widget.dart`
- API/data service: `lib/services/<resource>_service.dart`
- Data models: `lib/models/<resource>.dart`

**State management:**
`Provider` or `Riverpod`. For Provider: extend `ChangeNotifier`, expose via `ChangeNotifierProvider` in the widget tree. For Riverpod: `StateNotifierProvider` with `StateNotifier` subclass.

**API client:**
`dio` package (preferred for typed clients). Service class with typed async methods:
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
