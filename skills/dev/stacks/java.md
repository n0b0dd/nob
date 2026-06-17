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
    String msg = ex.getBindingResult().getFieldErrors().stream()
        .map(e -> e.getField() + ": " + e.getDefaultMessage())
        .collect(Collectors.joining("; "));
    return ResponseEntity.badRequest().body(Map.of("error", msg));
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
Run: If `./mvnw` exists: `cd {backend.path} && ./mvnw test`. If `./gradlew` exists: `cd {backend.path} && ./gradlew test`.

**Auth pattern:**
`@PreAuthorize` on the controller method, or `SecurityFilterChain` bean in a `@Configuration` class:
```java
@PreAuthorize("isAuthenticated()")
@GetMapping("/me")
public UserResponse getMe(...) { ... }
```
