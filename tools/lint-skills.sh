#!/usr/bin/env bash
#
# lint-skills.sh — Skill-contract linter for the Nob plugin.
#
# Validates the Nob plugin's internal contracts:
#   1. Sub-skill path references in the hub (skills/nob/SKILL.md) resolve to
#      existing files under skills/.
#   2. For each agent in the hub's Output Block Validation table, the producing
#      sub-skill actually emits the matching [X OUTPUT] and [/X OUTPUT] tags.
#   3. Every required field named in the validation table appears as "FieldName:"
#      on its own line within the producing sub-skill's output block.
#   4. Every [X OUTPUT] block the hub extracts has a known producing sub-skill
#      (flags missing-block / no-producer violations).
#
# Design notes (mirroring unit-boundary.sh's philosophy):
#   * Fail-open: any tooling/parse problem emits a WARNING, never crashes.
#   * No new runtime dependency: pure POSIX/bash + coreutils (grep, sed, awk).
#   * jq is NOT required. If used anywhere, guard with command -v check.
#   * Accepts an optional REPO_ROOT argument so it can be tested against a
#     copied tree without touching the real repo.
#
# Usage: tools/lint-skills.sh [REPO_ROOT]
#   REPO_ROOT defaults to the parent of the directory containing this script.
#
# Exit codes:
#   0 — no violations
#   1 — one or more violations found

# ---------------------------------------------------------------------------
# Resolve REPO_ROOT
# ---------------------------------------------------------------------------

script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ -n "$1" ]; then
  REPO_ROOT="$(cd "$1" && pwd 2>/dev/null)" || {
    echo "lint-skills: ERROR: cannot cd to provided REPO_ROOT: $1" >&2
    exit 1
  }
else
  # Default: parent of the script's own directory (tools/ lives at repo root)
  REPO_ROOT="$(cd "$script_dir/.." && pwd)"
fi

HUB="$REPO_ROOT/skills/nob/SKILL.md"
SKILLS_DIR="$REPO_ROOT/skills"

violations=0
warnings=0

# ---------------------------------------------------------------------------
# Helper: report a violation
# ---------------------------------------------------------------------------
violation() {
  local file="$1"
  local reason="$2"
  echo "${file}: ${reason}"
  violations=$((violations + 1))
}

# ---------------------------------------------------------------------------
# Helper: report a parse-level warning (non-fatal)
# ---------------------------------------------------------------------------
warn() {
  echo "lint-skills: WARNING: $1"
  warnings=$((warnings + 1))
}

# ---------------------------------------------------------------------------
# Step 0: Confirm the hub exists
# ---------------------------------------------------------------------------
if [ ! -f "$HUB" ]; then
  violation "skills/nob/SKILL.md" "hub file skills/nob/SKILL.md not found"
  echo "lint-skills: 1 violation(s) found."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Sub-skill path references
#
# The hub uses the pattern:
#   {SKILL_BASE_DIR}/../X/SKILL.md
# which resolves to skills/X/SKILL.md at runtime.
# We grep for those references and check each target exists.
# ---------------------------------------------------------------------------

# Extract unique sub-skill names referenced in the hub.
# Pattern: {SKILL_BASE_DIR}/../<name>/SKILL.md
# We capture the <name> part.
sub_skill_names=""
while IFS= read -r matched; do
  # matched is like: {SKILL_BASE_DIR}/../pm/SKILL.md
  # Extract the name between ../ and /SKILL.md
  name="${matched#*\.\./}"
  name="${name%%/SKILL.md*}"
  # Skip if name looks like a variable, template, or is empty
  case "$name" in
    ''|*'{'*|*'}'*|*' '*|*'/'*) continue ;;
  esac
  # Deduplicate
  case " $sub_skill_names " in
    *" $name "*) ;;
    *) sub_skill_names="$sub_skill_names $name" ;;
  esac
done < <(grep -oE '\{SKILL_BASE_DIR\}/\.\./[A-Za-z0-9_-]+/SKILL\.md' "$HUB" 2>/dev/null)

if [ -z "$sub_skill_names" ]; then
  warn "could not extract any sub-skill path references from skills/nob/SKILL.md — check the grep pattern"
fi

for name in $sub_skill_names; do
  # Skip single-letter placeholder names (e.g. 'X' used in documentation text
  # like "{SKILL_BASE_DIR}/../X/SKILL.md" as a generic stand-in).
  case "$name" in
    [A-Za-z]) continue ;;
  esac
  target="$SKILLS_DIR/$name/SKILL.md"
  rel_target="skills/$name/SKILL.md"
  if [ ! -f "$target" ]; then
    violation "$rel_target" "missing-path: hub references {SKILL_BASE_DIR}/../$name/SKILL.md but skills/$name/SKILL.md does not exist"
  fi
done

# ---------------------------------------------------------------------------
# Step 2: Output Block Validation table
#
# Parse the hub's "Output Block Validation Procedure" table to get:
#   Agent name → required fields
# Then map each agent name to:
#   output-block tag  e.g. [PM OUTPUT]
#   producing skill   e.g. skills/pm/SKILL.md
#
# The table rows look like:
#   | Tech Lead | `Affected units:`, `Interfaces written:`, ... |
#   | PM Agent  | `Acceptance criteria:`, ... |
#   | Dev Agent | `Tasks:`, ... |
#   | Reviewer  | `Overall status:`, ... |
# ---------------------------------------------------------------------------

# Static agent→(tag, skill-file) mapping.
# This is the most robust approach: the hub is authoritative about which
# agent emits which block, and the mapping is stable by design.
# Format per line: AgentName|[TAG OUTPUT]|skills/X/SKILL.md
AGENT_MAP="Tech Lead|[TECH LEAD OUTPUT]|skills/tech-lead/SKILL.md
PM Agent|[PM OUTPUT]|skills/pm/SKILL.md
Dev Agent|[DEV OUTPUT]|skills/dev/SKILL.md
Reviewer|[REVIEWER OUTPUT]|skills/reviewer/SKILL.md
Test Writer|[TEST WRITER OUTPUT]|skills/test-writer/SKILL.md"

# Extract the validation table from the hub.
# We look for the table between "| Agent |" and the next blank line or heading.
parse_ok=0
table_block=""
in_table=0
while IFS= read -r line; do
  if [ $in_table -eq 0 ]; then
    case "$line" in
      *'| Agent |'*'Required fields'*)
        in_table=1
        ;;
    esac
    continue
  fi
  # In table: collect rows until blank line, non-pipe line, or heading
  case "$line" in
    '|---'*) ;;           # separator row — skip
    '|'*)  table_block="${table_block}${line}
" ;;
    *) break ;;
  esac
done < "$HUB"

if [ -z "$table_block" ]; then
  warn "could not parse the Output Block Validation table in skills/nob/SKILL.md — field checks skipped"
else
  parse_ok=1
fi

# For each agent in our static map, check:
#   a) The producing skill file exists
#   b) The skill emits [X OUTPUT] and [/X OUTPUT]
#   c) All required fields from the table appear as "FieldName:" in the skill
while IFS='|' read -r agent_name tag skill_rel; do
  # Trim leading/trailing whitespace
  agent_name="${agent_name#"${agent_name%%[![:space:]]*}"}"
  agent_name="${agent_name%"${agent_name##*[![:space:]]}"}"
  tag="${tag#"${tag%%[![:space:]]*}"}"
  tag="${tag%"${tag##*[![:space:]]}"}"
  skill_rel="${skill_rel#"${skill_rel%%[![:space:]]*}"}"
  skill_rel="${skill_rel%"${skill_rel##*[![:space:]]}"}"

  [ -z "$agent_name" ] && continue

  skill_path="$REPO_ROOT/$skill_rel"

  # (a) Skill file exists
  if [ ! -f "$skill_path" ]; then
    violation "$skill_rel" "missing-path: producing skill for agent '$agent_name' not found"
    continue
  fi

  # Derive opening and closing tags from $tag.
  # $tag is e.g. "[PM OUTPUT]" → open_tag="[PM OUTPUT]" close_tag="[/PM OUTPUT]"
  open_tag="$tag"
  # Build close tag: insert / after opening [
  close_tag="[/${tag#[}"

  # (b) Skill emits [X OUTPUT] and [/X OUTPUT]
  open_found=0
  close_found=0
  grep -qF "$open_tag" "$skill_path" 2>/dev/null && open_found=1
  grep -qF "$close_tag" "$skill_path" 2>/dev/null && close_found=1

  if [ $open_found -eq 0 ] && [ $close_found -eq 0 ]; then
    violation "$skill_rel" "missing-block: skill for agent '$agent_name' does not emit $open_tag / $close_tag"
    continue
  elif [ $open_found -eq 0 ]; then
    violation "$skill_rel" "missing-block: skill for agent '$agent_name' emits $close_tag but not $open_tag"
    continue
  elif [ $close_found -eq 0 ]; then
    violation "$skill_rel" "missing-block: skill for agent '$agent_name' emits $open_tag but not $close_tag"
    continue
  fi

  # (c) Required fields from the validation table appear as "FieldName:" in the skill.
  if [ $parse_ok -eq 0 ]; then
    continue  # table parse failed — warning already emitted above
  fi

  # Extract ONLY the text inside the skill's output block(s) — the region(s)
  # strictly between an own-line "[X OUTPUT]" and its own-line "[/X OUTPUT]".
  # The skills' Output Format requires each tag on its own line; prose mentions
  # of a field token (e.g. a backtick'd `Risks:` in instructions) appear inline
  # and MUST NOT count toward field presence, or removing the real field would
  # go undetected. (whitespace-trimmed full-line match guards against this.)
  block_content="$(awk -v o="$open_tag" -v c="$close_tag" '
    { line=$0; sub(/^[ \t]+/,"",line); sub(/[ \t]+$/,"",line) }
    line==o { inb=1; next }
    line==c { inb=0; next }
    inb { print }
  ' "$skill_path" 2>/dev/null)"

  if [ -z "$block_content" ]; then
    # Open/close tags exist (passed check b) but no own-line block body was
    # found — the block is malformed (inline-only). Report once and skip fields.
    violation "$skill_rel" "missing-block: agent '$agent_name' $open_tag is not a well-formed own-line block (no field body found)"
    continue
  fi

  # Find the table row for this agent (case-insensitive match on agent name).
  agent_row=""
  while IFS= read -r row; do
    case "$row" in
      '|'*'|'*)
        row_agent="${row#|}"
        row_agent="${row_agent%%|*}"
        row_agent="${row_agent#"${row_agent%%[![:space:]]*}"}"
        row_agent="${row_agent%"${row_agent##*[![:space:]]}"}"
        row_lower="$(printf '%s' "$row_agent" | tr '[:upper:]' '[:lower:]')"
        agent_lower="$(printf '%s' "$agent_name" | tr '[:upper:]' '[:lower:]')"
        if [ "$row_lower" = "$agent_lower" ]; then
          agent_row="$row"
          break
        fi
        ;;
    esac
  done <<< "$table_block"

  if [ -z "$agent_row" ]; then
    warn "agent '$agent_name' not found in validation table — field checks skipped for $skill_rel"
    continue
  fi

  # Extract the required-fields column (second | … | section).
  fields_col="${agent_row#*|}"   # strip first column (| AgentName |)
  fields_col="${fields_col#*|}"  # strip the separator pipe
  fields_col="${fields_col%%|*}" # take content up to next |

  # Parse individual field names from backtick-quoted tokens like `FieldName:`.
  while IFS= read -r field_token; do
    field_token="${field_token#"${field_token%%[![:space:]]*}"}"
    field_token="${field_token%"${field_token##*[![:space:]]}"}"
    [ -z "$field_token" ] && continue

    if ! printf '%s\n' "$block_content" | grep -qF "$field_token" 2>/dev/null; then
      violation "$skill_rel" "missing-field: agent '$agent_name' required field '$field_token' not found in $open_tag block"
    fi
  done < <(printf '%s' "$fields_col" | grep -oE '`[^`]+`' | tr -d '`')

done <<< "$AGENT_MAP"

# ---------------------------------------------------------------------------
# Step 3: [X OUTPUT] blocks referenced/extracted by the hub but with no
#         known producing sub-skill.
#
# Grep the hub for all [X OUTPUT] and [/X OUTPUT] references and verify each
# tag has a known producer in our static mapping or known supplementary list.
# ---------------------------------------------------------------------------

# All known output tag names (without brackets or leading /).
known_tags="TECH LEAD OUTPUT
PM OUTPUT
DEV OUTPUT
REVIEWER OUTPUT
DEBUG OUTPUT
PM SPECWRITER OUTPUT
INIT OUTPUT
VENTURE OUTPUT
REFACTOR OUTPUT
IDEATION OUTPUT
RETRY-DIAGNOSTIC OUTPUT
DESIGNER OUTPUT
DOCS OUTPUT
TEST WRITER OUTPUT
QUICK PATH OUTPUT
LITE PATH OUTPUT
FULL PATH OUTPUT
RETRY OUTPUT
CHECKPOINT GATE OUTPUT"

# Grep hub for all [X OUTPUT] references (capture the tag content).
# We match patterns like [PM OUTPUT], [TECH LEAD OUTPUT], [/PM OUTPUT], etc.
hub_tags=""
while IFS= read -r matched; do
  # matched is like [PM OUTPUT] or [/PM OUTPUT]
  tag_content="${matched#[}"    # strip leading [
  tag_content="${tag_content%]}" # strip trailing ]
  tag_content="${tag_content#/}" # strip leading / (closing tags)
  # Must end with OUTPUT
  case "$tag_content" in
    *OUTPUT)
      # Deduplicate
      case "
$hub_tags
" in
        *"
$tag_content
"*) ;;
        *) hub_tags="${hub_tags}
${tag_content}" ;;
      esac
      ;;
  esac
done < <(grep -oE '\[/?[A-Z][A-Z0-9 -]*OUTPUT\]' "$HUB" 2>/dev/null)

while IFS= read -r tag_name; do
  tag_name="${tag_name#"${tag_name%%[![:space:]]*}"}"
  tag_name="${tag_name%"${tag_name##*[![:space:]]}"}"
  [ -z "$tag_name" ] && continue

  # Skip single-letter placeholder tag names (e.g. "X OUTPUT" used in
  # documentation prose as a generic stand-in for any real tag name).
  first_word="${tag_name%% *}"
  case "$first_word" in
    [A-Za-z]) continue ;;
  esac

  case "
$known_tags
" in
    *"
$tag_name
"*) ;;
    *)
      violation "skills/nob/SKILL.md" "missing-block/no-producer: hub references [$tag_name] but no producing sub-skill is mapped for this block"
      ;;
  esac
done <<< "$hub_tags"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ $violations -eq 0 ]; then
  echo "lint-skills: OK — no violations."
  exit 0
else
  echo "lint-skills: ${violations} violation(s) found."
  exit 1
fi
