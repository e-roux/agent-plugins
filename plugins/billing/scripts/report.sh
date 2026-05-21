#!/usr/bin/env bash
# Report Copilot CLI token usage by aggregating session.shutdown events.
# Usage: report.sh [--period=day|week|month] [--days=N] [--help]
set -euo pipefail

command -v jq >/dev/null 2>&1 || { printf "ERROR: jq is required\n" >&2; exit 1; }

DAYS=7
for arg in "$@"; do
  case "$arg" in
    --period=day)   DAYS=1  ;;
    --period=week)  DAYS=7  ;;
    --period=month) DAYS=30 ;;
    --days=*)       DAYS="${arg#*=}" ;;
    --help|-h) printf "Usage: report.sh [--period=day|week|month] [--days=N]\n"; exit 0 ;;
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
