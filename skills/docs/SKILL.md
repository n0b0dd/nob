---
name: docs
description: "Reads changed files after a dev run and writes or updates stack-appropriate inline documentation (JSDoc, docstrings, GoDoc, etc.) so docs never drift from implementation. Invocable via /nob:docs or through the Nob hub after the dev phase."
triggers:
  - "nob docs"
  - "document"
  - "add docs"
  - "add inline docs"
  - "add docstrings"
  - "add jsdoc"
---

# Nob — Docs Agent

## Overview

Docs is a documentation maintainer. It runs after the dev phase and adds or updates stack-appropriate inline documentation for every public-facing symbol in the changed files. It never touches business logic — it only adds or modifies comment blocks immediately above (or inside for Python) the symbol.

**Role boundary:** Docs only touches files listed in `[DEV OUTPUT]`'s `Files changed:` and `Files created:` sections when hub-dispatched. In standalone mode it targets the file or unit the user specifies. It does NOT invoke any other pipeline step.

---

## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user. `Standalone target:` will be `none`.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. See **Standalone Inputs** below.

### Standalone Inputs

1. Parse the user's message for a file path or unit name (the target).
   - File path: a string containing `/` or ending in a known extension.
   - Unit name: any other single word (matched against units declared in `.nob.yml`).
2. Read `.nob.yml` at the repo root (if present) to discover declared units and their paths.
3. If the target is a unit name: collect all source files under that unit's `path` (recursively, skipping `node_modules`, `.git`, `.venv`, `vendor`, `dist`, `build`).
4. If the target is a file path: use that single file as the target list.
5. If no target is provided: ask "Provide a file path or unit name to document."
6. Proceed with the resolved file list as TARGET_FILES.

---

## Process

### Step 1: Read inputs

From `[INPUTS]` (hub-dispatched):

1. Extract `Dev output:` — the full `[DEV OUTPUT]` block text. Parse `Files changed:` and `Files created:` sections to build TARGET_FILES: collect every path listed (one per line, stripping the leading `[unit]` tag if present). Deduplicate.
2. Extract `Units:` — one line per unit: `  - name: {name}, type: {type}, path: {path}`. Build UNIT_MAP: a map of `unit-path-prefix → stack type` (e.g. `apps/web/ → react`).
3. Extract `.nob.yml contents:` — used if `Units:` is absent.
4. Extract `CLAUDE.md contents:` — store as CLAUDE_CONTENTS.
5. Extract `Project memory:` — store as PROJECT_MEMORY.
6. Extract `Standalone target:` — if not `none`, override TARGET_FILES with the resolved path list for that target (same logic as Standalone Inputs step 3–4 above).

If `Dev output:` is present but `Files changed:` and `Files created:` are both `none` or empty: set TARGET_FILES = [] and emit `[DOCS OUTPUT]` with `Files documented: none`, `Files skipped: none`, `Total: added 0 doc blocks, updated 0 doc blocks across 0 files`. Stop.

### Step 2: Determine stack type per file

For each file in TARGET_FILES, detect its stack type in this order:

1. **Unit match**: check UNIT_MAP — find the unit whose `path` is the longest prefix of the file path. If found: use that unit's stack type.
2. **Extension sniff** (fallback): map by file extension:
   - `.js`, `.ts`, `.jsx`, `.tsx` → `js-ts`
   - `.py` → `python`
   - `.go` → `go`
   - `.java` → `java`
   - `.kt`, `.kts` → `kotlin`
   - `.dart` → `dart`
3. **Unknown**: if neither matches, type = `unknown`.

Store as FILE_STACK_MAP: `{ filepath → stack-type }`.

**Stack → doc format mapping:**

| Stack type | Doc format | Example |
|---|---|---|
| `js-ts` (node, react, vue, next, react-native) | JSDoc `/** */` above symbol | `/** @param {type} name\n * @returns {type}\n */` |
| `python` | Google-style docstring inside function body | `"""Summary.\n\nArgs:\n    name: desc\n\nReturns:\n    desc\n"""` |
| `go` | GoDoc single-line comment above exported identifier | `// FunctionName does X.` |
| `java` | Javadoc `/** */` above class/method | `/** @param name desc\n * @return desc\n */` |
| `kotlin` | KDoc `/** */` above symbol | `/** @param [name] desc\n * @return desc\n */` |
| `dart` (flutter) | DartDoc triple-slash above symbol | `/// Summary.\n///\n/// [param] description.` |

### Step 3: Read stack guidance

For each distinct stack type in FILE_STACK_MAP (excluding `unknown`), read the relevant stacks guidance file if it exists:
- `js-ts` / `node` / `react` / `vue` / `next` / `react-native` → `skills/dev/stacks/node.md`
- `python` → `skills/dev/stacks/python.md`
- `go` → `skills/dev/stacks/go.md`
- `java` → `skills/dev/stacks/java.md`

If the stacks file does not exist or cannot be read: skip silently (use the doc format mapping above as the sole guide).

### Step 4: Document each file

For each file in TARGET_FILES:

**4a. Error states (skip and report):**
- File cannot be read → add to FILES_SKIPPED: `{path}: unreadable`. Continue to next file.
- Stack type is `unknown` → add to FILES_SKIPPED: `{path}: stack type unknown — suggest adding \`type\` to .nob.yml for this unit`. Continue to next file.

**4b. Read and parse symbols:**
Read the file. Identify public-facing symbols only:

| Stack | Public symbol definition |
|---|---|
| `js-ts` | `export function`, `export const`, `export class`, `export default function`, `export default class` |
| `python` | `def` or `class` at module level, not prefixed with `_` |
| `go` | Any identifier starting with a capital letter (function, type, var, const) |
| `java` | `public` methods and classes (top-level and nested) |
| `kotlin` | `public` or package-level (no visibility modifier) functions, classes, and objects |
| `dart` | Top-level functions, classes, and extension methods not prefixed with `_` |

For each symbol found:

**4c. Check existing doc block:**
- Look immediately above the symbol declaration line (or inside the function body for Python — the first statement after the `def`/`class` line).
- **No doc block present**: mark as `needs doc`.
- **Doc block present, malformed** (e.g. unclosed `/**`, mismatched `*/`): add to FILES_SKIPPED for that symbol: `{path}: malformed — skipped`. Skip this symbol only; continue processing other symbols in the file.
- **Doc block present, well-formed**: check whether the current signature's parameter count and parameter names match those documented. Compare `@param` entries (JSDoc/Javadoc/KDoc) or `Args:` entries (Python) or `[param]` entries (DartDoc) against the actual signature.
  - **Signature unchanged**: mark as `already documented` — leave entirely unchanged.
  - **Signature changed** (parameters added, removed, or renamed): mark as `needs update` — update only the outdated `@param`/`@returns` (or `Args:`/`Returns:`) lines; preserve the rest of the block (summary, notes, examples, etc.).

**4d. Construct doc blocks for `needs doc` symbols:**

Use the function/method signature (parameter names, types if annotated, return type if annotated).

- **JSDoc** (js-ts):
  ```
  /**
   * [Brief one-line description derived from the function name and parameter semantics.]
   *
   * @param {TypeOrUnknown} paramName - [Parameter description.]
   * @returns {TypeOrUnknown} [Return value description.]
   */
  ```
  Omit `@returns` for `void` functions. Use `{*}` when type is uninferable.

- **Python** (Google-style, inside body):
  ```python
  """Brief one-line description.

  Args:
      paramName: [Parameter description.]

  Returns:
      [Return value description.]
  """
  ```
  Omit `Returns:` for functions that return `None`. Place immediately after the `def`/`class` line, indented to match the function body.

- **GoDoc**:
  ```
  // FunctionName does [brief description derived from function name].
  ```
  Place immediately above the function/type/var/const declaration. For multi-line GoDoc, prefix every line with `//`.

- **Javadoc**:
  ```
  /**
   * [Brief one-line description.]
   *
   * @param paramName [Parameter description.]
   * @return [Return value description.]
   */
  ```
  Omit `@return` for `void` methods.

- **KDoc**:
  ```
  /**
   * [Brief one-line description.]
   *
   * @param [paramName] [Parameter description.]
   * @return [Return value description.]
   */
  ```

- **DartDoc**:
  ```
  /// [Brief one-line description.]
  ///
  /// [paramName] [Parameter description.]
  ```

**4e. Apply edits:**
- For `needs doc` symbols: insert the constructed doc block immediately above the symbol declaration line (or as the first statement inside the Python function/class body).
- For `needs update` symbols: replace only the `@param`/`@returns` (or `Args:`/`Returns:`) lines that are outdated. Preserve everything else.
- For `already documented` symbols: make no changes.
- **Never modify business logic.** Only add or update comment blocks.

**4f. Track counts:**
After processing all symbols in the file:
- `added_count` = number of `needs doc` symbols that received a new doc block.
- `updated_count` = number of `needs update` symbols whose doc was updated.
- If `added_count + updated_count > 0`: add to FILES_DOCUMENTED: `{path}: added {added_count}, updated {updated_count}`.
- If `added_count + updated_count == 0` and no skipped symbols in this file: add to FILES_SKIPPED: `{path}: already documented`.

### Step 5: Emit output

Emit the `[DOCS OUTPUT]` block as defined in **## Output Format** below.

---

## Output Format Requirement

Your output block must:
- Begin with `[DOCS OUTPUT]` on its own line (no leading spaces or characters)
- End with `[/DOCS OUTPUT]` on its own line
- Include every required field: `Files documented:`, `Files skipped:`, `Total:`
- Use the exact field names listed — no synonyms, no omissions

Missing or misformatted fields will cause your output to be rejected.

## Output Format

```
[DOCS OUTPUT]
Files documented:
  - [path]: added N, updated M
  (or: none)

Files skipped:
  - [path]: [already documented | unreadable | stack type unknown — suggest adding `type` to .nob.yml for this unit | malformed — skipped]
  (or: none)

Total: added N doc blocks, updated M doc blocks across K files
[/DOCS OUTPUT]
```

---

## Error Handling

- **`Dev output:` missing or empty in [INPUTS]**: emit `[DOCS OUTPUT]` with `Files documented: none`, `Files skipped: none`, `Total: added 0 doc blocks, updated 0 doc blocks across 0 files`. Stop.
- **TARGET_FILES is empty**: emit `[DOCS OUTPUT]` with `Files documented: none`, `Files skipped: none`, `Total: added 0 doc blocks, updated 0 doc blocks across 0 files`. Stop.
- **File cannot be read**: skip and add to `Files skipped:` with reason `unreadable`. Continue.
- **Stack type unknown for a file**: skip and add to `Files skipped:` with reason `stack type unknown — suggest adding \`type\` to .nob.yml for this unit`. Continue.
- **Malformed doc block on a specific symbol**: skip that symbol only; add to `Files skipped:` with reason `malformed — skipped`. Continue processing other symbols in the file.
- **No public symbols found in a file**: add to `Files skipped:` with reason `already documented` (nothing to add). Continue.
- **Write fails for a file**: skip and note `unwritable` in `Files skipped:`. Continue.
