#!/usr/bin/env bash
# Launch the post-implementation dual reviewers (claude + codex) for a PR.
# This script is the one owner of the pilot-verified reviewer launch commands
# and per-tier prompts; crew/review/review-procedure.md tells the crewmate when
# to run it, and .agents/skills/pr-review-dispatch tells firstmate how to pick
# the tier.
# Usage: fm-review-launch.sh <full|simple> <pr-number> [--print] [--out-dir <dir>]
#   full     skill-based expensive review: claude uses its built-in code-review
#            skill; codex is pointed at crew/review/diff-review.md and its
#            prompt carries the mandatory "Use subagents" wording.
#            The crew procedure owns the at-most-once-per-PR rule for this tier.
#   simple   plain review prompts, no skill, no subagents; also used for every
#            follow-up round after fixes.
#   --print  print the two launch commands (shell-quoted) instead of running.
#   --out-dir <dir>  capture directory for reviewer output (default ./tmp/fm-review).
# Run it from the project worktree root. It launches both reviewers as parallel
# subprocesses, captures each reviewer's stdout VERBATIM to
# <out-dir>/{claude,codex}-review-<n>.md (stderr to a sibling .log, <n> increments
# per round so earlier rounds are never clobbered), waits for both, prints the
# capture paths with per-reviewer exit codes, and exits non-zero if either failed.
#
# config/review.env (LOCAL, gitignored, shell-sourced KEY=VALUE lines) overrides
# the pilot-verified defaults below; see docs/examples/review.env for a template.
# Recognized keys:
#   FM_REVIEW_CLAUDE_MODEL   claude reviewer model (default claude-fable-5)
#   FM_REVIEW_CLAUDE_EFFORT  claude reviewer effort (default high)
#   FM_REVIEW_CODEX_MODEL    codex reviewer model (default gpt-5.5)
#   FM_REVIEW_CODEX_EFFORT   codex model_reasoning_effort (default high)
#   FM_REVIEW_GUIDELINES     per-repo guideline link used in the prompts
#                            (default .review/guidelines.md)
#   FM_REVIEW_FRONTEND_GUIDELINES  frontend guideline link; set EMPTY to drop the
#                            "(and ... if the PR contains frontend changes)"
#                            prompt clause (default .review/frontend.md)
#   FM_REVIEW_CLAUDE_ARGS    replaces the default claude flag set entirely
#                            (word-split; default: --model <model> --effort
#                            <effort> --permission-mode auto)
#   FM_REVIEW_CODEX_ARGS     replaces the default codex flag set entirely
#                            (word-split; default: --yolo --model <model>
#                            -c model_reasoning_effort="<effort>")
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"

usage() {
  echo "usage: fm-review-launch.sh <full|simple> <pr-number> [--print] [--out-dir <dir>]" >&2
  exit 1
}

TIER=
PR=
PRINT=0
OUT_DIR=./tmp/fm-review
while [ $# -gt 0 ]; do
  case "$1" in
    --print) PRINT=1 ;;
    --out-dir)
      [ $# -ge 2 ] || { echo "error: --out-dir requires a value" >&2; exit 1; }
      shift; OUT_DIR=$1 ;;
    --out-dir=*) OUT_DIR=${1#--out-dir=} ;;
    -*) echo "error: unknown flag $1" >&2; usage ;;
    *)
      if [ -z "$TIER" ]; then TIER=$1
      elif [ -z "$PR" ]; then PR=$1
      else echo "error: unexpected argument $1" >&2; usage
      fi ;;
  esac
  shift
done
case "$TIER" in
  full|simple) : ;;
  *) echo "error: tier must be full or simple (got '${TIER:-<none>}')" >&2; usage ;;
esac
case "$PR" in
  ''|*[!0-9]*) echo "error: pr-number must be a plain number (got '${PR:-<none>}')" >&2; usage ;;
esac

if [ -f "$CONFIG/review.env" ]; then
  # shellcheck disable=SC1091  # local operator-provided override file
  . "$CONFIG/review.env"
fi
: "${FM_REVIEW_CLAUDE_MODEL:=claude-fable-5}"
: "${FM_REVIEW_CLAUDE_EFFORT:=high}"
: "${FM_REVIEW_CODEX_MODEL:=gpt-5.5}"
: "${FM_REVIEW_CODEX_EFFORT:=high}"
: "${FM_REVIEW_GUIDELINES:=.review/guidelines.md}"
# ${VAR-default} (not :-) so an explicitly EMPTY value drops the frontend clause.
FM_REVIEW_FRONTEND_GUIDELINES=${FM_REVIEW_FRONTEND_GUIDELINES-.review/frontend.md}

if [ -n "$FM_REVIEW_FRONTEND_GUIDELINES" ]; then
  GUIDELINE_CLAUSE="$FM_REVIEW_GUIDELINES (and $FM_REVIEW_FRONTEND_GUIDELINES if the PR contains frontend changes)"
else
  GUIDELINE_CLAUSE="$FM_REVIEW_GUIDELINES"
fi

# Pilot-verified prompts. The full-tier codex prompt MUST contain the words
# "Use subagents" - codex will not use them on a skill-file mention alone.
if [ "$TIER" = full ]; then
  CLAUDE_PROMPT="Review the PR #$PR using your code-review skill. Also consult advice in $GUIDELINE_CLAUSE."
  CODEX_PROMPT="Review the PR #$PR using the review skill at $FM_ROOT/crew/review/diff-review.md. Use subagents. Also consult the advice in $GUIDELINE_CLAUSE."
else
  CLAUDE_PROMPT="Review the PR #$PR. Consult advice in $GUIDELINE_CLAUSE."
  CODEX_PROMPT=$CLAUDE_PROMPT
fi

CLAUDE_CMD=(claude -p "$CLAUDE_PROMPT")
if [ -n "${FM_REVIEW_CLAUDE_ARGS:-}" ]; then
  # shellcheck disable=SC2206  # deliberate word-splitting of the operator's flag string
  CLAUDE_CMD+=($FM_REVIEW_CLAUDE_ARGS)
else
  CLAUDE_CMD+=(--model "$FM_REVIEW_CLAUDE_MODEL" --effort "$FM_REVIEW_CLAUDE_EFFORT" --permission-mode auto)
fi
CODEX_CMD=(codex exec)
if [ -n "${FM_REVIEW_CODEX_ARGS:-}" ]; then
  # shellcheck disable=SC2206  # deliberate word-splitting of the operator's flag string
  CODEX_CMD+=($FM_REVIEW_CODEX_ARGS)
else
  CODEX_CMD+=(--yolo --model "$FM_REVIEW_CODEX_MODEL" -c "model_reasoning_effort=\"$FM_REVIEW_CODEX_EFFORT\"")
fi
CODEX_CMD+=("$CODEX_PROMPT")

# Print one arg shell-quoted only when it needs quoting, so --print output is
# copy-pasteable and reads like the pilot's hand-written commands.
quote_arg() {
  case "$1" in
    ''|*[!A-Za-z0-9_@%+=:,./-]*)
      printf "'"
      printf '%s' "$1" | sed "s/'/'\\\\''/g"
      printf "'" ;;
    *) printf '%s' "$1" ;;
  esac
}

print_cmd() {
  local first=1 a
  for a in "$@"; do
    [ "$first" = 1 ] || printf ' '
    first=0
    quote_arg "$a"
  done
  printf '\n'
}

if [ "$PRINT" = 1 ]; then
  printf 'claude: '
  print_cmd "${CLAUDE_CMD[@]}"
  printf 'codex: '
  print_cmd "${CODEX_CMD[@]}"
  exit 0
fi

mkdir -p "$OUT_DIR"
n=1
while [ -e "$OUT_DIR/claude-review-$n.md" ] || [ -e "$OUT_DIR/codex-review-$n.md" ]; do
  n=$((n + 1))
done
CLAUDE_OUT="$OUT_DIR/claude-review-$n.md"
CODEX_OUT="$OUT_DIR/codex-review-$n.md"

"${CLAUDE_CMD[@]}" > "$CLAUDE_OUT" 2> "$CLAUDE_OUT.log" &
claude_pid=$!
"${CODEX_CMD[@]}" > "$CODEX_OUT" 2> "$CODEX_OUT.log" &
codex_pid=$!
claude_rc=0
codex_rc=0
wait "$claude_pid" || claude_rc=$?
wait "$codex_pid" || codex_rc=$?
echo "claude: exit $claude_rc, findings at $CLAUDE_OUT"
echo "codex: exit $codex_rc, findings at $CODEX_OUT"
if [ "$claude_rc" -ne 0 ] || [ "$codex_rc" -ne 0 ]; then
  echo "error: a reviewer exited non-zero; check the .log files next to the findings" >&2
  exit 1
fi
