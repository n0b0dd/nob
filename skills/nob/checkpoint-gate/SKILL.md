---
name: checkpoint-gate
description: 'Standalone pre-flight checkpoint check. Dispatched by the hub as the very first step before git, config, or any scan. Reads .nob/checkpoint.json, determines run state (none / completed / interrupted), alerts the user interactively, and emits [CHECKPOINT GATE OUTPUT] with the chosen action and resume context.'
---

# Nob — Checkpoint Gate

Reads the checkpoint, determines whether a previous run exists and in what state, then prompts the user to decide how to proceed. Returns a single structured output block — the hub acts on it, this skill never modifies project files.

---

## Setup

Set CHECKPOINT_PATH from `Checkpoint path:` in [INPUTS] (default: `.nob/` if absent).
Set INTENT_SPEC_PATH from `Spec path:` in [INPUTS] (may be empty).

---

## Step 1: Read checkpoint

Try to read `{CHECKPOINT_PATH}checkpoint.json` using the Read tool.

- **Not found or unreadable** → emit `Action: none`. Exit.
- **Found but not valid JSON** → print `"Warning: .nob/checkpoint.json is corrupted — it will be cleared."` Run `rm -f {CHECKPOINT_PATH}checkpoint.json` via Bash. Emit `Action: fresh`. Exit.

---

## Step 2: Spec match

If INTENT_SPEC_PATH is non-empty AND the checkpoint `spec_path` field does not match INTENT_SPEC_PATH: this checkpoint belongs to a different spec. Emit `Action: none`. Exit silently — do not alert the user.

---

## Step 3: Determine state

| Condition | State |
|---|---|
| `reviewer_output` non-null | **completed** |
| `phases_completed` non-empty OR `tasks` map non-empty | **interrupted** |
| both empty | **initializing** |

If state = **initializing**: emit `Action: none`. Exit.

---

## Step 4: Alert and prompt

### If state = completed

Print:
```
Nob: a previous run already completed for this spec.
  Spec:          {spec_path from checkpoint}
  Review status: {Overall status extracted from reviewer_output, or: unknown}

Run again from scratch? (yes / no)
```

Wait for user response.

- `yes` or clear affirmative:
  - Run `rm -f {CHECKPOINT_PATH}checkpoint.json` via Bash.
  - Emit `Action: fresh`. Exit.
- anything else:
  - Print `"Checkpoint preserved. Remove it to run again:  rm {CHECKPOINT_PATH}checkpoint.json"`
  - Emit `Action: cancel`. Exit.

### If state = interrupted

Count:
- N_DONE = number of entries in `tasks` map whose value is `"completed"`.
- N_TOTAL = total number of entries in `tasks` map.

Print:
```
Nob: interrupted run found for this spec.
  Spec:             {spec_path from checkpoint}
  Branch:           {worktree_branch from checkpoint}
  Phases completed: {phases_completed joined with ", ", or: none yet}
  Tasks done:       {N_DONE}/{N_TOTAL}

How to proceed?
  resume — continue from where it left off
  fresh  — discard checkpoint and start over
  cancel — exit
```

Wait for user response.

- **`resume`** or clear resume intent:
  - Collect RESUME_TASK_IDS = all keys in `tasks` map whose value is `"completed"`, joined with commas. If none: `none`.
  - Emit `Action: resume` with full context. Exit.

- **`fresh`** or clear fresh/restart intent:
  - Run `rm -f {CHECKPOINT_PATH}checkpoint.json` via Bash.
  - Print `"Checkpoint cleared — starting fresh."`
  - Emit `Action: fresh`. Exit.

- **`cancel`** or any other response:
  - Print `"Cancelled. Checkpoint preserved."`
  - Emit `Action: cancel`. Exit.

---

## Output

Emit exactly this block with all fields present (use `none` for absent values):

```
[CHECKPOINT GATE OUTPUT]
Action: {none | resume | fresh | cancel}
Spec path: {spec_path from checkpoint, or: none}
Worktree path: {worktree_path from checkpoint, or: none}
Worktree branch: {worktree_branch from checkpoint, or: none}
Resume tasks: {RESUME_TASK_IDS, or: none}
[/CHECKPOINT GATE OUTPUT]
```
