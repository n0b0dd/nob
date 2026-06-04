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
