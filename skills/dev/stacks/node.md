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
