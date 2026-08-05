---
name: zsh
description: "Write zsh compsys completion files and high-performance, asynchronous scripts. Follows the repository's reactive completions style and native, non-blocking design patterns."
---

# Zsh Completions Skill

## Place files the repo expects

- **PAY ATTENTION TO THIS WHEN STORING A COMPLETION FUNCTION**: Put one command completion per file under `${XDG_DATA_HOME}/zsh/completions/_<command>`.
- Keep the first line as `#compdef <command>`. `compinit` discovers `_` files from `fpath` by reading that line.
- Define one main function matching the file name, for example `_mycmd()` in `_mycmd`.
- Keep subcommand or domain helpers in the same file and namespace them (`_mycmd_project`, `_mycmd_models`, ...).
- Treat `${XDG_DATA_HOME}/zsh/completions/_gh_custom.zsh` as a special helper overlay. For new work, prefer the normal one-file-per-command layout used by `${XDG_DATA_HOME}/zsh/completions/_skills`, `_airflow`, and `_opencode`.

## Follow the local compsys shape

- Parse with `_arguments -C` and dispatch with states such as `->command`, `->subcommand`, and `->args`.
- Keep parser state local:
  - `local curcontext="$curcontext" state line ret=1`
  - `typeset -A opt_args`
- Use `_describe -t <tag>` for `name:description` arrays.
- Use `_values` for short fixed sets.
- Use `_files`, `_directories`, or another narrow helper for path arguments.
- Use helper functions for domains or subcommand families instead of one giant `case` block.
- Choose meaningful tags (`core-commands`, `config-commands`, `agents`, `projects`) because repo zstyles display and group matches by tag.

## ⚠ Mandatory: crawl all help output before writing a single line

**THIS IS THE FOUNDATIONAL COMMITMENT. DO NOT SKIP IT.**

Before writing any completion code, run the command's help system exhaustively to discover the complete command tree. This is not optional: completions built from assumptions, docs, or partial knowledge will be wrong or incomplete.

### The required discovery process

1. Run `<cmd> --help` or `<cmd> help` to get top-level subcommands and global flags.
2. For every subcommand found, run `<cmd> <sub> --help` (or `<cmd> help <sub>`).
3. For every nested subcommand found, continue recursively until leaf commands are reached.
4. Record every subcommand name, description, flag, flag alias, and argument type found.
5. Only then write the completion file.

```sh
# Example discovery loop (adapt as needed)
mycmd --help
mycmd help               # alternate form
mycmd project --help
mycmd project list --help
mycmd project show --help
mycmd config --help
mycmd config get --help
mycmd config set --help
# ... continue until every branch is exhausted
```

Use `help <cmd>`, `<cmd> <sub> --help`, or `<cmd> <sub> -h` according to whichever form the CLI accepts. If the CLI offers a machine-readable manifest (e.g., JSON, YAML, or a completion generation command), prefer that over screen-scraping help text.

### Why this is non-negotiable

A completion function that is missing subcommands or flags is actively worse than no completion. It trains muscle memory around an incomplete model, creates confusion when new flags tab-complete to nothing, and makes the file wrong the moment the upstream CLI adds anything. Crawling all help output first ensures completions are **accurate**, **complete**, and honest about what the command actually supports.

### Iterating on existing completions

When updating an existing completion file, re-run the full help crawl for any section being touched. Do not assume the current code is already complete.

## Start from this skeleton

```zsh
#compdef mycmd

_mycmd_projects() {
  local -a projects
  local project_data

  project_data="$(mycmd project list --limit 50 2>/dev/null)"
  [[ -n "$project_data" ]] || return 0

  projects=(${(f)project_data})
  _describe -t projects 'projects' projects
}

_mycmd_project() {
  local curcontext="$curcontext" state line ret=1
  typeset -A opt_args

  _arguments -C \
    '(- *)--help[Show help]' \
    '1: :->subcommand' \
    '*:: :->args' && ret=0

  case $state in
    subcommand)
      local -a commands
      commands=(
        'list:List projects'
        'show:Show one project'
      )
      _describe -t project-commands 'project commands' commands && ret=0
      ;;
    args)
      case ${words[3]} in
        show)
          _arguments '1:project:_mycmd_projects' && ret=0
          ;;
      esac
      ;;
  esac

  return $ret
}

_mycmd() {
  local curcontext="$curcontext" state line ret=1
  typeset -A opt_args

  _arguments -C \
    '(- *)--help[Show help]' \
    '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \
    '1: :->command' \
    '*:: :->args' && ret=0

  case $state in
    command)
      local -a core_commands config_commands
      core_commands=(
        'run:Run the default workflow'
        'project:Manage projects'
      )
      config_commands=(
        'config:Manage configuration'
      )

      [[ ${#core_commands} -gt 0 ]] && _describe -t core-commands 'core commands' core_commands
      [[ ${#config_commands} -gt 0 ]] && _describe -t config-commands 'configuration' config_commands
      ;;
    args)
      case ${words[2]} in
        project) _mycmd_project ;;
        run)
          _arguments \
            '--dry-run[Preview changes]' \
            '*:file:_files' && ret=0
          ;;
      esac
      ;;
  esac

  return $ret
}
```

Use `#compdef` as the primary binding mechanism. Add an explicit `compdef _mycmd mycmd` only if the file must also behave correctly when sourced directly.

## Group commands by domain

- If the CLI has several top-level verbs, group them before listing them. Good group names are things like `core`, `config`, `workspace`, `actions`, or another domain that matches the command.
- Prefer repeated `_describe -t <domain>-commands ...` calls for simple grouped menus. See `${XDG_DATA_HOME}/zsh/completions/_skills` and the grouped main-command logic in `${XDG_DATA_HOME}/zsh/completions/_gh_custom.zsh`.
- Move each large domain into a helper when it has its own subcommands or flags. See `${XDG_DATA_HOME}/zsh/completions/_airflow` and `${XDG_DATA_HOME}/zsh/completions/_opencode`.
- Use `_values` for compact literal sets instead of fake subcommands. See `${XDG_DATA_HOME}/zsh/completions/_mlib`.
- Use `_alternative` only when multiple groups truly compete at the same position; otherwise `_describe` is simpler and matches the repo style better.

## Keep dynamic completion reactive and bounded

- Prefer local, cheap sources: current repo files, local config, local state directories, or a command's own small `list`/`ls` output.
- Hard-limit dynamic queries (`--limit 10`, `--limit 50`, `head`, or equivalent). Never leave a completion path unbounded.
- Silence incidental errors with `2>/dev/null` and return an empty result instead of printing noise.
- Guard optional tools and files before reading them (`command -v`, `[[ -r file ]]`, `[[ -d dir ]]`).
- Do not perform long-running, recursive, interactive, state-changing, or obviously network-heavy work in completion code.
- Prefer local arrays and local variables. Use globals only for a deliberate cache.
- Cache only when repeated bounded calls are still expensive. If caching is necessary, keep it small and easy to invalidate; `${XDG_DATA_HOME}/zsh/completions/_gh_custom.zsh` is the model, not the default.
- Always provide a fast fallback when dynamic data is missing.
- Escape literal `:` characters in completion values before passing them to `_describe`; `${XDG_DATA_HOME}/zsh/completions/_opencode` does this for model names.

## Validate the completion the way this repo does

- Run syntax checks with `make -C ${XDG_DATA_HOME}/zsh zsh.lint`.
- Add or update focused Bats tests in `${XDG_DATA_HOME}/zsh/test/completions/` when the command is new or the completion logic is non-trivial. Use `${XDG_DATA_HOME}/zsh/test/completions/_astro.bats` as the pattern for command-specific checks.
- Run the completion test suite with `make -C ${XDG_DATA_HOME}/zsh zsh.test` after changing completion behavior or tests.
- Spot-check interactively in a fresh zsh when possible. This repo loads custom completions through `${XDG_DATA_HOME}/zsh/config/completion.zsh`, prepends the completions directory to `fpath`, and caches `compinit` output.
- If the file name or `#compdef` line changes and the shell still behaves as if nothing changed, rebuild the completion dump or restart the shell before debugging further.

## Use the local examples deliberately

- `${XDG_DATA_HOME}/zsh/completions/_skills`: direct command dispatch plus small dynamic helpers.
- `${XDG_DATA_HOME}/zsh/completions/_airflow`: large tree split into helper functions.
- `${XDG_DATA_HOME}/zsh/completions/_opencode`: grouped domains, nested dispatch, and bounded local discovery.
- `${XDG_DATA_HOME}/zsh/completions/_gh_custom.zsh`: dynamic completion with selective caching and fast fallbacks.

Optimize for fast, quiet, maintainable completions. In this repo, a slightly smaller completion that responds immediately is better than a clever one that blocks on data gathering.

---

## Advanced Zsh Scripting & Architecture Guidelines

When writing custom shell tools, prompt modifications, or terminal plugins, autocompletions are only one component. Interactive shell extensions must be visually pleasing, lightning-fast, safe, and completely non-blocking.

To achieve this, explore our comprehensive, categorized best-practice guides:

- ⏳ **[Asynchronous & Non-blocking Programming](./references/async-non-blocking.md):** Learn how to offload heavy disk/network/Git status operations to background workers.
- ⚡ **[High-Performance Zsh (Zero-Fork Pattern)](./references/performance-zero-fork.md):** Master native Zsh features, built-ins, and high-speed in-process string transformations (no `sed`, `awk`, or subprocess spawns).
- 🛡️ **[Option Isolation, Scoping, & Environment Safety](./references/safety-scoping-options.md):** Ensure your scripts are sandboxed safely using local options and proper namespaces without side-effects.
- ⚙️ **[API-Driven Configuration with zstyle](./references/zstyle-configuration.md):** Design clean, user-configurable plugin options using Zsh's standard configuration registry.

