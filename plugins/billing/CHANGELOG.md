# Changelog

## [Unreleased]

## [1.0.0] - 2026-05-21

### Added
- `token-usage` skill for natural-language Copilot usage queries (daily/weekly/monthly, per-model)
- `sessionEnd` hook that persists each session's token data to `$COPILOT_HOME/plugin-data/e-roux-plugins/billing/usage.jsonl`
- `scripts/report.sh` standalone report generator: reads `session.shutdown` events, aggregates by model, reports premium requests and all five token types
