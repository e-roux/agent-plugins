#!/usr/bin/env bash
# Report Copilot CLI token usage by aggregating session.shutdown events.
# Usage: report.sh [--period=day|week|month] [--days=N] [--drivers] [--help]
set -euo pipefail

command -v jq >/dev/null 2>&1 || { printf "ERROR: jq is required\n" >&2; exit 1; }

DAYS=7
SHOW_DRIVERS=0
for arg in "$@"; do
  case "$arg" in
    --period=day)   DAYS=1  ;;
    --period=week)  DAYS=7  ;;
    --period=month) DAYS=30 ;;
    --days=*)       DAYS="${arg#*=}" ;;
    --drivers)      SHOW_DRIVERS=1 ;;
    --help|-h) printf "Usage: report.sh [--period=day|week|month] [--days=N] [--drivers]\n"; exit 0 ;;
  esac
done

_find_copilot_home() {
  if [ -n "${COPILOT_HOME:-}" ] && [ -d "$COPILOT_HOME/session-state" ]; then
    printf '%s' "$COPILOT_HOME"; return
  fi
  for try in "$HOME/.copilot" "${XDG_CONFIG_HOME:-$HOME/.config}/copilot"; do
    [ -d "$try/session-state" ] && { printf '%s' "$try"; return; }
  done
  return 1
}

COPILOT_HOME=$(_find_copilot_home) \
  || { printf "ERROR: Copilot session data not found. Set COPILOT_HOME.\n" >&2; exit 1; }

CUTOFF_EPOCH=$(date -d "${DAYS} days ago" +%s 2>/dev/null \
  || date -v "-${DAYS}d" +%s 2>/dev/null \
  || echo 0)

_fmt() {
  local n=${1:-0}
  if   [ "$n" -ge 1000000 ]; then printf "%dM" $(( n / 1000000 ))
  elif [ "$n" -ge 1000    ]; then printf "%dK" $(( n / 1000 ))
  else printf "%d" "$n"
  fi
}

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

while IFS= read -r f; do
  grep -h '"type":"session.shutdown"' "$f" 2>/dev/null || true
done < <(find "$COPILOT_HOME/session-state" -name "events.jsonl" 2>/dev/null) \
  > "$TMPFILE"

REPORT=$(jq -sr --argjson cutoff "$CUTOFF_EPOCH" '
  reduce (
    .[] | select((.timestamp // 0) / 1000 >= $cutoff)
  ) as $e (
    {sessions: 0, premium: 0, duration_ms: 0, models: {}};
    .sessions    += 1 |
    .premium     += ($e.data.totalPremiumRequests // 0) |
    .duration_ms += ($e.data.totalApiDurationMs  // 0) |
    reduce ($e.data.modelMetrics // {} | to_entries[]) as $m (
      .;
      .models[$m.key] //= {reqs:0, cost:0, input:0, output:0, cache_w:0, cache_r:0, reason:0} |
      .models[$m.key].reqs    += ($m.value.requests.count             // 0) |
      .models[$m.key].cost    += ($m.value.requests.cost              // 0) |
      .models[$m.key].input   += ($m.value.usage.inputTokens          // 0) |
      .models[$m.key].output  += ($m.value.usage.outputTokens         // 0) |
      .models[$m.key].cache_w += ($m.value.usage.cacheWriteTokens     // 0) |
      .models[$m.key].cache_r += ($m.value.usage.cacheReadTokens      // 0) |
      .models[$m.key].reason  += ($m.value.usage.reasoningTokens      // 0)
    )
  )
' "$TMPFILE")

SESSIONS=$(printf '%s' "$REPORT"    | jq -r '.sessions')
PREMIUM=$(printf '%s' "$REPORT"     | jq -r '.premium')
DURATION_MS=$(printf '%s' "$REPORT" | jq -r '.duration_ms')
DURATION_MIN=$(( DURATION_MS / 60000 ))

if [ "${SESSIONS:-0}" = "0" ]; then
  printf "No Copilot sessions found in the last %d day(s).\n" "$DAYS"
  exit 0
fi

SEP=$(printf '%0.s─' {1..89})

printf "\n=== Copilot Usage — last %d day(s) ===\n\n" "$DAYS"
printf "  Sessions : %s\n"              "$SESSIONS"
printf "  Premium  : %s requests\n"    "$PREMIUM"
printf "  API time : %d min\n\n"       "$DURATION_MIN"

printf "%-28s %5s %5s %8s %8s %9s %8s %8s\n" \
  "MODEL" "REQS" "PREM" "INPUT" "OUTPUT" "CACHE-W" "CACHE-R" "REASON"
printf "%s\n" "$SEP"

printf '%s' "$REPORT" | jq -r '
  .models | to_entries | sort_by(-.value.cost) | .[] |
  [.key, .value.reqs, .value.cost,
   .value.input, .value.output,
   .value.cache_w, .value.cache_r, .value.reason] | @tsv
' | while IFS=$'\t' read -r model reqs cost inp out cw cr reason; do
  printf "%-28s %5s %5s %8s %8s %9s %8s %8s\n" \
    "$model" "$reqs" "$cost" \
    "$(_fmt "${inp:-0}")" "$(_fmt "${out:-0}")" \
    "$(_fmt "${cw:-0}")"  "$(_fmt "${cr:-0}")"  "$(_fmt "${reason:-0}")"
done

printf "\n"
printf "PREM    = premium request units consumed (GitHub billing metric)\n"
printf "CACHE-W = cache write tokens (billed at higher rates, first call in context)\n"
printf "CACHE-R = cache read tokens (cheap, reuses prior context)\n"

if [ "$SHOW_DRIVERS" -eq 1 ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RATES_FILE="$SCRIPT_DIR/../config/rates.json"

  printf "\n=== Cost Drivers ===\n\n"

  DRIVERS=$(printf '%s' "$REPORT" | jq -r --argjson rates "$(cat "$RATES_FILE" 2>/dev/null || echo '{}')" '
    .models | to_entries |
    # Compute weighted cost per model
    map({
      model: .key,
      reqs: .value.reqs,
      cost: .value.cost,
      input: .value.input,
      output: .value.output,
      cache_w: .value.cache_w,
      cache_r: .value.cache_r,
      reason: .value.reason,
      total_tokens: (.value.input + .value.output + .value.cache_w + .value.cache_r + .value.reason),
      multiplier: ($rates.multipliers[.key] // 1),
      tier: (
        if ($rates.multipliers[.key] // 1) == 0 then "included"
        elif ($rates.multipliers[.key] // 1) <= 0.25 then "budget"
        elif ($rates.multipliers[.key] // 1) <= 1 then "standard"
        elif ($rates.multipliers[.key] // 1) <= 10 then "premium"
        else "ultra" end
      )
    }) |
    # Aggregate by tier
    group_by(.tier) | map({
      tier: .[0].tier,
      multiplier: .[0].multiplier,
      reqs: (map(.reqs) | add),
      tokens: (map(.total_tokens) | add),
      weighted: (map(.total_tokens * .multiplier) | add)
    }) |
    sort_by(-.weighted) |
    # Top cost driver
    (.[0] // {tier:"none",reqs:0,tokens:0,weighted:0}) as $top |
    # Total tokens and requests
    (map(.tokens) | add // 0) as $total_tokens |
    (map(.reqs) | add // 0) as $total_reqs |
    (map(.weighted) | add // 0) as $total_weighted |
    # Premium ratio
    (map(select(.tier == "premium" or .tier == "ultra")) | map(.reqs) | add // 0) as $premium_reqs |
    {
      top_tier: $top.tier,
      top_multiplier: $top.multiplier,
      top_weighted_pct: (if $total_weighted > 0 then (($top.weighted / $total_weighted) * 100 | round) else 0 end),
      premium_pct: (if $total_reqs > 0 then (($premium_reqs / $total_reqs) * 100 | round) else 0 end),
      total_tokens: $total_tokens,
      avg_tokens_per_req: (if $total_reqs > 0 then ($total_tokens / $total_reqs | round) else 0 end),
      tiers: .
    }
  ')

  TOP_TIER=$(printf '%s' "$DRIVERS" | jq -r '.top_tier')
  TOP_PCT=$(printf '%s' "$DRIVERS" | jq -r '.top_weighted_pct')
  PREMIUM_PCT=$(printf '%s' "$DRIVERS" | jq -r '.premium_pct')
  AVG_TOK=$(printf '%s' "$DRIVERS" | jq -r '.avg_tokens_per_req')
  TOTAL_TOK=$(printf '%s' "$DRIVERS" | jq -r '.total_tokens')

  printf "  Highest cost tier   : %s (%s%% of weighted spend)\n" "$TOP_TIER" "$TOP_PCT"
  printf "  Premium model usage : %s%% of requests\n" "$PREMIUM_PCT"
  printf "  Avg tokens/request  : %s\n" "$(_fmt "$AVG_TOK")"
  printf "  Total token exposure: %s\n\n" "$(_fmt "$TOTAL_TOK")"

  printf "%-12s %6s %10s %12s %8s\n" "TIER" "REQS" "TOKENS" "WEIGHTED" "MULT"
  printf '%0.s─' {1..52}; printf "\n"

  printf '%s' "$DRIVERS" | jq -r '
    .tiers[] | [.tier, .reqs, .tokens, .weighted, .multiplier] | @tsv
  ' | while IFS=$'\t' read -r tier reqs tokens weighted mult; do
    printf "%-12s %6s %10s %12s %8s×\n" \
      "$tier" "$reqs" "$(_fmt "${tokens:-0}")" "$(_fmt "${weighted:-0}")" "$mult"
  done

  printf "\n"
  if [ "$PREMIUM_PCT" -gt 50 ]; then
    printf "⚠ OPTIMIZATION: >50%% premium model usage. Consider Sonnet for routine tasks.\n"
  fi
  if [ "$AVG_TOK" -gt 50000 ]; then
    printf "⚠ OPTIMIZATION: High avg tokens/request (%sK). Consider shorter sessions or delegation.\n" "$(( AVG_TOK / 1000 ))"
  fi
  printf "Note: Only cleanly shutdown sessions are included.\n"
fi
