# Symbol / Function Search — pick the right tier

From fastest+dumbest to slowest+smartest. Pick the cheapest tier that answers the question.

## 1. Plain text search — know the exact name
```bash
rg "def my_function" --type py
rg -w "MyClass"          # word-boundary, avoids matching substrings
rg --files | fzf         # interactive fuzzy file jump
```
No semantic understanding — matches comments/strings too. Good enough when the name is distinctive.

## 2. Tag-based indexing — fast, no compiler needed
- **universal-ctags** — builds a symbol index, editors jump via `:tag`. Still the fastest option on huge repos (e.g. Linux kernel scale).
- **cscope** — similar, historically C-focused, still common in large C/C++ trees.

## 3. Tree-sitter structural search — know the shape, not the exact name
- **ast-grep** — query by AST pattern.
  ```bash
  ast-grep run -p 'function $NAME($$$) { $$$ }'
  ```
- `tree-sitter query` CLI for raw grammar control.
This is the sweet spot for "quickly, and actually understands code structure" without needing a running language server.

## 4. LSP — most accurate, needs project indexed/buildable
Access via editor (VS Code, Neovim, Zed) or headlessly via `multilspy` (Python) to script it.
- `textDocument/documentSymbol` — all symbols in a file
- `workspace/symbol` — fuzzy symbol search across the whole project
- `textDocument/definition` — jump to definition
- `textDocument/references` — find all usages (the accuracy backstop for dead-code verification)

Only tier that correctly resolves overloads, imports, and cross-file references. Slower to spin up (project must build/index) and heavier per-query — use surgically, not as the primary discovery mechanism across a whole repo.

## 5. Semantic / embedding search — know only what it does, not its name
- **Sourcegraph** (`src search` CLI, self-hosted or cloud) — combines exact + structural + fuzzy search at scale.
- Local embedding index (e.g. via Cody or a custom embedding search) when you can only describe behavior ("the function that retries failed uploads").

## Rule of thumb
| You know | Use |
|---|---|
| Exact name | `rg` / ctags |
| Shape, not name | `ast-grep` |
| Need "who calls this" accurately | LSP |
| Only what it does | Sourcegraph / embeddings |
