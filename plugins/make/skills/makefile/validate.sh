#!/usr/bin/env bash
# validate.sh — Static validator for skill-conformant Makefiles
#
# Usage: ./scripts/validate.sh <path/to/Makefile>
#
# Exit codes:
#   0  All checks passed
#   1  A check failed (fail-fast: stops at first failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
FONTS_DIR="${SKILL_DIR}/fonts"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
pass() { printf "${GREEN}  ✓${RESET} %s\n" "$1"; }
fail() { printf "${RED}  ✗${RESET} ${BOLD}%s${RESET}\n" "$1"; exit 1; }
section() { printf "\n${CYAN}${BOLD}%s${RESET}\n" "$1"; }

# ── Argument ──────────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    printf "${YELLOW}Usage:${RESET} %s <path/to/Makefile>\n" "$0"
    exit 1
fi

MAKEFILE="$1"

if [[ ! -f "$MAKEFILE" ]]; then
    fail "File not found: $MAKEFILE"
fi

printf "${BOLD}Validating:${RESET} %s\n" "$MAKEFILE"

# ═════════════════════════════════════════════════════════════════════════════
# CHECK 1 — Required .PHONY targets
# ═════════════════════════════════════════════════════════════════════════════
section "1. Required PHONY targets"

REQUIRED_PHONY=(help sync fmt lint typecheck check qa test test.unit clean distclean)

# Collect every target declared after .PHONY:
PHONY_TARGETS=$(grep -oP '(?<=\.PHONY:)[^\n]+' "$MAKEFILE" | tr ' ' '\n' | sed 's/^[[:space:]]*//' | grep -v '^$' || true)

for target in "${REQUIRED_PHONY[@]}"; do
    if echo "$PHONY_TARGETS" | grep -qx "$target"; then
        pass ".PHONY: $target"
    else
        fail "Missing required .PHONY target: '$target'"
    fi
done

# ═════════════════════════════════════════════════════════════════════════════
# CHECK 2 — .SILENT: declared and no @ in recipes
# ═════════════════════════════════════════════════════════════════════════════
section "2. Silent mode"

if grep -q '^\.SILENT' "$MAKEFILE"; then
    pass ".SILENT: is declared"
else
    fail ".SILENT: is not declared — add '.SILENT:' to suppress recipe echoing"
fi

if grep -q '\.ONESHELL' "$MAKEFILE"; then
    pass ".ONESHELL: is declared"
else
    fail ".ONESHELL: is not declared — add '.ONESHELL:' to run each recipe in a single shell"
fi

# Recipe lines start with a tab; @ on such lines is redundant and forbidden
AT_LINES=$(grep -nP '^\t@' "$MAKEFILE" || true)
if [[ -n "$AT_LINES" ]]; then
    fail "Found recipe lines using '@' (redundant with .SILENT:):"$'\n'"$AT_LINES"
fi
pass "No '@' prefix in recipes"

# ═════════════════════════════════════════════════════════════════════════════
# CHECK 3 — help target: structure and format (Approach A only)
# Approach B (inline ## annotations + grep pipeline) is FORBIDDEN.
# The help target MUST use explicit printf entries with a box-drawing header.
# ═════════════════════════════════════════════════════════════════════════════
section "3. help target format"

# 3a. help target exists as a recipe
if ! grep -qP '^help\s*:' "$MAKEFILE"; then
    fail "No 'help:' target found"
fi
pass "help: target exists"

# 3b. Reject ## annotations on target lines (Approach B is FORBIDDEN)
ANNOTATED=$(grep -cP '^[a-zA-Z_.][a-zA-Z_.0-9]*[^#\n]*##' "$MAKEFILE" 2>/dev/null || true)
ANNOTATED="${ANNOTATED//[^0-9]/}"
ANNOTATED="${ANNOTATED:-0}"
if [[ "$ANNOTATED" -gt 0 ]]; then
    fail "Found $ANNOTATED target line(s) with '##' inline annotations — Approach B (grep-parsed help) is FORBIDDEN. Use explicit printf entries in the help target (Approach A)."
fi
pass "No inline ## annotations on target lines"

# 3c. Reject grep-based help pipeline
if grep -qP 'grep.*##.*MAKEFILE_LIST' "$MAKEFILE"; then
    fail "help target uses grep to parse '##' annotations — this pattern is FORBIDDEN. Use explicit printf entries instead."
fi
pass "No grep-based help pipeline"

# 3d. Approach A: box-drawing header required
ART_CHARS='[║╗╝╚╔═╠╣╦╩╬]'
if grep -qP "$ART_CHARS" "$MAKEFILE"; then
    pass "Box-drawing header detected"
else
    fail "No box-drawing header found in help target (generate with: make_banner tool)"
fi

if grep -qP 'Usage:' "$MAKEFILE"; then
    pass "Usage: line present"
else
    fail "No 'Usage:' line found in help target"
fi

SECTION_COUNT=$(grep -cF '1;35m' "$MAKEFILE" 2>/dev/null || true)
SECTION_COUNT="${SECTION_COUNT//[^0-9]/}"
SECTION_COUNT="${SECTION_COUNT:-0}"
if [[ "$SECTION_COUNT" -ge 1 ]]; then
    pass "Colored section headers present ($SECTION_COUNT)"
else
    fail "No colored section headers found in help target (expected printf lines with \\033[1;35m<Name>:\\033[0m)"
fi

ENTRY_LINES=$(grep -cP '^\t\s*printf\s+"[[:space:]]+\S+[[:space:]]+-[[:space:]]+\S' "$MAKEFILE" 2>/dev/null || true)
ENTRY_LINES="${ENTRY_LINES//[^0-9]/}"
ENTRY_LINES="${ENTRY_LINES:-0}"
if [[ "$ENTRY_LINES" -ge 2 ]]; then
    pass "Explicit printf entries detected ($ENTRY_LINES entries)"
else
    fail "Help entries must be explicit printf lines: '  target  - description' (at least 2 found $ENTRY_LINES)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# CHECK 4 — uv instead of python / pip
# ═════════════════════════════════════════════════════════════════════════════
section "4. Python toolchain (uv, not python/pip)"

# Only flag when the file contains Python indicators
HAS_PYTHON_INDICATOR=$(grep -ciP '\.py|pyproject|uv|pip|pytest|ruff' "$MAKEFILE" 2>/dev/null || true)

if [[ "$HAS_PYTHON_INDICATOR" -gt 0 ]]; then
    # Forbidden patterns in recipe lines (tabs), ignoring comments
    FORBIDDEN=$(grep -nP '^\t(python[23]?\s|pip[23]?\s)' "$MAKEFILE" || true)
    if [[ -n "$FORBIDDEN" ]]; then
        fail "Use 'uv run' / 'uv sync' instead of bare python/pip in recipes:"$'\n'"$FORBIDDEN"
    fi
    pass "No bare python/pip calls in recipes (uv enforced)"
else
    pass "No Python indicators found — uv check skipped"
fi

# ═════════════════════════════════════════════════════════════════════════════
# DONE
# ═════════════════════════════════════════════════════════════════════════════
printf "\n${GREEN}${BOLD}All checks passed.${RESET}\n\n"
