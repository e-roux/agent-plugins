---
name: shell
description: "Shell scripting expert specializing in robust automation and system administration scripts."
license: MIT
---

# Shell Scripting Skill

## Approach

1. Write defensive scripts with comprehensive error handling
2. Use `set -euo pipefail` for strict error mode
3. Quote variables to prevent word splitting
4. Prefer built-ins over external tools
5. Document complex logic and variable names (inline if possible)

## Workflow

Always use Make targets:
- `make fmt` — shell formatting
- `make lint` — shellcheck
- `make test` — shell script tests
- `make check` — fmt + lint
- `make qa` — required before completion

## Code style requirements

**Error handling** (required for all scripts):

```bash
set -euo pipefail  # Strict error mode
IFS=$'\n\t'       # Safer IFS
```

**Variable documentation**:

```bash
readonly CONFIG_FILE="${1:-/etc/default/config}"  # Configuration file path
readonly TIMEOUT="${2:-30}"                        # Request timeout in seconds
```

**Function pattern**:

```bash
#!/bin/bash
set -euo pipefail

# Validate input file exists
# @param string file_path Path to file to validate
validate_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: File not found: $file_path" >&2
    return 1
  fi
}

main() {
  local config_file="${1:-/etc/default/config}"
  validate_file "$config_file"
  # Rest of script logic
}

main "$@"
```

## Testing

Write tests FIRST. Load the **testing** skill for full TDD workflow.

- Unit tests: `test/unit/*_test.sh`
- Integration tests: `test/integration/*_test.sh`
