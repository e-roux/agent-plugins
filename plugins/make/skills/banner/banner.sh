#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LETTERS_JSON="${SCRIPT_DIR}/letters.json"

render() {
  local text="$1"
  [[ -z "$text" ]] && return 0

  local upper
  upper="$(printf '%s' "$text" | tr '[:lower:]' '[:upper:]')"

  local result
  result=$(jq -r --arg text "$upper" '
    . as $alpha |
    ($text | explode | map(
      if . == 32 then " "
      else ([.] | implode)
      end
    ) | map(
      if $alpha[.] then $alpha[.] else $alpha[" "] end
    )) as $glyphs |
    [0, 1, 2] | map(. as $row |
      $glyphs | map(.[$row]) | join("")
    ) | join("\n")
  ' "$LETTERS_JSON")
  printf '%s' "$result"
}

render "${*:-}"
