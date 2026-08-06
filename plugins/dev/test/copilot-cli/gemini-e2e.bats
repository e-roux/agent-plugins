#!/usr/bin/env bats

setup() {
  export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../../hooks"
  export NODE_FLAGS="--experimental-strip-types"
  
  # Ensure we have git identity set up for temporary repositories
  export GIT_AUTHOR_NAME="Test Bot"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test Bot"
  export GIT_COMMITTER_EMAIL="test@example.com"
}

_make_main_repo() {
  local dir; dir=$(mktemp -d)
  git -C "$dir" init -b main -q
  git -C "$dir" config user.name "Test Bot"
  git -C "$dir" config user.email "test@example.com"
  echo "dummy" > "$dir/dummy.txt"
  git -C "$dir" add dummy.txt
  git -C "$dir" commit -m "initial commit" -q --no-verify
  echo "$dir"
}

@test "gemini-e2e: branch-first guard blocks write_file on main" {
  local repo; repo=$(_make_main_repo)
  
  # Run gemini headless on that repository, prompting it to create a file.
  # We use "--include-directories" so the session works inside the temporary repository,
  # but specify the local "dev" extension to execute our local hooks.
  run gemini -e dev --approval-mode yolo --skip-trust --include-directories "$repo" -p "Create a file named hello.py with print('hello') in $repo"
  
  # Verify that gemini executed successfully and the hook printed the blocked tool call
  [ "$status" -eq 0 ]
  
  # Assert that the hook blocked the toolcall on main and printed the denial reason
  echo "$output" | grep -q "Branch-first guard: you are on 'main'"
  
  rm -rf "$repo"
}

@test "gemini-e2e: no-comments guard blocks comment lines on feature branch" {
  local repo; repo=$(_make_main_repo)
  
  # Switch to a feature branch in our test repository so branch protection is satisfied
  git -C "$repo" checkout -b feat/my-feature -q
  
  # Run gemini headless on that repository, prompting it to create a file containing comments
  run gemini -e dev --approval-mode yolo --skip-trust --include-directories "$repo" -p "Create a python file named app.py with a comment line # Hello in $repo"
  
  # Verify that gemini executed successfully and our pre-tool hook successfully blocked the comment line
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No-comments guard: code must be self-documenting"
  
  rm -rf "$repo"
}
