#!/usr/bin/env bash
# Chains repo scoping + dead-code detection + duplicate detection + complexity +
# coupling + churn into a single JSON findings report, so an LLM only needs to
# read the summary, not the repo.
#
# Usage: ./audit.sh <path-to-repo> [output-dir]
#
# Requires whichever of these are relevant to the repo's language(s):
#   tokei, scc, jscpd (npx), knip (npx, JS/TS), vulture/ruff (Python),
#   deadcode (Go), gocyclo/gocognit (Go), cargo-udeps (Rust), lizard/radon (complexity),
#   madge (npx, JS/TS)/pydeps (Python)/go mod graph (coupling), git (churn)
# Missing tools are skipped with a warning rather than failing the run.

set -uo pipefail

REPO="${1:-.}"
OUT="${2:-./audit-out}"
mkdir -p "$OUT"

echo "== Scoping repo: $REPO =="
if command -v tokei >/dev/null; then
  tokei "$REPO" --output json > "$OUT/loc.json" 2>"$OUT/tokei.err"
  echo "  -> $OUT/loc.json"
elif command -v scc >/dev/null; then
  scc "$REPO" --format json > "$OUT/loc.json" 2>"$OUT/scc.err"
  echo "  -> $OUT/loc.json (using scc)"
else
  echo "  [skip] tokei or scc not installed (brew install tokei scc)"
fi

echo "== Duplicate detection (jscpd) =="
if command -v npx >/dev/null; then
  npx --yes jscpd "$REPO" --min-lines 5 --threshold 0 \
    --reporters json --output "$OUT/jscpd" 2>"$OUT/jscpd.log"
  echo "  -> $OUT/jscpd/jscpd-report.json"
else
  echo "  [skip] npx not found"
fi

echo "== Dead code detection (auto-detect language) =="
if [ -f "$REPO/package.json" ]; then
  echo "  JS/TS repo detected -> knip"
  (cd "$REPO" && npx --yes knip --reporter json) > "$OUT/deadcode-js.json" 2>"$OUT/knip.log" || \
    echo "  [warn] knip run failed, see $OUT/knip.log"
fi
if compgen -G "$REPO/*.py" > /dev/null || [ -f "$REPO/pyproject.toml" ]; then
  echo "  Python repo detected -> vulture + ruff"
  if command -v vulture >/dev/null; then
    vulture "$REPO" --min-confidence 80 > "$OUT/deadcode-python-vulture.txt" 2>"$OUT/vulture.log" || true
  fi
  if command -v ruff >/dev/null; then
    ruff check --select F401,F841 "$REPO" --output-format json > "$OUT/deadcode-python-ruff.json" 2>"$OUT/ruff.log" || true
  fi
fi
if [ -f "$REPO/go.mod" ]; then
  echo "  Go repo detected -> deadcode"
  if command -v deadcode >/dev/null; then
    (cd "$REPO" && deadcode ./...) > "$OUT/deadcode-go.txt" 2>&1
  else
    echo "  [skip] deadcode not installed (go install golang.org/x/tools/cmd/deadcode@latest)"
  fi
fi
if [ -f "$REPO/Cargo.toml" ]; then
  echo "  Rust repo detected -> cargo build warnings (dead_code lint)"
  (cd "$REPO" && cargo build --message-format=json 2>&1 | grep -i dead_code) > "$OUT/deadcode-rust.txt" || true
fi

echo "== Structural complexity =="
if command -v lizard >/dev/null; then
  lizard "$REPO" --csv > "$OUT/complexity-lizard.csv" 2>"$OUT/lizard.log" || true
  echo "  -> $OUT/complexity-lizard.csv"
else
  echo "  [skip] lizard not installed (pip install lizard)"
fi
if compgen -G "$REPO/*.py" > /dev/null || [ -f "$REPO/pyproject.toml" ]; then
  if command -v radon >/dev/null; then
    radon cc "$REPO" -s -j > "$OUT/complexity-radon.json" 2>"$OUT/radon.log" || true
    echo "  -> $OUT/complexity-radon.json"
  else
    echo "  [skip] radon not installed (pip install radon)"
  fi
fi
if [ -f "$REPO/go.mod" ]; then
  if command -v gocyclo >/dev/null; then
    (cd "$REPO" && gocyclo .) > "$OUT/complexity-go-gocyclo.txt" 2>"$OUT/gocyclo.log" || true
    echo "  -> $OUT/complexity-go-gocyclo.txt"
  elif command -v gocognit >/dev/null; then
    (cd "$REPO" && gocognit .) > "$OUT/complexity-go-gocognit.txt" 2>"$OUT/gocognit.log" || true
    echo "  -> $OUT/complexity-go-gocognit.txt"
  fi
fi

echo "== Coupling / entanglement =="
if [ -f "$REPO/package.json" ] && command -v npx >/dev/null; then
  npx --yes madge --circular --json "$REPO" > "$OUT/coupling-madge.json" 2>"$OUT/madge.log" || \
    echo "  [warn] madge run failed, see $OUT/madge.log"
  echo "  -> $OUT/coupling-madge.json"
fi
if [ -f "$REPO/go.mod" ]; then
  (cd "$REPO" && go mod graph) > "$OUT/coupling-go.txt" 2>&1 || true
  echo "  -> $OUT/coupling-go.txt"
fi
if command -v pydeps >/dev/null && { compgen -G "$REPO/*.py" > /dev/null || [ -f "$REPO/pyproject.toml" ]; }; then
  pydeps "$REPO" --no-show --max-bacon 2 --show-deps > "$OUT/coupling-pydeps.json" 2>"$OUT/pydeps.log" || true
  echo "  -> $OUT/coupling-pydeps.json"
fi

echo "== Churn (most-edited files, last 90 days) =="
if command -v git >/dev/null && (cd "$REPO" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  (cd "$REPO" && git log --since="90 days ago" --format=format: --name-only -- . \
    | sort | uniq -c | sort -rg | head -20) > "$OUT/churn.txt"
  echo "  -> $OUT/churn.txt"
else
  echo "  [skip] not a git repo, or git not installed"
fi

echo ""
echo "== Composite entropy snapshot =="
if command -v python3 >/dev/null; then
  python3 - "$OUT" <<'PYEOF'
import json, sys, os, csv
out = sys.argv[1]

def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None

snapshot = {"tools_used": []}

# Scoping lines
loc = read_json(os.path.join(out, "loc.json"))
if loc:
    if isinstance(loc, dict) and "total" in loc:
        snapshot["total_code_lines"] = loc["total"].get("code", 0)
        snapshot["tools_used"].append("tokei")
    elif isinstance(loc, list):
        # scc format (list of dicts, with Code field)
        total_code = sum(item.get("Code", 0) for item in loc if isinstance(item, dict))
        snapshot["total_code_lines"] = total_code
        snapshot["tools_used"].append("scc")

jscpd = read_json(os.path.join(out, "jscpd", "jscpd-report.json"))
if jscpd:
    stats = jscpd.get("statistics", {}).get("total", {})
    snapshot["duplication_percent"] = stats.get("percentage")
    snapshot["tools_used"].append("jscpd")

deadcode_js = read_json(os.path.join(out, "deadcode-js.json"))
if deadcode_js is not None:
    if isinstance(deadcode_js, list):
        count = len(deadcode_js)
    elif isinstance(deadcode_js, dict):
        count = len(deadcode_js.get("issues", []))
    else:
        count = None
    snapshot["dead_code_findings_js"] = count
    snapshot["tools_used"].append("knip")

lizard_csv = os.path.join(out, "complexity-lizard.csv")
if os.path.exists(lizard_csv):
    try:
        ccns = []
        with open(lizard_csv) as f:
            for row in csv.reader(f):
                if len(row) > 1:
                    try:
                        ccns.append(float(row[1]))
                    except ValueError:
                        pass
        if ccns:
            snapshot["avg_cyclomatic_complexity"] = round(sum(ccns) / len(ccns), 2)
            snapshot["max_cyclomatic_complexity"] = max(ccns)
            snapshot["tools_used"].append("lizard")
    except Exception:
        pass

snapshot["note"] = (
    "Snapshot only, not a verdict. Compare against a prior baseline snapshot to get the "
    "before/after delta that actually matters -- see references/entropy.md."
)

with open(os.path.join(out, "entropy.json"), "w") as f:
    json.dump(snapshot, f, indent=2)

print(f"  -> {os.path.join(out, 'entropy.json')}")
PYEOF
else
  echo "  [skip] python3 not found, entropy.json not generated -- inspect the raw files in $OUT/ instead"
fi

echo ""
echo "Done. Findings written to $OUT/"
echo "Feed the JSON/text files in $OUT/ to the model for triage -- not the source tree."
