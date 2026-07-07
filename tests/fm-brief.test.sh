#!/usr/bin/env bash
# Behavior tests for bin/fm-brief.sh.
#
# Regression coverage for the heredoc-in-command-substitution parse bug (issue
# #166): each ship-mode branch builds its Definition-of-done text with
# `VAR=$(cat <<EOF ... EOF)`. Bash's lexer tracks quote state through the
# heredoc body while it scans for the matching `)` of the command
# substitution, so a single unescaped apostrophe anywhere in that body breaks
# parsing of the *entire rest of the script* - `bash -n` fails, not just the
# generated brief. A plain `cat > file <<EOF ... EOF` (not wrapped in `$(...)`)
# is unaffected, so the secondmate charter block does not need this guard.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-brief)

# The script itself must always parse. This is the direct regression test for
# issue #166: a stray apostrophe in any of the three DOD heredoc bodies
# (no-mistakes/direct-PR/local-only) breaks `bash -n` on the whole file.
test_script_parses() {
  bash -n "$ROOT/bin/fm-brief.sh" 2>&1 || fail "bin/fm-brief.sh fails bash -n (heredoc/quote regression)"
  pass "fm-brief.sh: bash -n succeeds"
}

# Registry with one project per delivery mode, so each ship-mode DOD branch is
# exercised. A project absent from the registry defaults to no-mistakes.
write_registry() {
  local home=$1
  mkdir -p "$home/data"
  cat > "$home/data/projects.md" <<'EOF'
- direct-proj [direct-PR] - fixture for direct-PR mode (added 2026-07-01)
- local-proj [local-only] - fixture for local-only mode (added 2026-07-01)
EOF
}

# fm-brief.sh must exit 0 and produce a brief with no unreplaced shell
# metacharacter corruption for every ship delivery mode. This also guards
# against any *new* unescaped apostrophe or unbalanced quote later added to
# one of these DOD blocks, since a broken heredoc corrupts or empties the
# generated brief content, not just the script's own syntax.
test_ship_modes_generate_clean_briefs() {
  local home id brief status
  home="$TMP_ROOT/ship-home"
  write_registry "$home"

  for id_proj in "brief-nomistakes-a1:no-registry-proj" "brief-directpr-a2:direct-proj" "brief-localonly-a3:local-proj"; do
    id=${id_proj%%:*}
    proj=${id_proj##*:}
    FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" "$proj" >/dev/null 2>&1; status=$?
    expect_code 0 "$status" "fm-brief.sh $id $proj should exit 0"
    brief="$home/data/$id/brief.md"
    assert_present "$brief" "$id: brief was not scaffolded"
    assert_grep "# Definition of done" "$brief" "$id: brief missing Definition of done section"
    assert_grep "{TASK}" "$brief" "$id: brief missing the {TASK} placeholder"
    assert_no_grep "EOF" "$brief" "$id: brief leaked a heredoc EOF marker (unterminated heredoc)"
  done
  pass "fm-brief.sh: no-mistakes/direct-PR/local-only briefs generate cleanly"
}

# Pin the specific line the bug lived on: the no-mistakes DOD's no-mistakes
# reference must render as plain prose with no dangling apostrophe artifact.
test_no_mistakes_dod_wording() {
  local home id brief
  home="$TMP_ROOT/wording-home"
  mkdir -p "$home/data"
  id="brief-wording-b1"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" some-proj >/dev/null 2>&1
  brief="$home/data/$id/brief.md"
  assert_present "$brief" "brief was not scaffolded"
  assert_grep "no-mistakes itself provides for the mechanics" "$brief" \
    "no-mistakes DOD lost its guidance-reference sentence"
  assert_no_grep "no-mistakes' own guidance" "$brief" \
    "no-mistakes DOD regressed to the apostrophe form that breaks bash -n"
  pass "fm-brief.sh: no-mistakes DOD wording avoids the apostrophe regression"
}

# --review=<tier> must put the post-implementation review contract into a
# direct-PR ship brief: the pinned tier, the absolute path to the tracked crew
# procedure, and the review-shaped done line, all resolvable without any
# firstmate-private data/ file.
test_review_flag_direct_pr() {
  local home id brief
  home="$TMP_ROOT/review-home"
  write_registry "$home"
  id="brief-review-c1"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" direct-proj --review=full >/dev/null 2>&1 \
    || fail "fm-brief.sh --review=full on a direct-PR project should succeed"
  brief="$home/data/$id/brief.md"
  assert_present "$brief" "review brief was not scaffolded"
  assert_grep "# Post-implementation review" "$brief" "review brief missing the review section"
  assert_grep "TIER=\`full\`" "$brief" "review brief does not pin the chosen tier"
  assert_grep "$ROOT/crew/review/review-procedure.md" "$brief" \
    "review brief does not point at the tracked crew procedure by absolute path"
  assert_grep "FM=\`$ROOT\`" "$brief" "review brief does not state the FM root for the procedure"
  assert_grep "one-line note of any rejected findings" "$brief" \
    "review brief lost the review-shaped done report"
  assert_no_grep "EOF" "$brief" "review brief leaked a heredoc EOF marker"

  id="brief-review-c2"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" direct-proj --review=simple >/dev/null 2>&1 \
    || fail "fm-brief.sh --review=simple on a direct-PR project should succeed"
  assert_grep "TIER=\`simple\`" "$home/data/$id/brief.md" "simple-tier brief does not pin its tier"
  pass "fm-brief.sh: --review briefs carry tier, procedure path, and done contract"
}

# --review must refuse everything outside its verified surface: a missing or
# invalid tier, non-ship briefs, and ship modes the flow was not piloted on -
# and a refusal must not leave a half-made data/<id>/ dir behind.
test_review_flag_refusals() {
  local home status
  home="$TMP_ROOT/review-refuse-home"
  write_registry "$home"

  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-review-d1 direct-proj --review >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "bare --review (no tier) should be refused"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-review-d5 direct-proj --review= >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "--review= with an empty tier should be refused, not silently ignored"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-review-d2 direct-proj --review=fancy >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "an unknown review tier should be refused"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-review-d3 direct-proj --scout --review=simple >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "--review on a scout brief should be refused"
  FM_HOME="$home" "$ROOT/bin/fm-brief.sh" brief-review-d4 nomistakes-proj --review=simple >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "--review on a non-direct-PR project should be refused"
  assert_absent "$home/data/brief-review-d4" "mode refusal left a stray data/<id>/ dir behind"
  pass "fm-brief.sh: --review refusals cover tier, kind, and delivery mode"
}

test_script_parses
test_ship_modes_generate_clean_briefs
test_no_mistakes_dod_wording
test_review_flag_direct_pr
test_review_flag_refusals
