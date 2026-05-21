---
name: cost-optimization
description: >
  Copilot token efficiency and AI Credit optimization strategies.
  Use when the user asks about reducing Copilot token spend, model routing
  for cost, AI Credits budget, premium model usage reduction, or
  token-efficient session patterns.
---

# Cost Optimization — Copilot AI Credits

## Model cost hierarchy (June 2026 billing)

| Tier | Models | Multiplier | Use for |
|------|--------|-----------|---------|
| Included | GPT-4.1, GPT-5-mini, GPT-4o | 0× | Chat, formatting, simple transforms |
| Budget | Gemini 2.0 Flash | 0.25× | Research, summarization |
| Standard | Sonnet 4 | 1× | Implementation, reviews |
| Premium | Claude Opus 4 | 10× | Complex architecture, nuanced reasoning |
| Ultra | GPT-4.5 | 50× | Almost never justified |

## Optimization checklist

1. **Run usage report** — `bash "$SCRIPT" --period=week --drivers` to identify cost drivers
2. **Identify premium model overuse** — Sessions using Opus for routine coding
3. **Check context growth** — High cache-write tokens signal bloated first-turn context
4. **Evaluate delegation** — Long sessions (>20 turns) compound input tokens superlinearly
5. **Re-measure** — Compare week-over-week after changes

## Token compounding formula

Each turn sends full conversation history as input:
```
Turn N cost ≈ system_prompt + Σ(all_prior_turns) + current_turn
```
A 30-turn session with 10K avg context → turn 30 processes ~300K input tokens.

## High-impact patterns

### Delegation (when it saves)
- ✅ Isolated subtask with large context (research, file analysis)
- ✅ Parallelizable independent work items
- ❌ Small edits or lookups (delegation overhead > savings)

### Hooks over instructions
Every line of "don't do X" in a skill costs tokens per turn.
A `preToolUse` hook that blocks X costs zero tokens per turn.
Move enforcement to hooks; keep skills for guidance only.

### Tool isolation
MCP tool schemas occupy system prompt space on every request.
Scope tool registrations per-agent: code agents get code tools only.

### Context diet
- Load skills on-demand (trigger phrases), not always-on
- Keep working context < 10KB
- Summarize and delegate instead of carrying 50-turn history

## Locating the report script

```bash
if [ -n "${COPILOT_HOME:-}" ] && [ -d "$COPILOT_HOME/session-state" ]; then
  :
elif [ -d "$HOME/.copilot/session-state" ]; then
  COPILOT_HOME="$HOME/.copilot"
else
  COPILOT_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/copilot"
fi
SCRIPT="$COPILOT_HOME/installed-plugins/e-roux-plugins/billing/scripts/report.sh"
```

## Key metrics to monitor

- **Cache-write tokens** — Billed at ~3.75× input rate (first turn in context)
- **Premium model %** — Ratio of Opus/GPT-4.5 calls to total
- **Input tokens per turn** — Growing = context bloat
- **Session length** — Longer = more compounding
