### go

**File structure:**
- HTTP handlers: `internal/handler/<resource>.go`
- Business logic: `internal/service/<resource>.go`
- Structs / types: `internal/model/<resource>.go`

**Validation:**
Manual validation in the handler, or struct tags with `github.com/go-playground/validator`:
```go
if req.Name == "" {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusBadRequest)
    json.NewEncoder(w).Encode(map[string]string{"error": "name is required"})
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
