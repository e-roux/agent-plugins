#!/usr/bin/env bats

PLUGIN_DIR="$BATS_TEST_DIRNAME/.."

@test "plugin.json exists with required fields" {
  [ -f "$PLUGIN_DIR/plugin.json" ]
  jq -e '.name'                     "$PLUGIN_DIR/plugin.json" >/dev/null
  jq -e '.version'                  "$PLUGIN_DIR/plugin.json" >/dev/null
  jq -e '._meta.copilotCliVersion'  "$PLUGIN_DIR/plugin.json" >/dev/null
}

@test "marketplace.json version matches plugin.json" {
  local plugin_ver mkt_ver
  plugin_ver=$(jq -r .version "$PLUGIN_DIR/plugin.json")
  mkt_ver=$(jq -r ".plugins[] | select(.source == \"./plugins/billing\") | .version" "$PLUGIN_DIR/../../.claude-plugin/marketplace.json")
  [ "$plugin_ver" = "$mkt_ver" ]
}

@test "skills directories contain SKILL.md" {
  local skills_dir="$PLUGIN_DIR/skills"
  [ -d "$skills_dir" ] || skip "no skills dir"
  for dir in "$skills_dir"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || { echo "missing SKILL.md in $dir"; false; }
  done
}

@test "hooks file is valid JSON with version field" {
  local hooks_key
  hooks_key=$(jq -r '.hooks // empty' "$PLUGIN_DIR/plugin.json")
  [ -n "$hooks_key" ] || skip "no hooks declared"
  [ -f "$PLUGIN_DIR/$hooks_key" ] || { echo "missing hooks file: $PLUGIN_DIR/$hooks_key"; false; }
  jq -e '.version' "$PLUGIN_DIR/$hooks_key" >/dev/null
}

@test "session-start hook script exists and is executable" {
  [ -f "$PLUGIN_DIR/hooks/scripts/session-start.sh" ]
  [ -x "$PLUGIN_DIR/hooks/scripts/session-start.sh" ]
}

@test "session-end hook script exists and is executable" {
  [ -f "$PLUGIN_DIR/hooks/scripts/session-end.sh" ]
  [ -x "$PLUGIN_DIR/hooks/scripts/session-end.sh" ]
}

@test "report script exists and is executable" {
  [ -f "$PLUGIN_DIR/scripts/report.sh" ]
  [ -x "$PLUGIN_DIR/scripts/report.sh" ]
}

@test "CHANGELOG.md has Unreleased section" {
  [ -f "$PLUGIN_DIR/CHANGELOG.md" ]
  grep -q '^\#\# \[Unreleased\]' "$PLUGIN_DIR/CHANGELOG.md"
}

@test "report script --help exits 0" {
  run bash "$PLUGIN_DIR/scripts/report.sh" --help
  [ "$status" -eq 0 ]
}

@test "session-start hook outputs valid JSON with additionalContext" {
  run bash -c 'echo "{}" | bash "$0"' "$PLUGIN_DIR/hooks/scripts/session-start.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.additionalContext' >/dev/null
}

@test "rates config is valid JSON with multipliers" {
  [ -f "$PLUGIN_DIR/config/rates.json" ]
  jq -e '.multipliers' "$PLUGIN_DIR/config/rates.json" >/dev/null
  jq -e '.effective_date' "$PLUGIN_DIR/config/rates.json" >/dev/null
}

@test "cost-optimization skill exists" {
  [ -f "$PLUGIN_DIR/skills/cost-optimization/SKILL.md" ]
}
