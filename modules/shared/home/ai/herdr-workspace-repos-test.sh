#!/usr/bin/env bash

set -euo pipefail
resolver="$1"
# shellcheck source=herdr-workspace-repos-fixture.sh
source "$2"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
repo_fixture "$test_dir"
"$resolver" <"$test_dir/repos.json" >"$test_dir/map.json"
jq -e --arg primary "$test_dir/primary repo" --arg unusual "$test_dir/odd"$'\t\n'"name"$'\n' '
  .primary == {repo_key:($primary+"/.git"),repo_name:"primary repo"}
  and .linked == .primary and .duplicate == .primary
  and .mixed == {repo_key:($primary|sub("primary repo$";"other/.git")),repo_name:"other"}
  and .unusual == {repo_key:($unusual+"/.git"),repo_name:($unusual|split("/")|last)}
  and .plain == null and .missing == null and .bare == null
  and .empty == null and ."no-layout" == null
' "$test_dir/map.json"

# Common-dir naming also covers embedded bare repositories and separate storage.
jq --arg dir "$test_dir" '
  .result.snapshot = {
    workspaces: [{workspace_id:"embedded"},{workspace_id:"standalone"},{workspace_id:"separate"}],
    tabs: ["embedded","standalone","separate" | {workspace_id:.,tab_id:.}],
    layouts: ["embedded","standalone","separate" | {tab_id:.,panes:[{pane_id:.}]}],
    panes: [{pane_id:"embedded",cwd:($dir+"/container/main")},
      {pane_id:"standalone",cwd:($dir+"/standalone/main")},
      {pane_id:"separate",cwd:($dir+"/checkout")}]
  }
' "$test_dir/repos.json" | "$resolver" >"$test_dir/names.json"
jq -e --arg dir "$test_dir" '
  .embedded == {repo_key:($dir+"/container/.bare"),repo_name:"container"}
  and .standalone == {repo_key:($dir+"/standalone/.bare"),repo_name:".bare"}
  and .separate == {repo_key:($dir+"/storage"),repo_name:"storage"}
' "$test_dir/names.json"

# A container pointing at a linked Git dir is not Herdr's embedded-bare layout.
cp "$test_dir/container/main/.git" "$test_dir/container/.git"
jq -n --arg cwd "$test_dir/container/main" '{result:{snapshot:{
  workspaces:[{workspace_id:"linked-container"}],
  tabs:[{workspace_id:"linked-container",tab_id:"t"}],
  layouts:[{tab_id:"t",panes:[{pane_id:"p"}]}],
  panes:[{pane_id:"p",cwd:$cwd}]
}}}' | "$resolver" | jq -e '.["linked-container"].repo_name == ".bare"'

for snapshot in '{}' '{"result":{"snapshot":{}}}' '{"result":{"snapshot":{"workspaces":[]}}}'; do
  [ "$("$resolver" <<<"$snapshot")" = '{}' ]
done
for field in tabs layouts panes; do
  jq --arg field "$field" 'del(.result.snapshot[$field])' "$test_dir/repos.json" |
    "$resolver" >"$test_dir/missing.json"
  jq -e 'all(to_entries[]; .key == "primary" or .value == null)' "$test_dir/missing.json" >/dev/null
done

printf 'Workspace repository resolver fixtures passed.\n'
