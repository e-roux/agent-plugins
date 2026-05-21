# Changelog

## [Unreleased]

## [1.1.0] - 2026-05-21

### Added
- `sessionStart` hook injects minimal cost-aware context (AOP pattern — ~25 tokens, model-agnostic)
- `cost-optimization` skill with model hierarchy table, token compounding formula, and optimization checklist
- `config/rates.json` versioned model multiplier configuration (0× included → 50× ultra)
- `--drivers` flag for `report.sh` — shows cost drivers: tier breakdown, premium %, avg tokens/request, optimization warnings
- Actionable warnings when premium usage >50% or avg tokens/request >50K

## [1.0.0] - 2026-05-21

### Added
- `token-usage` skill for natural-language Copilot usage queries (daily/weekly/monthly, per-model)
- `sessionEnd` hook that persists each session's token data to `$COPILOT_HOME/plugin-data/e-roux-plugins/billing/usage.jsonl`
- `scripts/report.sh` standalone report generator: reads `session.shutdown` events, aggregates by model, reports premium requests and all five token types
