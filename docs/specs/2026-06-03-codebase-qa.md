# Natural Language Codebase Q&A ("Ask Before You Build")

## Problem statement
Before writing a spec or starting an implementation, developers routinely need to answer codebase questions: "Where is authentication handled?", "What pattern do we use for database queries?", "Does a user model already exist?". Nob's only entry points are implement, fix, ideate, init, venture, and refactor — there is no lightweight Q&A mode. Users must either explore the codebase manually or write a spec to find out whether the work is already done, which wastes a full pipeline run on work that may be redundant or need different scope.

## Proposed solution
Add an `Ask` workflow triggered by "nob ask [question]" or "ask [question]" intent. The hub dispatches a read-only agent that uses grep, directory listings, and targeted file reads to answer the question, then prints the answer with source file references. The agent writes nothing to disk. It uses the same discovery patterns the Planner already uses (grep for symbols, read package.json, scan routes) but is scoped purely to answering the user's question. The result is a 1–10 line answer with cited file paths, returned in under 30 seconds on a haiku model.

## Acceptance criteria
- "nob ask [question]" triggers the Ask workflow (no clarifying question needed)
- A read-only agent is dispatched with the user's question and the working directory
- The agent uses only Bash (grep, find, ls) and Read tool calls — no Edit, Write, or file creation
- The response includes cited file paths for every factual claim (e.g. "Auth is handled in `apps/backend/src/middleware/auth.ts:42`")
- The agent completes in a single pass — no retry loop, no Reviewer, no checkpoint written
- The terminal summary is the agent's answer verbatim (no pipeline summary header)
- If the question cannot be answered from the codebase (e.g. "what is the best ORM?"), the agent says so explicitly rather than hallucinating

## Affected files
- `skills/nob/SKILL.md` — add `Ask` to the workflow identification table; add Ask workflow early exit (similar to Ideate) that dispatches a read-only Q&A agent
- `skills/nob/ask-agent/SKILL.md` — new skill file: read-only Q&A agent that answers codebase questions with cited file paths

## Out of scope
- Conversational multi-turn Q&A (each `/ask` is a single question/answer pair)
- Answers to questions about external libraries or best practices (only codebase-grounded answers)
- Integration with project memory (Ask does not write to or read from `.nob/project-memory.yml`)
