---
name: shell-config
description: "Multi-shell configuration system contributing guide. Use when working on shell configurations across zsh, fish, and nushell. Covers cross-shell impact assessment, transpilation-based environment system, shared vs shell-specific changes, and testing requirements."
---

# Multi-Shell Configuration Contributing Guide

**Purpose**: Make safe, consistent changes across zsh, fish, and nushell without breaking other shells.

## Quick Decision Tree

### What am I modifying?
- **Aliases** → Check `shared/aliases.csv`
- **Environment Variables** → Check `shared/shared_env.sh`  
- **Named Directories** → Check `shared/named_dirs.csv`
- **Functions** → Decide if shared or shell-specific
- **Shell behavior** → Usually shell-specific only

### Does this affect other shells?
- **YES**: Modify shared files + update all shell implementations
- **NO**: Modify only the target shell
- **UNSURE**: Read "Cross-Shell Impact Assessment" below

## Architecture Overview

```
dots/
├── shell/share/           # SHARED LAYER (affects ALL shells)
│   ├── shared_env.sh      # Environment variables (master source)
│   ├── transpile_env.sh   # Transpilation script
│   ├── shared_env.fish    # Auto-generated Fish environment
│   ├── shared_env.nu      # Auto-generated Nushell environment
│   ├── load_shared_env.fish  # Fish loader with auto-transpilation
│   ├── load_shared_env.nu    # Nushell loader with auto-transpilation
│   ├── aliases.csv        # Cross-shell aliases
│   ├── named_dirs.csv     # Directory shortcuts
│   └── functions/         # Shared functions
├── zsh/config/            # Zsh-only changes
├── fish/config/           # Fish-only changes  
└── nushell/config/        # Nushell-only changes
```

**CRITICAL RULE**: Changes to `dots/shell/share/` affect ALL three shells.

## Transpilation-Based Environment System

The system uses **build-time transpilation** to convert the master `shared_env.sh` into shell-specific syntax:

```
shared_env.sh (master) → transpile_env.sh → shared_env.fish & shared_env.nu
                                   ↑                    ↓
Shell login → load_shared_env.{fish,nu} ←───────── source transpiled files
```

**How it works:**
1. **Zsh**: Directly sources `shared_env.sh` (POSIX compatible)
2. **Fish**: Uses `load_shared_env.fish` → auto-transpiles → sources `shared_env.fish`
3. **Nushell**: Uses `load_shared_env.nu` → auto-transpiles → loads `shared_env.nu`

## Cross-Shell Impact Assessment

### HIGH IMPACT (Always affects all shells)

**Files that affect ALL shells:**
- `dots/shell/share/shared_env.sh` - Environment variables (MASTER SOURCE)
- `dots/shell/share/aliases.csv` - Alias definitions
- `dots/shell/share/named_dirs.csv` - Directory shortcuts
- `dots/shell/share/functions/` - Shared functions

**Auto-generated files (DO NOT EDIT MANUALLY):**
- `dots/shell/share/shared_env.fish` - Auto-generated from shared_env.sh
- `dots/shell/share/shared_env.nu` - Auto-generated from shared_env.sh
- `dots/shell/share/load_shared_env.fish` - Fish transpilation loader
- `dots/shell/share/load_shared_env.nu` - Nushell transpilation loader

**When you modify `shared_env.sh`:**
1. **AUTOMATIC**: Fish and Nushell versions regenerate automatically via loaders
2. **MUST DO**: Test in all three shells (zsh, fish, nushell)
3. **MUST CHECK**: Variables use POSIX-compatible syntax (no shell-specific features)

### MEDIUM IMPACT (May affect other shells)

**Shell-specific files that use shared configs:**
- `dots/zsh/config/.zshrc` - Loads shared configs
- `dots/fish/config/config.fish` - Loads shared configs  
- `dots/nushell/config/config.nu` - Loads shared configs

**When you modify these files:**
1. **CHECK**: Are you changing how shared configs are consumed?
2. **CONSIDER**: Should similar changes be made to other shells?

### LOW IMPACT (Shell-specific only)

**Files that typically don't affect other shells:**
- Shell-specific functions (e.g., `dots/zsh/config/site-functions/`)
- Shell-specific themes/prompts
- Shell-specific key bindings
- Shell-specific completion scripts

## Implementation Patterns

### Pattern A: Adding Environment Variables (Transpilation Workflow)

**Example: Adding a new environment variable**

1. **Add to master source:**
```bash
# dots/shell/share/shared_env.sh
export NEW_TOOL_CONFIG="${XDG_CONFIG_HOME}/new-tool/config.toml"
```

2. **Test transpilation manually (optional):**
```bash
cd dots/shell/share
./transpile_env.sh --force  # Regenerate both Fish and Nushell versions
```

3. **Verify auto-transpilation works:**
```bash
# The loaders will auto-detect changes and regenerate as needed
fish -c "echo \$NEW_TOOL_CONFIG"     # Should auto-transpile and show value
nu -c "echo \$env.NEW_TOOL_CONFIG"   # Should auto-transpile and show value
zsh -c "echo \$NEW_TOOL_CONFIG"      # Direct source, should show value
```

**What happens automatically:**
- Fish: `load_shared_env.fish` detects change → runs `transpile_env.sh --fish` → sources `shared_env.fish`
- Nushell: `load_shared_env.nu` detects change → runs `transpile_env.sh --nushell` → loads `shared_env.nu`
- Zsh: Direct POSIX sourcing of `shared_env.sh` (no transpilation needed)

**Important notes:**
- Use POSIX-compatible syntax only (no shell-specific features)
- Path variables should use `${XDG_*}` patterns for proper expansion
- Test that variables expand correctly in all three shells

### Pattern B: Adding to Shared CSV Files

**Example: Adding new alias**
```csv
# Add to dots/shell/share/aliases.csv
kubectx,kubectx,kubectx
```

**What happens automatically:**
- Zsh will load it via the CSV parsing loop
- Fish will load it via the CSV parsing loop  
- Nushell needs manual addition to `aliases.nu` (limitation)

**Action required:** Add to nushell manually:
```nushell
# Add to dots/nushell/config/aliases.nu
alias kubectx = kubectx
```

### Pattern C: Adding Shell-Specific Functionality

**Example: Complex zsh function**
```bash
# dots/zsh/config/site-functions/myfunction
# Complex zsh-specific logic here
```

**No other shells affected** - proceed normally

## Testing & Validation

**For shared file changes:**
```bash
# Test each shell loads the change
zsh -c "alias | grep mynewalias"  
fish -c "alias | grep mynewalias"
nu -c "alias | where name == mynewalias"
```

**For shell-specific changes:**
```bash
# Test only the target shell
zsh -c "myfunction --test"
```

## Shell Integration Points

### Zsh (`dots/zsh/config/zprofile`)
```bash
# Direct POSIX sourcing (no transpilation needed)
SHARED_ENV="${XDG_DATA_HOME}/shell/shared_env.sh"
[[ -f "${SHARED_ENV}" ]] && source "${SHARED_ENV}"

# Parses aliases.csv with while loop
while IFS=, read -r ref cmd def; do
    if command -v "$cmd" &>/dev/null; then
        alias "$ref"="$def"
    fi
done <"${SHELL_ALIASES}"

# Hardcodes named directories using hash -d
hash -d mx=~/development/github.com/mx
```

### Fish (`dots/fish/config/conf.d/shared_env.fish`)
```fish
# Auto-transpilation via loader
source ($env.XDG_DATA_HOME + "/shell/load_shared_env.fish")

# Parses aliases.csv in config.fish
while read -l line
    set ref (echo $line | cut -d',' -f1)
    set cmd (echo $line | cut -d',' -f2) 
    set def (echo $line | cut -d',' -f3)
    if type -q $cmd
        alias $ref="$def"
    end
end < "$SHELL_ALIASES"

# Creates abbreviations from named_dirs.csv
abbr -a cdmx "cd ~/development/github.com/mx"
```

### Nushell (`dots/nushell/config/env.nu`)
```nushell
# Auto-transpilation via loader
source ($env.XDG_DATA_HOME | path join "shell/load_shared_env.nu")

# Manually defines aliases in aliases.nu (parse-time limitation)
alias g = git
alias d = docker

# Implements ncd function that reads named_dirs.csv at runtime
def --env ncd [dir_name: string] {
    # Reads and parses CSV dynamically
}
```

## Common Gotchas

### 1. Nushell Alias Limitation
**Problem**: Nushell can't dynamically create aliases from CSV files
**Solution**: 
- Add simple aliases to `dots/shell/share/aliases.csv` 
- Manually mirror them in `dots/nushell/config/aliases.nu`

### 2. Path Expansion Differences
**Problem**: `~/path` works differently across shells
**Solutions**:
- **Zsh**: Automatic expansion
- **Fish**: Use `(eval echo ~/path)` 
- **Nushell**: Use `"~/path" | str replace "~" $nu.home-path`

### 3. Transpilation System Management
**Understanding the transpilation workflow:**
- **Manual transpilation**: `cd dots/shell/share && ./transpile_env.sh [--force|--fish|--nushell]`
- **Auto-transpilation**: Happens automatically when shells load via `load_shared_env.*`
- **Make-style efficiency**: Only regenerates when `shared_env.sh` is newer than target files
- **Debugging**: Use `--force` to regenerate regardless of timestamps

### 4. Command Existence Checking
**Problem**: Each shell has different command existence checking
**Solutions**:
- **Zsh**: `command -v tool &>/dev/null`
- **Fish**: `type -q tool`  
- **Nushell**: `(which tool | is-not-empty)`

## Decision Matrix: Where to Make Changes

| Change Type | Shared Location | Zsh Specific | Fish Specific | Nushell Specific |
|-------------|----------------|--------------|---------------|------------------|
| Simple alias | `aliases.csv` + `aliases.nu` | If complex syntax | If fish-specific syntax | Always needed |
| Environment var | `shared_env.sh` | Only if zsh-specific | Only if fish-specific | Only if nushell-specific |
| Named directory | `named_dirs.csv` | Update hardcoded hash | Auto-loaded | Auto-loaded via `ncd` |
| Simple function | `functions/` + shell-specific loading | If using zsh features | If using fish features | Convert to nushell syntax |
| Complex function | N/A | `site-functions/` | `functions/` | `config.nu` or `aliases.nu` |
| Key binding | N/A | `zle.zsh` | `fish_user_key_bindings.fish` | `config.nu` keybindings |
| Theme/prompt | N/A | `theme.zsh` | prompt functions | `env.nu` PROMPT_COMMAND |

## File Modification Checklist

### When modifying `dots/shell/share/aliases.csv`:
- [ ] Test alias works in zsh: `zsh -c "alias | grep newalias"`
- [ ] Test alias works in fish: `fish -c "alias | grep newalias"`  
- [ ] Add alias manually to `dots/nushell/config/aliases.nu`
- [ ] Test alias works in nushell: `nu -c "alias | where name == newalias"`

### When modifying `dots/shell/share/shared_env.sh`:
- [ ] Test transpilation works: `cd dots/shell/share && ./transpile_env.sh --force`
- [ ] Test var exists in zsh: `zsh -c "echo \$NEW_VAR"`
- [ ] Test var exists in fish: `fish -c "echo \$NEW_VAR"` (should auto-transpile)
- [ ] Test var exists in nushell: `nu -c "echo \$env.NEW_VAR"` (should auto-transpile)
- [ ] Verify auto-transpilation message appears when files are outdated

### When modifying `dots/shell/share/named_dirs.csv`:
- [ ] Test zsh can use it: Update hardcoded `hash -d` entries
- [ ] Test fish loads it: Should work automatically via abbreviations
- [ ] Test nushell can use it: `nu -c "ncd dirname"`

### When adding shell-specific function:
- [ ] Consider if it should be cross-shell
- [ ] If yes, implement in `dots/shell/share/functions/` first
- [ ] If no, add only to target shell's function directory

## Summary

**Key Takeaway**: Always consider cross-shell impact before making changes. When in doubt, start with shell-specific implementations and only move to shared configurations once you understand the implications.

**Quick Rules**:
1. **Shared files** = test all 3 shells
2. **Shell-specific files** = test only that shell  
3. **Nushell aliases** = always update manually
4. **Functions** = try shared first, fall back to shell-specific
5. **When unsure** = choose shell-specific over shared
