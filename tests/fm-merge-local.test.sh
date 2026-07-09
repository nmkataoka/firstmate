#!/usr/bin/env bash
# Behavior tests for bin/fm-merge-local.sh's task-branch resolution.
#
# The script always merged the fm/<id> branch guess; config/branch-prefix
# (bin/fm-brief.sh) means a crewmate's branch can carry any prefix, so the
# script falls back to the task worktree's checked-out branch (meta worktree=)
# when fm/<id> does not exist. These tests pin the default path, the
# custom-prefix fallback, and the no-branch error.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-merge-local)
fm_git_identity

# make_local_task <dir> <id> <branch>: project repo on its default branch, a
# task worktree one commit ahead on <branch>, and a local-only meta in a state
# dir. Sets PROJ, WT, STATE for the caller.
make_local_task() {
  local dir=$1 id=$2 branch=$3
  PROJ="$dir/proj"
  WT="$dir/wt"
  STATE="$dir/state"
  fm_git_worktree "$PROJ" "$WT" "$branch"
  printf 'change\n' > "$WT/change.txt"
  git -C "$WT" add change.txt
  git -C "$WT" commit -qm "task change"
  mkdir -p "$STATE"
  fm_write_meta "$STATE/$id.meta" "project=$PROJ" "mode=local-only" "worktree=$WT"
}

# 1. backward-compat: the default fm/<id> branch merges as before.
test_default_branch_merges() {
  local id out status
  id="task-a1"
  make_local_task "$TMP_ROOT/default" "$id" "fm/$id"
  out=$(FM_STATE_OVERRIDE="$STATE" "$ROOT/bin/fm-merge-local.sh" "$id" 2>/dev/null); status=$?
  expect_code 0 "$status" "default fm/<id> merge should succeed"
  assert_contains "$out" "merged fm/$id" "merge output does not name the fm/<id> branch"
  [ "$(git -C "$PROJ" rev-parse HEAD)" = "$(git -C "$WT" rev-parse HEAD)" ] \
    || fail "default merge did not fast-forward the project to the task branch tip"
  pass "fm-merge-local.sh: default fm/<id> branch fast-forwards"
}

# 2. a custom-prefix branch is found via the task worktree's checked-out branch.
test_custom_prefix_branch_merges() {
  local id out status
  id="task-b2"
  make_local_task "$TMP_ROOT/prefixed" "$id" "nolan/$id"
  out=$(FM_STATE_OVERRIDE="$STATE" "$ROOT/bin/fm-merge-local.sh" "$id" 2>/dev/null); status=$?
  expect_code 0 "$status" "custom-prefix merge should succeed via the worktree fallback"
  assert_contains "$out" "merged nolan/$id" "merge output does not name the prefixed branch"
  [ "$(git -C "$PROJ" rev-parse HEAD)" = "$(git -C "$WT" rev-parse HEAD)" ] \
    || fail "prefixed merge did not fast-forward the project to the task branch tip"
  pass "fm-merge-local.sh: custom-prefix branch resolves through the task worktree"
}

# 3. no fm/<id> branch and no usable worktree branch is a hard error.
test_missing_branch_errors() {
  local id err status
  id="task-c3"
  PROJ="$TMP_ROOT/missing/proj"
  STATE="$TMP_ROOT/missing/state"
  fm_git_init_commit "$PROJ"
  mkdir -p "$STATE"
  fm_write_meta "$STATE/$id.meta" "project=$PROJ" "mode=local-only" "worktree=$TMP_ROOT/missing/gone"
  err="$TMP_ROOT/missing/err"
  FM_STATE_OVERRIDE="$STATE" "$ROOT/bin/fm-merge-local.sh" "$id" >/dev/null 2>"$err"; status=$?
  expect_code 1 "$status" "a task with no resolvable branch should be refused"
  assert_grep "no task-worktree branch" "$err" "missing-branch refusal lost its diagnostic"
  pass "fm-merge-local.sh: missing branch refuses with a diagnostic"
}

test_default_branch_merges
test_custom_prefix_branch_merges
test_missing_branch_errors
