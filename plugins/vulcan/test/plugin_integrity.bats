#!/usr/bin/env bats

PLUGIN_DIR="$BATS_TEST_DIRNAME/.."

@test "plugin.json exists with required fields" {
  [ -f "$PLUGIN_DIR/plugin.json" ]
  jq -e '.name' "$PLUGIN_DIR/plugin.json" >/dev/null
  jq -e '.version' "$PLUGIN_DIR/plugin.json" >/dev/null
}

@test "skills directories contain SKILL.md" {
  local skills_dir="$PLUGIN_DIR/skills"
  [ -d "$skills_dir" ] || skip "no skills dir"
  for dir in "$skills_dir"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || { echo "missing SKILL.md in $dir"; false; }
  done
}

@test "agent files have required frontmatter" {
  local agents_dir="$PLUGIN_DIR/agents"
  [ -d "$agents_dir" ] || skip "no agents dir"
  for f in "$agents_dir"/*.agent.md; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -q '^---' || { echo "missing frontmatter in $f"; false; }
    grep -q '^name:' "$f" || { echo "missing name: in $f"; false; }
  done
}

@test "hooks file is valid JSON" {
  local hooks_key
  hooks_key=$(jq -r '.hooks // empty' "$PLUGIN_DIR/plugin.json")
  [ -n "$hooks_key" ] || skip "no hooks declared"
  [ -f "$PLUGIN_DIR/$hooks_key" ] || { echo "missing hooks file: $hooks_key"; false; }
  jq -e '.version' "$PLUGIN_DIR/$hooks_key" >/dev/null
}

@test "all hook scripts referenced in hooks file exist" {
  local hooks_key
  hooks_key=$(jq -r '.hooks // empty' "$PLUGIN_DIR/plugin.json")
  [ -n "$hooks_key" ] || skip "no hooks declared"
  local hooks_file="$PLUGIN_DIR/$hooks_key"
  while IFS= read -r cmd; do
    local script
    script=$(echo "$cmd" | grep -oE '[^ ]+\.sh' | head -1)
    [ -n "$script" ] || continue
    # scripts are resolved relative to PLUGIN_DIR (default hook cwd)
    local full_path="$PLUGIN_DIR/$script"
    [ -f "$full_path" ] || { echo "missing hook script: $full_path"; false; }
  done < <(jq -r '.. | .bash? // empty | select(type=="string")' "$hooks_file" 2>/dev/null)
}
