#!/usr/bin/env bats

SKILLS_DIR="$BATS_TEST_DIRNAME/../../skills/codebase-audit"
STRIP_PY="$SKILLS_DIR/scripts/strip_annotations.py"
AUDIT_SH="$SKILLS_DIR/scripts/audit.sh"

setup() {
  # Create a clean temporary directory for tests
  TEST_TMP_DIR=$(mktemp -d)
}

teardown() {
  # Clean up temporary directory
  rm -rf "$TEST_TMP_DIR"
}

# ── strip_annotations.py ──────────────────────────────────────────────────────

@test "strip_annotations: executes successfully for --help" {
  run "$STRIP_PY" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Strip Python Type Annotations"* ]]
}

@test "strip_annotations: parses annotations and docstrings in JSON format" {
  # Write a mock Python file with type annotations and docstrings
  cat << 'EOF' > "$TEST_TMP_DIR/mock.py"
"""Module docstring."""

def add(x: int, y: int) -> int:
    """Add two numbers."""
    return x + y

class Calculator[T]:
    """A generic calculator."""
    value: T = 0
EOF

  run "$STRIP_PY" -f json "$TEST_TMP_DIR/mock.py"
  [ "$status" -eq 0 ]

  # Verify the JSON output contains correct fields
  echo "$output" | jq -e '.summary' >/dev/null
  echo "$output" | jq -e '.annotations' >/dev/null

  local processed; processed=$(echo "$output" | jq -r '.summary.files_processed')
  [ "$processed" -eq 1 ]

  local annot_density; annot_density=$(echo "$output" | jq -r '.summary.annotation_density_percent')
  # Density should be greater than 0
  [ $(echo "$annot_density > 0" | bc -l) -eq 1 ]

  local doc_density; doc_density=$(echo "$output" | jq -r '.summary.docstring_density_percent')
  # Docstring density should be greater than 0
  [ $(echo "$doc_density > 0" | bc -l) -eq 1 ]
}

@test "strip_annotations: strips type annotations" {
  cat << 'EOF' > "$TEST_TMP_DIR/mock.py"
def add(x: int, y: int) -> int:
    return x + y
EOF

  local out_file="$TEST_TMP_DIR/stripped.py"
  run "$STRIP_PY" -o "$out_file" "$TEST_TMP_DIR/mock.py"
  [ "$status" -eq 0 ]

  # Check that type annotations are removed from the unannotated file
  run cat "$out_file"
  [[ "$output" == *"def add(x, y):"* ]]
  [[ "$output" != *"int"* ]]
}

@test "strip_annotations: strips docstrings when requested" {
  cat << 'EOF' > "$TEST_TMP_DIR/mock.py"
def add(x, y):
    """Add numbers."""
    return x + y
EOF

  local out_file="$TEST_TMP_DIR/stripped.py"
  run "$STRIP_PY" --strip-docstrings -o "$out_file" "$TEST_TMP_DIR/mock.py"
  [ "$status" -eq 0 ]

  # Check that docstring is stripped
  run cat "$out_file"
  [[ "$output" != *"Add numbers"* ]]
}

# ── audit.sh ──────────────────────────────────────────────────────────────────

@test "audit_sh: generates output folder and entropy JSON" {
  # Write a simple structure with some code files to audit
  mkdir -p "$TEST_TMP_DIR/src"
  cat << 'EOF' > "$TEST_TMP_DIR/src/app.py"
def hello():
    print("hello")
EOF

  run "$AUDIT_SH" "$TEST_TMP_DIR" "$TEST_TMP_DIR/audit-out"
  [ "$status" -eq 0 ]

  # Output should contain our expected snapshot files
  [ -f "$TEST_TMP_DIR/audit-out/entropy.json" ]

  # Verify the generated entropy JSON contains total_code_lines or other keys
  run cat "$TEST_TMP_DIR/audit-out/entropy.json"
  echo "$output" | jq -e '.tools_used' >/dev/null
}
