# shellcheck shell=bash

# Sourced by the resolver and both consumers; every path is sandbox-local.
repo_fixture() {
  local dir="$1" primary="$1/primary repo" linked="$1/linked" other="$1/other" unusual
  unusual="$dir/odd"$'\t\n'"name"$'\n'
  mkdir -p "$dir/plain"
  git init -q "$primary"
  git -C "$primary" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm initial --allow-empty
  git -C "$primary" worktree add -q --detach "$linked"
  git init -q "$other"
  git init -q "$unusual"
  git init -q --bare "$dir/bare"
  git clone -q --bare --no-hardlinks "$primary" "$dir/container/.bare"
  printf 'gitdir: .bare\n' >"$dir/container/.git"
  git -C "$dir/container/.bare" worktree add -q --detach "$dir/container/main"
  git clone -q --bare --no-hardlinks "$primary" "$dir/standalone/.bare"
  git -C "$dir/standalone/.bare" worktree add -q --detach "$dir/standalone/main"
  git init -q --separate-git-dir "$dir/storage" "$dir/checkout"
  jq -n --arg primary "$primary" --arg linked "$linked" --arg other "$other" --arg dir "$dir" --arg unusual "$unusual" '
    def ws($id): {workspace_id:$id, label:$id, worktree:null};
    def tab($id; $n): {workspace_id:$id, tab_id:($id + ":t" + ($n|tostring)), number:$n};
    def pane($id; $n; $cwd): {workspace_id:$id, tab_id:($id + ":t" + ($n|tostring)), pane_id:($id + ":p" + ($n|tostring)), cwd:$cwd};
    {result:{snapshot:{
      workspaces: [
        (ws("primary") | .worktree={repo_key:($primary+"/.git"),repo_name:"primary repo",repo_root:$primary,checkout_path:$primary}),
        ws("plain"), ws("linked"), ws("duplicate"), ws("mixed"), ws("missing"), ws("bare"), ws("unusual"), ws("empty"), ws("no-layout")],
      tabs: [tab("mixed"; 2), tab("mixed"; 1)] + ["primary","plain","linked","duplicate","missing","bare","unusual","no-layout" | tab(.; 1)],
      panes: [pane("mixed"; 2; $other), pane("mixed"; 1; $linked),
        (pane("mixed"; 1; $other) | .pane_id="later-split"),
        pane("primary"; 1; $other), pane("plain"; 1; ($dir+"/plain")), pane("linked"; 1; $linked),
        pane("duplicate"; 1; $primary), pane("missing"; 1; ($dir+"/missing")), pane("bare"; 1; ($dir+"/bare")),
        pane("unusual"; 1; $unusual), pane("no-layout"; 1; $primary)],
      layouts: (["primary","plain","linked","duplicate","missing","bare","unusual" | {tab_id:(.+":t1"),panes:[{pane_id:(.+":p1")}]}]
        + [{tab_id:"mixed:t2",panes:[{pane_id:"mixed:p2"}]},
           {tab_id:"mixed:t1",panes:[{pane_id:"mixed:p1"},{pane_id:"later-split"}]}]),
      agents: []
    }}}
  ' >"$dir/repos.json"
}
