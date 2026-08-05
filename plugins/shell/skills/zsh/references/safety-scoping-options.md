# Option Isolation, Scoping, & Safety in Zsh

This reference describes guidelines for writing robust, self-contained Zsh functions that do not pollute the global namespace or inadvertently alter the user's active shell configurations.

---

## 1. Option Isolation (Local Options)

Zsh allows users to configure shell behaviors using thousands of individual options (e.g., word splitting, globbing behavior, error output). If a function is executed within the user's active shell (as most prompt or integration hooks are) and changes an option globally, it can break the user's entire environment.

Conversely, if your function depends on a specific shell option (such as word splitting) but the user has disabled it globally, your script will crash or misbehave.

**Rule:** Always isolate options locally at the start of any public function using `setopt localoptions`.

```zsh
my_utility_function() {
  # Set options locally so they revert to user defaults when the function exits
  setopt localoptions noshwordsplit warncreateglobal
  
  # noshwordsplit: prevents variables from splitting on spaces unless explicitly requested
  # warncreateglobal: prints a warning during development if you accidentally create a global variable without 'local' or 'typeset'
}
```

---

## 2. Variable Scoping and Namespace Hygiene

Always restrict variables to the minimum required scope. Global namespace pollution is a major source of bugs, conflicts, and slow shell load times.

- **Declare Local Variables:** Always prefix internal function variables with `local`.
  ```zsh
  # ✗ Forbidden: leaks 'my_var' into the user's global session
  my_var="value" 
  
  # ✓ Correct: isolated to the function stack
  local my_var="value"
  ```
- **Explicit Global Declarations:** If a variable *must* be global (such as a shared cache or state across callbacks), declare it explicitly with `typeset -g` or `typeset -gA` (for associative arrays). This makes its global nature self-documenting.
  ```zsh
  typeset -g prompt_my_plugin_last_check=0
  typeset -gA prompt_my_plugin_cache
  ```
- **Namespacing:** Prefix all global variables, functions, and helper routines with a unique plugin-specific namespace to prevent conflicts with other third-party shell plugins.
  ```zsh
  # ✗ Bad names (risk of collision)
  local branch
  get_status() { ... }
  
  # ✓ Namespaced names (safe and unique)
  typeset -g prompt_myplugin_git_branch
  prompt_myplugin_get_git_status() { ... }
  ```

---

## 3. Safe Option Scoping Patterns

When writing complex multi-function plugins, establish standard options that are safe and predictable:

| Option / Setting | Standard Value | Why it is recommended |
|------------------|----------------|-----------------------|
| `noshwordsplit`  | Active (`setopt noshwordsplit`) | Mimics standard programming languages where string parameters are treated as singular values instead of splitting on spaces. |
| `warncreateglobal` | Active during dev | Catches missing `local` declarations immediately. |
| `localoptions`   | Active (`setopt localoptions`) | Reverts all option changes when the function exits. |
| `localtraps`     | Active (`setopt localtraps`) | Reverts any signal traps set inside the function when exiting. |

### Robust Function Template
```zsh
# A standard robust function template
prompt_my_plugin_helper() {
  setopt localoptions localtraps noshwordsplit warncreateglobal
  
  local input_value=$1
  local -a internal_array
  
  # ... function logic ...
  
  return 0
}
```
