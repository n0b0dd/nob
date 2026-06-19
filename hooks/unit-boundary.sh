#!/usr/bin/env bash
#
# nob unit-boundary guardrail — PreToolUse hook for Edit/Write/MultiEdit/NotebookEdit.
#
# While a nob implementation run is active, the hub writes a marker file
# `.nob/.boundary.json` describing the run's git worktree and the sub-paths that
# edits are allowed to touch (the declared unit paths plus nob-internal/docs/config).
# This hook denies any edit that lands inside the worktree but outside those paths,
# so a dev sub-agent cannot wander outside the units it was assigned.
#
# Design notes:
#   * No marker  -> no active run (or guard disabled) -> allow everything. The
#     hook is a no-op in ordinary sessions and for init/refactor/venture (they
#     never reach the dev phase, so no marker is written).
#   * Only edits *inside* the active worktree are policed. The hub's own
#     operational writes (checkpoint, run-log, memory) live outside the worktree
#     and are never blocked.
#   * Fail-open everywhere: any parse/tooling problem allows the edit. A guard
#     that silently disables itself is safer than one that bricks the pipeline.
#   * Bash 3.2 compatible (macOS system bash). Requires `jq`; without it the
#     hook no-ops.

input="$(cat)"

# jq absent -> degrade to no-op rather than risk blocking legitimate edits.
command -v jq >/dev/null 2>&1 || exit 0

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
proj="${proj%/}"
marker="$proj/.nob/.boundary.json"

# No active run -> nothing to enforce.
[ -f "$marker" ] || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Edit/Write/MultiEdit use file_path; NotebookEdit uses notebook_path.
fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[ -n "$fp" ] || exit 0

# Resolve target to an absolute path (no canonicalization — purely textual).
case "$fp" in
  /*) target="$fp" ;;
  *)  target="$proj/$fp" ;;
esac

# Worktree base the run's edits should stay within. May be relative to proj.
wt="$(jq -r '.worktree // "."' "$marker" 2>/dev/null)"
[ -n "$wt" ] || exit 0
case "$wt" in
  /*)   ;;
  .|./) wt="$proj" ;;
  *)    wt="$proj/${wt#./}" ;;
esac
wt="${wt%/}"

# Only police edits inside the active worktree — the dev sandbox. Anything
# outside it (the hub's operational writes, the main checkout) is left alone.
case "$target/" in
  "$wt/"*) ;;
  *) exit 0 ;;
esac

rel="${target#$wt/}"

# Allowed sub-paths within the worktree (unit paths + nob-internal/docs/config).
allow=()
while IFS= read -r a; do
  [ -n "$a" ] && allow+=("$a")
done < <(jq -r '.allow[]?' "$marker" 2>/dev/null)

# Malformed/empty allow list -> fail open.
[ "${#allow[@]}" -gt 0 ] || exit 0

for a in "${allow[@]}"; do
  a="${a#./}"
  case "$rel/" in
    "$a"*) exit 0 ;;            # under an allowed directory
  esac
  [ "$rel" = "${a%/}" ] && exit 0   # exact allowed file (e.g. .nob.yml)
done

reason="nob unit-boundary: \"$rel\" is outside every declared unit path in .nob.yml. During an active /nob run, edits must stay within a unit (or .nob/, docs/, .nob.yml). If this edit is intentional, remove $marker to lift the guard, or add the path as a unit in .nob.yml."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
