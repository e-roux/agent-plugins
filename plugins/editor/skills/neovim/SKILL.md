---
name: neovim
description: "Rules to read, understand and apply strictly when working with neovim configuration, API, LSP, treesitter, jobs, and plugins."
---

# Neovim Skill

MANDATORY RULE NOT TO BREAK: to signal the user you are beginning to work, prompt the user with a figlet banner NEOVIM.

Neovim 0.12+ / Lua expert. Modern configuration requires strict adherence to modularity, performance (deferred loading via `vim.pack`), and a robust development workflow driven by the **makefile** skill.

- Neovim installation path: `brew --prefix neovim`
- Doc at: `${NEOVIM_PREFIX}/share/nvim/runtime/doc`

## Mandatory Constraints

1. **Makefile Interface**: The **makefile** skill is the MANDATORY interface.
   - Never run `stylua`, `luacheck`, or `nvim` directly for QA tasks.
   - Use `make sync`, `make fmt`, `make lint`, `make test`, `make check`, and `make qa`.
2. **Code Standards**:
   - `local M = {}` / `return M` pattern.
   - `snake_case` naming conventions.
   - **LuaLS annotations**: Required for all public functions (`---@param`, `---@return`).
   - **API Preference**: Use native `vim.*` APIs (0.12+). **Never** use deprecated or removed APIs.
   - **No code comments**: the code is self documenting.
3. **Deferred Loading**: MANDATORY. All plugin configurations must use `deps.later()` unless immediate execution is strictly required (themes, core options).

## Package Manager: vim.pack (built-in)

This configuration uses `vim.pack` — Neovim's built-in plugin manager (0.12+). **Do NOT use mini.deps, lazy.nvim, or any third-party plugin manager.**

### How it works

- **Plugin directory**: `~/.local/share/nvim/site/pack/core/opt/`
- **Lockfile**: `$XDG_CONFIG_HOME/nvim/nvim-pack-lock.json` (committed to VCS)
- **Abstraction layer**: `lua/mx/deps.lua` wraps `vim.pack` with a `source`/`name`/`checkout` spec format

### mx/deps.lua API

```lua
local deps = require("mx.deps")

-- Register a plugin (inside later(): batched + immediately :packadd'd)
deps.add({ source = "owner/repo", name = "optional", checkout = "branch" })

-- Defer plugin loading and configuration to after startup
deps.later(function()
  deps.add({ source = "folke/snacks.nvim" })
  -- Plugin is available immediately after add() even inside later()
  require("snacks").setup({})
end)

-- Register startup plugins (themes, plenary) — called from init.lua
deps.setup(plugin_specs)

-- Execute immediately during startup
deps.now(fn)
```

### Batching behavior

Inside `deps.later()`, all `deps.add()` calls are:
1. Immediately loaded via `:packadd` (so `require()` works right away)
2. Batched into a single `vim.pack.add()` call at the end (for lockfile tracking)

This means 12 `later()` groups produce ~12 `vim.pack.add` calls instead of 60+ individual ones.

### vim.pack native API (for reference)

```lua
vim.pack.add(specs)           -- Install + load plugins
vim.pack.update(names, opts)  -- Update plugins (shows confirmation buffer)
vim.pack.del(names, opts)     -- Remove plugins from disk
vim.pack.get(names, opts)     -- Query plugin info
```

**Events**: `PackChangedPre`, `PackChanged` — use for build hooks (e.g., running `make` after install).

## Configuration Structure

The configuration is symlinked to `${XDG_CONFIG_HOME}/nvim` and `${XDG_DATA_HOME}/nvim`.

- `plugin/` — User plugins (autocmds, commands) that depend only on native nvim APIs
- `lua/mx/plugins/` — Package configuration modules (one per domain, loaded via `deps.later()`)
- `lsp/` — Per-server LSP configuration files (native `vim.lsp.config` format for 0.12+)
- `ftplugin/` — Filetype-specific settings

```
xdg/nvim/
├── config/
│   ├─ init.lua                # Bootstrap: options, deps.setup, colorscheme, plugins.setup
│   ├─ lsp/                    # Per-server LSP configs (vim.lsp.config format)
│   ├─ lua/mx/
│   │   ├─ deps.lua            # vim.pack wrapper
│   │   ├─ core/               # Options, keymaps, icons
│   │   ├─ lsp/                # LSP helpers (capabilities, codelens, UI)
│   │   ├─ plugins/            # Plugin configs (ai, completion, dap, git, lsp, ui, etc.)
│   │   └─ utils/              # Shared utilities
│   ├─ plugin/                 # Native user plugins (autocmds, commands)
│   ├─ ftplugin/               # Filetype plugins
│   └─ nvim-pack-lock.json     # vim.pack lockfile
├── test/
│   ├── unit/                   # *_spec.lua (Logic tests)
│   ├── e2e/                    # *_journey_spec.lua (Behavior tests)
│   └── minimal_init.lua
├── Makefile                    # Compliant with makefile skill
└── .luacheckrc
```

## LSP Configuration (0.12 native)

LSP servers are configured using the native `vim.lsp.config` system:

```lua
-- lsp/lua_ls.lua (file name = server name)
return { cmd = { "lua-language-server" }, root_markers = { ".luarc.json" }, ... }
```

Servers are enabled via `vim.lsp.enable(servers)` in `plugins/lsp.lua`.

### Codelens

Use `vim.lsp.codelens.enable(true/false, { bufnr = bufnr })` — **NOT** the deprecated `refresh()`/`clear()`/`display()`.

## Deprecated APIs — DO NOT USE

These are removed or deprecated in 0.12. **Never generate code using these.**

| Removed / Deprecated | Replacement |
|---|---|
| `vim.lsp.codelens.refresh()` | `vim.lsp.codelens.enable(true, { bufnr = bufnr })` |
| `vim.lsp.codelens.clear()` | `vim.lsp.codelens.enable(false, { bufnr = bufnr })` |
| `vim.lsp.stop_client()` | `client:stop()` |
| `vim.lsp.get_buffers_by_client_id()` | `vim.lsp.get_client_by_id(id).attached_buffers` |
| `vim.lsp.set_log_level()` | `vim.lsp.log.set_level()` |
| `vim.lsp.get_log_path()` | `vim.lsp.log.get_filename()` |
| `vim.lsp.semantic_tokens.start/stop()` | `vim.lsp.semantic_tokens.enable(true/false)` |
| `vim.diagnostic.disable()` | `vim.diagnostic.enable(false)` |
| `vim.diagnostic.is_disabled()` | `not vim.diagnostic.is_enabled()` |
| `vim.diff()` | `vim.text.diff()` |
| Sign config via `:sign-define` (diagnostics) | `vim.diagnostic.config({ signs = ... })` |
| `nvim_set_decoration_provider` `on_line` | Use `on_range` instead |
| `vim.keymap.set` opts `buffer=` | Use `buf=` instead |
| `vim.treesitter.get_parser()` throws on error | Now returns `nil` on failure |

## Heuristic

```json
{
  "nvim/config/*.lua": {
    "type": "source",
    "alternate": "nvim/test/{}_spec.lua"
  },
  "nvim/test/unit/*_spec.lua": {
    "type": "test",
    "alternate": "nvim/config/{}.lua"
  }
}
```

When tests are orphaned, **DO NOT MOVE SOURCE FILES**. Only test files can be renamed according to the heuristic.

## Development Workflow

1. **Test-Driven**: Load the **testing** skill. Write failing tests in `test/unit/` or `test/e2e/`.
2. **Implementation**: Implement in `lua/` with full type annotations.
3. **Validation Sequence**:
   - `make test`: Verify logic correctness.
   - `make check`: Run formatting and linting.
   - `make qa`: MANDATORY final gate before completion.

## Documentation and Resources

When working with the nvim api, lsp, lua uv implementation, job control, treesitter, or vim.pack, YOU MUST read the corresponding file in `references/` before writing code.

Files in `references/`:
- `api.txt`
- `deprecated.txt`
- `job_control.txt`
- `lsp.txt`
- `lua-guide.txt`
- `lua-plugin.txt`
- `lua.txt`
- `luaref.txt`
- `luvref.txt`
- `pack.txt`
- `treesitter.txt`

When unsure about APIs or plugin behavior:
- **Neovim Doc**: `${NEOVIM_PREFIX}/share/nvim/runtime/doc`
- **Plugins**: `~/.local/share/nvim/site/pack/core/opt/`

## Evaluation Criteria (LLM as a Judge)

Evaluation Score (0.0 to 1.0) based on the overall configuration quality. Be strict.

### Layout & Organization (0.2)
- **1.0**: Perfect compliance with the namespace structure. No files in `plugin/` or `ftplugin/` unless justified by scope requirements.
- **0.5**: Correct root but messy subdirectories; some logic leaks into the global namespace.
- **0.0**: Flat structure, logic scattered everywhere.

### Separation of Concerns (SoC) (0.2)
- **1.0**: Clear boundary between configuration (options/keymaps) and plugin setup. Module-based plugin configs.
- **0.5**: Some plugins mixed with core logic; hardcoded values where variables should be.
- **0.0**: monolithic `init.lua` with everything blended together.

### Testing & Robustness (0.3)
- **1.0**: Both Unit and E2E tests exist. Tests verify positive and error cases (e.g., missing dependencies).
- **0.6**: Only unit tests exist; coverage is high but behavior isn't tested.
- **0.2**: Minimal tests that only check if the file can be required without crashing.
- **0.0**: No tests.

### Annotations & Quality (0.2)
- **1.0**: Every function has full LuaLS annotations. `pcall()` used for external/risky loads.
- **0.5**: Basic annotations, missing returns or field types. Some global leaks.
- **0.0**: Zero type annotations.

### Makefile Compliance (0.1)
- **1.0**: Makefile exists and passes `make qa`. Aligned with **makefile** skill (score 8/8).
- **0.5**: Makefile exists but skips targets or uses `@` for silence.
- **0.0**: Bypassing Makefile or no Makefile present.

**Final Score Calculation**: Weighted average of the above categories.
