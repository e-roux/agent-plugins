# API-Driven Configuration with zstyle in Zsh

This reference describes best practices for designing configurable Zsh plugins and prompt integrations using Zsh's standard, native `zstyle` registry.

---

## 1. Why Use zstyle?

Many shell script authors configure their plugins by exposing hundreds of global shell variables (e.g., `MY_PLUGIN_SHOW_TIME=true`). This pollutes the environment namespace, is error-prone, and is difficult to scope cleanly.

Zsh provides a powerful, native, centralized configuration registry called `zstyle`. It acts as an API-driven configuration system where users define settings in a hierarchically-scoped manner.

---

## 2. Reading Config Settings in Your Code

Use Zsh's built-in `zstyle` commands to retrieve configuration values. Always provide safe fallbacks for when user configuration is absent.

### A. Retrieving String Values
Use `zstyle -s <context> <style_name> <variable>` to read a style as a string:
```zsh
# Read the configured prompt symbol; fallback to '❯' if unset
local prompt_symbol
zstyle -s ":prompt:my_plugin:options" symbol prompt_symbol || prompt_symbol='❯'
```

### B. Checking Boolean Styles (True/False)
Use `zstyle -t <context> <style_name>` to test if a style evaluates to true (e.g., yes, true, on, 1):
```zsh
# Only display the hostname if show_host is configured as true/yes/1
if zstyle -t ":prompt:my_plugin:options" show_host; then
  # Hostname rendering logic
fi
```

### C. Checking Boolean Styles with Default True
Use `zstyle -T <context> <style_name>` to test if a style evaluates to true, defaulting to **true** if the style is unset:
```zsh
# Show title unless the user explicitly configured show_title to no/false/0
zstyle -T ":prompt:my_plugin:options" show_title || return
```

---

## 3. How Users Configure Your Plugin

Provide a clean namespace pattern for your plugin's configurations so users can define settings easily in their `.zshrc`:

```zsh
# Context format: :<type>:<plugin_name>:<scope>
# Examples of user configurations:
zstyle :prompt:my_plugin:options symbol "⚡"
zstyle :prompt:my_plugin:options show_host yes
zstyle :prompt:my_plugin:options show_time no
```

---

## 4. Summary of zstyle Commands

| Command | Return Code / Behavior | Common Use Case |
|---------|-------------------------|-----------------|
| `zstyle -s` | Returns `0` if style exists; stores value in variable. | Fetching custom paths, icons, colors, or command limits. |
| `zstyle -t` | Returns `0` if style exists and evaluates to true/yes/on/1. | Checking optional/opt-in flags (defaults to false). |
| `zstyle -T` | Returns `0` if style evaluates to true/yes/on/1 OR is unset. | Checking opt-out configurations (defaults to true). |
| `zstyle -a` | Returns `0` if style exists; stores multiple values in array. | Retrieving lists of directories, ignores, or arrays. |
