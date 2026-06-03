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
`JUnit4` + `MockK` for ViewModel unit tests:
```kotlin
@Test fun `createItem updates uiState to Success`() = runTest {
    coEvery { api.createItem(any()) } returns mockResponse
    viewModel.createItem(input)
    assertEquals(UiState.Success(mockResponse), viewModel.uiState.value)
}
```
Run: `cd {frontend.path} && ./gradlew test`
