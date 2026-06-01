# Agent Stack Specialization — Design Spec

**Date:** 2026-06-01
**Status:** Approved

## Summary

Add `## Stack-specific guidance` sections to `backend-agent`, `frontend-agent`, and `qa-agent` skill files. Each section contains subsections per supported stack type. Agents read the subsection matching their configured stack and apply it throughout implementation. This removes guesswork from agents that already know their stack but currently have no framework-specific guidance to draw on.

## Scope

Three agents are modified. Three are left unchanged.

| Agent | Change |
|---|---|
| `backend-agent` | Add stack-specific guidance section |
| `frontend-agent` | Add stack-specific guidance section |
| `qa-agent` | Add stack-specific guidance section (narrower: test commands + output patterns) |
| `planner` | No change |
| `pm-agent` | No change |
| `reviewer` | No change |

## Section Structure

Each `## Stack-specific guidance` section contains one subsection per supported stack type. Every subsection answers the same five questions for that stack:

1. **File structure** — where to place new files
2. **Validation** — how to validate request/form input
3. **Error format** — how to return errors consistently
4. **Test pattern** — test framework, fixture style, and run command
5. **Auth pattern** — how auth middleware or guards are wired

For `qa-agent`, each subsection is narrower: test command, how to run it, and how to interpret pass/fail output.

For `frontend-agent`, the five questions adapt to the UI domain:
1. **File structure** — where to place components/screens/widgets
2. **State management** — approach and library
3. **API client** — how API calls are made and where the client lives
4. **Routing** — how screens/pages are registered
5. **Test pattern** — testing library and pattern

### backend-agent stacks covered

- `node` (Express/Fastify)
- `python` (FastAPI/Django)
- `go`
- `java` (Spring Boot)

### frontend-agent stacks covered

- `react`
- `next`
- `vue`
- `flutter`
- `android`
- `ios`
- `react-native`

### qa-agent stacks covered

All of the above (backend + frontend), giving the QA agent the right test command and output interpretation for each.

## Agent Instruction Change

A new step is inserted into each affected agent's process, immediately after reading `.nob.yml` (Step 1) and before exploring the codebase:

> **Step 1.5: Select stack guidance**
> From your `[INPUTS]`, read `stack.backend.type` (or `stack.frontend.type`). Find the matching subsection under `## Stack-specific guidance` below and follow it throughout your implementation. If your stack type has no matching subsection, skip this step and rely on codebase exploration alone.

### Conflict resolution rule

Stack guidance supplements codebase exploration — it does not replace it. If the actual codebase contradicts the stack guidance (e.g., a Node project uses `joi` instead of `express-validator`), the codebase wins. This is consistent with the existing rule in `backend-agent` for CLAUDE.md discrepancies.

## What This Does Not Change

- Hub orchestration logic in `nob/SKILL.md` — no changes needed
- Agent dispatch prompts — no changes needed
- `.nob.yml` schema — no new fields
- `planner`, `pm-agent`, `reviewer` — untouched
- The "read and follow the existing codebase" steps in each agent — these remain and take precedence

## Success Criteria

- An agent on a Python backend produces Pydantic validation, `pytest` tests, and `HTTPException` error patterns without having to infer them from the codebase alone
- An agent on a Next.js frontend uses server components and route handlers without being told explicitly in the spec
- A QA agent on a Go project runs `go test ./...` and interprets its output correctly
- No regression for stacks not listed (agent falls back to codebase exploration only)
