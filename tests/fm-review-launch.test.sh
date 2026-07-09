#!/usr/bin/env bash
# Behavior tests for bin/fm-review-launch.sh.
#
# The script is the one owner of the pilot-verified dual-reviewer launch
# commands and per-tier prompts, so these tests pin that verified surface:
# the exact default models/flags, the per-tier prompt shapes (including the
# mandatory "Use subagents" wording in the full-tier codex prompt and the
# no-GitHub-posting sentence in every prompt), the
# config/review.env override indirection with its absent-file defaults, and
# launch mode's parallel capture and failure propagation.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-review-launch)

# Empty config dir: --print must emit the pilot-verified default commands and
# full-tier prompts verbatim.
test_print_full_defaults() {
  local cfg out
  cfg="$TMP_ROOT/cfg-empty"
  mkdir -p "$cfg"
  out=$(FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" full 123 --print) \
    || fail "print mode with default config should exit 0"
  assert_contains "$out" "claude: claude -p 'Review the PR #123 using your code-review skill. Also consult advice in .review/guidelines.md (and .review/frontend.md if the PR contains frontend changes). Do not post your comments to GitHub; report your findings as reply text only.' --model claude-fable-5 --effort high --permission-mode auto" \
    "full-tier claude command drifted from the pilot-verified default"
  assert_contains "$out" "codex: codex exec --yolo --model gpt-5.5 -c 'model_reasoning_effort=\"high\"'" \
    "full-tier codex command drifted from the pilot-verified default"
  assert_contains "$out" "using the review skill at $ROOT/crew/review/diff-review.md. Use subagents." \
    "full-tier codex prompt lost the diff-review path or the mandatory Use subagents wording"
  assert_contains "$out" "Use subagents. Also consult the advice in .review/guidelines.md (and .review/frontend.md if the PR contains frontend changes). Do not post your comments to GitHub; report your findings as reply text only.'" \
    "full-tier codex prompt lost the no-GitHub-posting sentence"
  pass "fm-review-launch.sh: full tier prints the pilot-verified defaults"
}

# Simple tier: plain review prompts for both reviewers - no skill reference,
# no subagents.
test_print_simple_prompts() {
  local cfg out
  cfg="$TMP_ROOT/cfg-empty2"
  mkdir -p "$cfg"
  out=$(FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" simple 123 --print) \
    || fail "print mode (simple) should exit 0"
  assert_contains "$out" "claude: claude -p 'Review the PR #123. Consult advice in .review/guidelines.md (and .review/frontend.md if the PR contains frontend changes). Do not post your comments to GitHub; report your findings as reply text only.'" \
    "simple-tier claude prompt drifted from the pilot-verified wording"
  assert_contains "$out" "'model_reasoning_effort=\"high\"' 'Review the PR #123. Consult advice in .review/guidelines.md (and .review/frontend.md if the PR contains frontend changes). Do not post your comments to GitHub; report your findings as reply text only.'" \
    "simple-tier codex prompt drifted from the pilot-verified wording"
  assert_not_contains "$out" "code-review skill" "simple tier must not reference the claude skill"
  assert_not_contains "$out" "Use subagents" "simple tier must not request subagents"
  assert_not_contains "$out" "diff-review.md" "simple tier must not point codex at the review skill file"
  pass "fm-review-launch.sh: simple tier prompts carry no skill or subagent references"
}

# config/review.env overrides models, efforts, and guideline links; an EMPTY
# frontend value drops the frontend clause from the prompts entirely.
test_config_overrides() {
  local cfg out
  cfg="$TMP_ROOT/cfg-override"
  mkdir -p "$cfg"
  cat > "$cfg/review.env" <<'EOF'
FM_REVIEW_CLAUDE_MODEL=claude-opus-4-8
FM_REVIEW_CLAUDE_EFFORT=max
FM_REVIEW_CODEX_MODEL=gpt-6
FM_REVIEW_CODEX_EFFORT=xhigh
FM_REVIEW_GUIDELINES=docs/review-rules.md
FM_REVIEW_FRONTEND_GUIDELINES=
EOF
  out=$(FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" full 9 --print) \
    || fail "print mode with override config should exit 0"
  assert_contains "$out" "--model claude-opus-4-8 --effort max" "claude model/effort override was not applied"
  assert_contains "$out" "--model gpt-6 -c 'model_reasoning_effort=\"xhigh\"'" "codex model/effort override was not applied"
  assert_contains "$out" "advice in docs/review-rules.md." "guideline link override was not applied"
  assert_not_contains "$out" "frontend changes" "empty frontend override must drop the frontend clause"
  pass "fm-review-launch.sh: config/review.env overrides models, efforts, and guideline links"
}

# FM_REVIEW_*_ARGS strings are word-split but never glob-expanded: a flag value
# containing * must survive literally even when the cwd holds matching files.
test_args_override_no_glob_expansion() {
  local cfg work out
  cfg="$TMP_ROOT/cfg-glob"
  work="$TMP_ROOT/work-glob"
  mkdir -p "$cfg" "$work"
  touch "$work/a.md" "$work/b.md"
  cat > "$cfg/review.env" <<'EOF'
FM_REVIEW_CLAUDE_ARGS='--allowed-tools *.md'
FM_REVIEW_CODEX_ARGS='-c include="*.md"'
EOF
  out=$(cd "$work" && FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" simple 5 --print) \
    || fail "print mode with glob-bearing ARGS overrides should exit 0"
  assert_contains "$out" "--allowed-tools '*.md'" "claude ARGS glob was expanded against cwd files"
  assert_contains "$out" "-c 'include=\"*.md\"'" "codex ARGS glob was expanded against cwd files"
  assert_not_contains "$out" "a.md" "glob expansion leaked cwd filenames into the reviewer command"
  pass "fm-review-launch.sh: ARGS overrides word-split without glob expansion"
}

# Launch mode: both reviewers run in parallel, stdout is captured verbatim to
# round-numbered files that never clobber an earlier round.
test_launch_captures_and_increments() {
  local cfg fakebin work out
  cfg="$TMP_ROOT/cfg-launch"
  work="$TMP_ROOT/work"
  mkdir -p "$cfg" "$work"
  fakebin=$(fm_fakebin "$TMP_ROOT")
  cat > "$fakebin/claude" <<'SH'
#!/usr/bin/env bash
echo "claude findings for: $2"
SH
  cat > "$fakebin/codex" <<'SH'
#!/usr/bin/env bash
echo "codex findings"
SH
  chmod +x "$fakebin/claude" "$fakebin/codex"
  out=$(cd "$work" && PATH="$fakebin:$PATH" FM_CONFIG_OVERRIDE="$cfg" \
    "$ROOT/bin/fm-review-launch.sh" simple 7) \
    || fail "launch mode with healthy reviewers should exit 0"
  assert_contains "$out" "claude-review-1.md" "launch output does not name the claude capture file"
  assert_grep "Review the PR #7." "$work/tmp/fm-review/claude-review-1.md" \
    "claude stdout was not captured verbatim"
  assert_grep "codex findings" "$work/tmp/fm-review/codex-review-1.md" \
    "codex stdout was not captured"
  (cd "$work" && PATH="$fakebin:$PATH" FM_CONFIG_OVERRIDE="$cfg" \
    "$ROOT/bin/fm-review-launch.sh" simple 7 >/dev/null) \
    || fail "second launch round should exit 0"
  assert_present "$work/tmp/fm-review/claude-review-2.md" "second round should get its own capture files"
  assert_grep "Review the PR #7." "$work/tmp/fm-review/claude-review-1.md" \
    "second round clobbered the first round's findings"
  pass "fm-review-launch.sh: launch mode captures both reviewers and increments rounds"
}

# A reviewer that exits non-zero must fail the launch as a whole.
test_launch_failure_propagates() {
  local cfg fakebin work status
  cfg="$TMP_ROOT/cfg-fail"
  work="$TMP_ROOT/work-fail"
  mkdir -p "$cfg" "$work"
  fakebin=$(fm_fakebin "$TMP_ROOT/fail")
  fm_fake_exit0 "$fakebin" claude
  cat > "$fakebin/codex" <<'SH'
#!/usr/bin/env bash
echo boom >&2
exit 3
SH
  chmod +x "$fakebin/codex"
  (cd "$work" && PATH="$fakebin:$PATH" FM_CONFIG_OVERRIDE="$cfg" \
    "$ROOT/bin/fm-review-launch.sh" simple 7 >/dev/null 2>&1); status=$?
  expect_code 1 "$status" "a failing reviewer should fail the launch"
  pass "fm-review-launch.sh: a non-zero reviewer exit fails the launch"
}

# Bad arguments are refused before anything launches.
test_argument_validation() {
  local cfg status
  cfg="$TMP_ROOT/cfg-args"
  mkdir -p "$cfg"
  FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" mega 7 --print >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "an unknown tier should be refused"
  FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" full abc --print >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "a non-numeric PR number should be refused"
  FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-review-launch.sh" full 7 --bogus >/dev/null 2>&1; status=$?
  expect_code 1 "$status" "an unknown flag should be refused"
  pass "fm-review-launch.sh: invalid tier, PR number, and flags are refused"
}

test_print_full_defaults
test_print_simple_prompts
test_config_overrides
test_args_override_no_glob_expansion
test_launch_captures_and_increments
test_launch_failure_propagates
test_argument_validation
