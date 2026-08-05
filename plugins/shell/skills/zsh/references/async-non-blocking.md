# Asynchronous & Non-blocking Zsh Programming

This reference describes the design patterns and best practices for performing asynchronous background operations in Zsh without causing shell UI latency or freezing the terminal.

---

## 1. The Non-Blocking Mandate

Any synchronous operation that queries a slow external resource (e.g., disk crawl, git status, remote HTTP endpoints, container inspect, or database queries) blocks Zsh's main execution loop. This introduces noticeable latency to the user's interactive terminal typing, prompt rendering, or directory navigation.

**Rule:** Offload any disk-bound, network-bound, or external process execution to a background worker.

---

## 2. The Async Worker Lifecycle

A high-performance async pattern in Zsh consists of four main phases:

1. **Initialization:** Starting a dedicated background process (using an async framework like `async.zsh` or custom background job management).
2. **Task Submission:** Submitting a specific task to the background process during main hooks (e.g., `precmd` or `chpwd`).
3. **Execution:** The background worker runs the heavy job entirely in a subshell without blocking the interactive main thread.
4. **Callback & Rendering:** The worker fires a completion callback, which parses the results and triggers a prompt or terminal redraw via `zle reset-prompt`.

---

## 3. Implementing the Async Pattern

A robust, standard implementation of the asynchronous pattern:

```zsh
# 1. Setup and worker initialization
init_async_worker() {
  # Load the async framework
  autoload -Uz async && async

  # Initialize a named async worker
  async_init "my_plugin_worker"

  # Register callback function to handle outputs
  async_register_callback "my_plugin_worker" my_plugin_async_callback
}

# 2. Triggering the async task during precmd (runs before every prompt display)
my_plugin_precmd() {
  # Submit task to the background worker
  async_job "my_plugin_worker" get_git_status_heavy
}

# 3. The actual worker function (runs entirely in a background subshell/process)
get_git_status_heavy() {
  # Perform disk-bound, heavy operations here safely
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local branch=$(git branch --show-current 2>/dev/null)
    local dirty=
    git diff --quiet --exit-code 2>/dev/null || dirty="*"
    
    # Print output; the async framework captures stdout and passes it to the callback
    print -r -- "${branch}|${dirty}"
  fi
}

# 4. Callback function (executed on the main thread when background job completes)
my_plugin_async_callback() {
  local job_name=$1 return_code=$2 stdout=$3 execution_time=$4 error_output=$5
  
  if [[ $job_name == "get_git_status_heavy" && $return_code -eq 0 ]]; then
    # Parse the stdout using Zsh's high-speed string splitting
    local -a parts
    parts=(${(s:|:)stdout})
    
    typeset -g my_plugin_git_branch="${parts[1]}"
    typeset -g my_plugin_git_dirty="${parts[2]}"
    
    # Crucial: Reset/redraw prompt to show newly fetched asynchronous data!
    if (( $+widgets[reset-prompt] )); then
      zle reset-prompt
    fi
  fi
}
```

---

## 4. Safety Constraints for Async Code

- **Flush on Interactive Commands:** If the user initiates a command that conflicts with the async worker (e.g., the user runs `git pull` while the worker is checking git status), flush active worker jobs immediately using `async_flush_jobs` to prevent race conditions or file locks.
- **Redirect Stderr:** Always silence background subshell errors (`2>/dev/null`) to prevent noise from leaking into the user's interactive terminal.
- **Limit Worker Spawns:** Never spawn workers repeatedly without checking if they are already running or if the previous job is still active.
