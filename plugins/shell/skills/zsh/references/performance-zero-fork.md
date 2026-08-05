# High-Performance Zsh Programming (Zero-Fork Pattern)

This reference describes best practices for maximizing shell script execution speed by utilizing native Zsh modules, parameters, and string expansions instead of spawning external subprocesses.

---

## 1. The Zero-Fork Philosophy

Spawning an external command (such as `date`, `sed`, `awk`, `tr`, `grep`, `cut`, or `python`) requires a costly operating system `fork()` and `exec()`. While negligible in isolated scripts, running these in prompt rendering (`precmd`) or loop hooks causes severe interactive latency.

**Rule:** Always prefer native Zsh built-ins and parameter expansions over forks.

---

## 2. Speeding Up Date and Time Calculations

Never call `date` or `perl` to track command execution time, check durations, or fetch current timestamps.

- **Fast Datetime Module:** Load `zmodload zsh/datetime`.
- **Built-in Time Parameters:** Access native shell parameters directly:
  - `$EPOCHSECONDS`: Current time in integer seconds (extremely fast).
  - `$EPOCHREALTIME`: Current time in high-precision floating-point seconds.

### Example: Formatting Durations in Pure Zsh (Zero Forks)
```zsh
# Converts integer seconds to a human-readable duration (e.g., 1d 21h 56m 32s)
format_duration_to_var() {
  local human total_seconds=$1 var=$2
  local days=$(( total_seconds / 60 / 60 / 24 ))
  local hours=$(( total_seconds / 60 / 60 % 24 ))
  local minutes=$(( total_seconds / 60 % 60 ))
  local seconds=$(( total_seconds % 60 ))
  
  (( days > 0 )) && human+="${days}d "
  (( hours > 0 )) && human+="${hours}h "
  (( minutes > 0 )) && human+="${minutes}m "
  human+="${seconds}s"

  # Store result dynamically in a global variable named by $var
  typeset -g "${var}"="${human}"
}
```

---

## 3. High-Speed State Inspection

Do not run external commands like `ps`, `jobs`, or `which` to check shell configurations or jobs.

- **Check if a command/utility exists:** Use `command -v` (builtin shell check) rather than `which`.
  ```zsh
  if command -v node &>/dev/null; then ...
  ```
- **Inspect Background Jobs:** Use the `$jobstates` associative array provided by `zsh/parameter`.
  ```zsh
  # Count suspended jobs without forking 'jobs' or 'ps'
  zmodload zsh/parameter
  local suspended_count=0
  ((${(M)#jobstates:#suspended:*} != 0)) && suspended_count=1
  ```
- **Check if a Function or Variable is defined:**
  - Function check: `(( $+functions[my_custom_hook] ))`
  - Variable/Parameter check: `(( ${+my_state_variable} ))`

---

## 4. Advanced In-Process String & Array Transformations

Replace traditional piped pipeline commands (`sed`, `awk`, `tr`, `cut`) with high-speed, native Zsh parameter expansion modifiers and flags.

### Substring Replacement (Instead of `sed 's/old/new/g'`)
```zsh
# Global replacement
local input="path/to/some/file"
local transformed="${input//\//-}" # Result: "path-to-some-file"
```

### Joining Array Elements with Delimiter (Instead of `paste` or `tr`)
```zsh
# Join array elements with "|"
local -a my_array=(apple banana orange)
local joined="${(j:|:)my_array}" # Result: "apple|banana|orange"
```

### Splitting Strings into Arrays (Instead of `cut` or `awk`)
```zsh
# Split multi-line output into an array of lines
local raw_output="$(command_output)"
local -a lines
lines=(${(f)raw_output}) # Splits on newlines (f flag)

# Split by custom delimiter (e.g., "|")
local -a parts
parts=(${(s:|:)my_string}) # Splits on "|"
```

### Quoting and Safety Escape (Instead of custom sed-escaping)
```zsh
# Safely quote/escape elements for direct evaluation
local -a args=( "one simple" "two's" "three" )
local escaped="${(@qqq)args}" # Result: "one simple" "two'\''s" "three"
```

### Path and Directory Extraction (Instead of `basename` / `dirname`)
- **Get final segment:** `${PWD:t}` (equivalent to `basename "$PWD"`)
- **Get parent directory:** `${PWD:h}` (equivalent to `dirname "$PWD"`)
