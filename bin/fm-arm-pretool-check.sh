#!/usr/bin/env bash
# PreToolUse seatbelt against the firstmate watcher-arm anti-pattern.
#
# A firstmate PRIMARY must arm the watcher (bin/fm-watch-arm.sh) or run a
# Codex checkpoint (bin/fm-watch-checkpoint.sh) as a STANDALONE, VERIFIED
# harness call. On 2026-07-09 a Grok primary instead armed with shapes like
# `bin/fm-watch-arm.sh &`, `bin/fm-watch-arm.sh 2>&1 | head -2 &`, and the arm
# glued after another command with `&`. Each of those backgrounds the arm with
# a plain shell `&` (or pipes/bundles it) instead of using the harness's own
# tracked background mechanism, so the forked child is reaped the instant the
# tool call ends - leaving NO watcher running and supervision blind. See
# bin/fm-watch-arm.sh's own header for the incident this already guards
# against structurally; this script adds a pre-execution seatbelt so a
# harness that supports PreToolUse-style hooks can refuse the command before
# it ever runs.
#
# THIS IS A SEATBELT FOR KNOWN-BAD COMMAND SHAPES, NOT A POST-ARM LIVENESS
# GUARANTEE. It only inspects the text of a shell command about to run and
# denies a handful of specific anti-patterns (background operator, truncating
# pipe, stdio redirection, command substitution, bundling with other work,
# broad pkill). It cannot prove the watcher actually started and stayed
# healthy afterward - that is bin/fm-guard.sh and bin/fm-turnend-guard.sh's
# job, which run after the fact from the beacon and lock. A command this script
# allows can still fail to arm the watcher for unrelated reasons. See
# docs/arm-pretool-check.md for the full contract and the per-harness wiring
# audit.
#
# SCOPE: denies fire only from firstmate's PRIMARY checkout. The tracked hook
# files ship in every worktree of this repo (crewmate/scout task worktrees,
# secondmate homes), but the seatbelt protects the primary's supervision loop,
# not workers. Outside the primary - linked worktree, secondmate-home marker,
# non-repo root, or git unavailable - every command is a silent allow, using
# the same primary predicate as bin/fm-turnend-guard.sh (keyed off this
# script's own location, honoring FM_ROOT_OVERRIDE; tests use the override).
# The check runs lazily, only when a deny is about to fire, so the common
# allow path never pays the git calls.
#
# RELEVANCE is positional. A watcher-script name (or pkill) only makes a
# command relevant when it appears in COMMAND POSITION: at the start of the
# text or right after a statement separator (;, &, |, a subshell/brace open,
# a backtick), optionally preceded by env assignments and run-prefix words
# (exec, nohup, timeout, ...) with their flag/numeric arguments. Position is
# judged on the quote-stripped command text, on a separator-neutralized
# projection that keeps quoted content so a quoted command word like
# `"bin/fm-watch-arm.sh" &` cannot dodge the check, and - for nested shell
# evaluators (bash -c, eval, themselves required in command position) -
# inside each quoted payload, so `bash -lc 'bin/fm-watch-arm.sh &'` stays
# denied. Quoted string content and plain arguments never trigger relevance:
# on 2026-07-10 the previous anywhere-in-text match false-denied read-only
# grep/git commands whose search patterns named fm-watch*, and a
# `no-mistakes axi respond --instructions "..."` whose prose named the
# scripts. A raw-substring pre-filter (fm-watch or pkill anywhere in the
# quote-delimiter-free text) short-circuits every other command before any
# projection work, so the per-character walkers never run on the ordinary
# large commands this hook sees on every shell call.
#
# Usage:
#   <PreToolUse JSON on stdin> | bin/fm-arm-pretool-check.sh
#   bin/fm-arm-pretool-check.sh --command '<cmd>' [--background true|false]
#
# Stdin mode reads a harness PreToolUse-style payload and extracts the shell
# command from, in order: .toolInput.command (Grok), .tool_input.command
# (Claude, Codex). .toolInput.background / .tool_input.background is read for
# context only - it names the harness's OWN tracked background mechanism
# (e.g. Grok's run_terminal_command background:true tool parameter), which is
# the CORRECT way to background the arm, and is never itself a deny signal.
# The only backgrounding this script objects to is a shell-level operator
# inside the command text (&, nohup, disown), because that bypasses the
# harness's tracking entirely.
#
# CLI mode (--command) is for adapters that already extracted the command
# themselves (OpenCode/Pi plugin JSON differs in shape) and for tests; it
# never touches jq.
#
# Exit/output contract:
#   ALLOW - exit 0. No stdout for an irrelevant command (fast pass-through).
#   DENY  - exit 2, plus BOTH of:
#             stdout: {"decision":"deny","reason":"..."} (Grok's PreToolUse
#               contract; verified 2026-07-09 against grok 0.2.93 - exit 2
#               alone is not honored without this).
#             stderr: {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#               "permissionDecision":"deny"},"systemMessage":"..."} (Claude
#               Code's PreToolUse contract; verified 2026-07-09 - plain-text
#               stderr + exit 2, which is sufficient for Claude's Stop hook,
#               is NOT sufficient here and silently lets the tool run).
#           Codex reads plain exit 2 and shows stderr verbatim (verified
#           2026-07-09 against codex-cli 0.143.0), so the JSON on stderr is
#           merely displayed as text there - still a clean deny.
#   Fail-open - unparseable/empty JSON in stdin mode, or missing jq in stdin
#   mode, always exits 0. A hook must never crash-deny everything.
#
# --claude: Claude Code only honors a PreToolUse deny when stdout is EMPTY
# and the hookSpecificOutput JSON is on stderr alone (verified 2026-07-09
# against Claude Code 2.1.204: ANY content on stdout - even Grok's own
# {"decision":...} JSON, even a combined object carrying both schemas -
# makes Claude silently allow the tool instead of falling back to stderr).
# Pass --claude from the Claude adapter to suppress the stdout deny JSON;
# every other caller (Grok, Codex, tests, CLI use) keeps the default dual
# output.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

CMD=""
CMD_SET=0
BACKGROUND=""
CLAUDE_MODE=0

usage() {
  cat <<'EOF'
Usage: fm-arm-pretool-check.sh [--command <cmd>] [--background true|false] [--claude]

With no --command, reads a PreToolUse-style JSON payload on stdin (Grok
toolInput.command, or Claude/Codex tool_input.command).
Exits 0 to allow, 2 to deny (deny reason on stderr, deny decision JSON on
stdout unless --claude). Fails open (exit 0) on unparseable/empty input or
missing jq.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --command)
      [ "$#" -gt 1 ] || { echo "error: --command requires a value" >&2; exit 2; }
      CMD=$2
      CMD_SET=1
      shift 2
      ;;
    --command=*)
      CMD=${1#--command=}
      CMD_SET=1
      shift
      ;;
    --background)
      [ "$#" -gt 1 ] || { echo "error: --background requires a value" >&2; exit 2; }
      BACKGROUND=$2
      shift 2
      ;;
    --background=*)
      BACKGROUND=${1#--background=}
      shift
      ;;
    --claude)
      CLAUDE_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# --- input acquisition -------------------------------------------------------

if [ "$CMD_SET" -eq 0 ]; then
  PAYLOAD=$(cat 2>/dev/null || true)
  [ -n "$PAYLOAD" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  CMD=$(printf '%s' "$PAYLOAD" | jq -r '(.toolInput.command // .tool_input.command // empty)' 2>/dev/null) || exit 0
  [ -n "$CMD" ] || exit 0
  # Read for context/logging parity with --background only; never a gating
  # signal (see the usage header: harness-native background:true is correct
  # usage, only a shell-level '&' is the anti-pattern).
  # shellcheck disable=SC2034
  BACKGROUND=$(printf '%s' "$PAYLOAD" | jq -r '(.toolInput.background // .tool_input.background // false)' 2>/dev/null) || BACKGROUND=false
fi

[ -n "$CMD" ] || exit 0

# --- primary scoping ----------------------------------------------------------

# Same predicate as bin/fm-turnend-guard.sh: only the main, non-worktree
# checkout that looks firstmate-shaped is the primary. A linked worktree's
# git-dir lives under the main repo's .git/worktrees/<name> and differs from
# the common git-dir; a git-cloned secondmate home carries the
# .fm-secondmate-home marker instead. Anything unprovable fails open to
# non-primary (allow) - a seatbelt must never crash-deny.
is_primary_checkout() {
  [ -f "$FM_ROOT/.fm-secondmate-home" ] && return 1
  local git_dir git_common_dir
  git_dir=$(git -C "$FM_ROOT" rev-parse --git-dir 2>/dev/null) || return 1
  git_common_dir=$(git -C "$FM_ROOT" rev-parse --git-common-dir 2>/dev/null) || return 1
  [ "$git_dir" = "$git_common_dir" ] || return 1
  [ -f "$FM_ROOT/AGENTS.md" ] || return 1
  [ -d "$FM_ROOT/bin" ] || return 1
  return 0
}

# --- pattern detection --------------------------------------------------------

# Command position: start of the text or right after a statement separator or
# subshell/brace/backtick open, optionally preceded by env assignments and
# run-prefix words that still execute the next word. Flag and numeric tokens
# are accepted as wrapper arguments (timeout 60, nice -n 5, stdbuf -oL) - the
# chain must still START at an allowlisted word, so an argument to grep or
# echo can never open a prefix chain.
CMD_POS_PREFIX='(^|[;&|({`])[[:space:]]*((exec|eval|command|builtin|nohup|setsid|time|env|sudo|timeout|flock|stdbuf|nice|ionice|-[^[:space:]]+|[0-9][^[:space:]]*|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+)*'
WATCH_SCRIPT_WORD='[^[:space:];|&]*(fm-watch-arm(\.sh)?\b|fm-watch-checkpoint\.sh\b|fm-watch\.sh\b)'
PKILL_WORD='[^[:space:];|&]*pkill\b'

# One quote/escape walker for every quoted-text projection, parameterized on
# emit mode so the escape and quote rules cannot drift between projections:
#   strip    - remove quoted content (and the quote delimiters) so grep
#              patterns, commit messages, and --instructions prose never look
#              like commands; each opening quote leaves one space so word
#              boundaries survive.
#   segments - emit each quoted segment's content on its own line. A quoted
#              argument to a nested shell evaluator (bash -c, eval) is itself
#              a command string, so command position is re-judged inside it.
#   neutral  - remove only the quote delimiters, keeping quoted content, with
#              statement separators inside quotes neutralized to a space. A
#              quoted command word ("bin/fm-watch-arm.sh" &) stays visible in
#              command position, while quoted prose containing ';' or a
#              newline cannot fabricate a command-position anchor.
quote_walk() {
  local mode=$1 cmd=$2
  local LC_ALL=C
  local i len ch out="" seg="" in_single=0 in_double=0 escaped=0
  len=${#cmd}
  for ((i = 0; i < len; i++)); do
    ch=${cmd:i:1}
    if [ "$escaped" -eq 1 ]; then
      escaped=0
      quote_walk_emit
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = "\\" ]; then
      escaped=1
      continue
    fi
    if [ "$in_double" -eq 0 ] && [ "$ch" = "'" ]; then
      if [ "$in_single" -eq 0 ]; then
        in_single=1
        [ "$mode" = "strip" ] && out+=" "
      else
        in_single=0
        [ "$mode" = "segments" ] && { printf '%s\n' "$seg"; seg=""; }
      fi
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = '"' ]; then
      if [ "$in_double" -eq 0 ]; then
        in_double=1
        [ "$mode" = "strip" ] && out+=" "
      else
        in_double=0
        [ "$mode" = "segments" ] && { printf '%s\n' "$seg"; seg=""; }
      fi
      continue
    fi
    quote_walk_emit
  done
  if [ "$mode" = "segments" ]; then
    [ -n "$seg" ] && printf '%s\n' "$seg"
  else
    printf '%s' "$out"
  fi
  return 0
}

# Dynamic-scope helper for quote_walk only: appends the current character to
# the active projection according to mode and quote state.
quote_walk_emit() {
  local quoted=0
  { [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; } && quoted=1
  case "$mode" in
    strip)
      [ "$quoted" -eq 0 ] && out+=$ch
      ;;
    segments)
      [ "$quoted" -eq 1 ] && seg+=$ch
      ;;
    neutral)
      if [ "$quoted" -eq 1 ]; then
        case "$ch" in ';'|'&'|'|'|'('|'{'|'`'|$'\n') ch=' ' ;; esac
      fi
      out+=$ch
      ;;
  esac
  return 0
}

watch_script_in_command_position() {
  printf '%s' "$1" | grep -Eq "${CMD_POS_PREFIX}${WATCH_SCRIPT_WORD}"
}

is_relevant() {
  local cmd=$1
  printf '%s' "$cmd" | tr -d "'\"\\\\" | grep -q 'fm-watch' || return 1
  watch_script_in_command_position "$(quote_walk strip "$cmd")" && return 0
  watch_script_in_command_position "$(quote_walk neutral "$cmd")" && return 0
  if has_nested_shell_evaluator "$cmd"; then
    watch_script_in_command_position "$(quote_walk segments "$cmd")" && return 0
  fi
  return 1
}

# pkill must itself sit in command position (judged on the quote-stripped
# text), while the fm-watch target may come from a quoted argument - so
# `pkill -f 'fm-watch'` still denies but a grep whose pattern quotes the same
# words does not.
is_pkill_watch() {
  local cmd=$1 segs
  printf '%s' "$cmd" | tr -d "'\"\\\\" | grep -q 'pkill' || return 1
  if printf '%s' "$(quote_walk strip "$cmd")" | grep -Eq "${CMD_POS_PREFIX}${PKILL_WORD}"; then
    printf '%s' "$cmd" | grep -Eq '\bpkill\b[^|;&]*fm-watch' && return 0
  fi
  if has_nested_shell_evaluator "$cmd"; then
    segs=$(quote_walk segments "$cmd")
    if printf '%s' "$segs" | grep -Eq "${CMD_POS_PREFIX}${PKILL_WORD}"; then
      printf '%s' "$segs" | grep -Eq '\bpkill\b[^|;&]*fm-watch' && return 0
    fi
  fi
  return 1
}

# Bare shell `&` (not `&&` or redirection), or nohup/disown anywhere in an
# already-relevant command.
has_bare_background_operator() {
  local cmd=$1
  local LC_ALL=C
  local i len ch prev next in_single=0 in_double=0 escaped=0
  len=${#cmd}
  for ((i = 0; i < len; i++)); do
    ch=${cmd:i:1}
    if [ "$escaped" -eq 1 ]; then
      escaped=0
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = "\\" ]; then
      escaped=1
      continue
    fi
    if [ "$in_double" -eq 0 ] && [ "$ch" = "'" ]; then
      if [ "$in_single" -eq 0 ]; then in_single=1; else in_single=0; fi
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = '"' ]; then
      if [ "$in_double" -eq 0 ]; then in_double=1; else in_double=0; fi
      continue
    fi
    if [ "$in_single" -ne 0 ] || [ "$in_double" -ne 0 ]; then
      continue
    fi
    [ "$ch" = "&" ] || continue

    prev=""
    next=""
    [ "$i" -gt 0 ] && prev=${cmd:i-1:1}
    [ "$((i + 1))" -lt "$len" ] && next=${cmd:i+1:1}
    [ "$next" = "&" ] && { i=$((i + 1)); continue; }
    [ "$prev" = ">" ] && continue
    [ "$next" = ">" ] && continue
    return 0
  done
  return 1
}

# The evaluator itself must sit in command position on the quote-stripped
# text - a bare 'eval' or 'bash -c' appearing as an argument word (a grep
# pattern, a git pathspec) must not turn every quoted segment into a command
# payload.
has_nested_shell_evaluator() {
  local stripped
  stripped=$(quote_walk strip "$1")
  printf '%s' "$stripped" | grep -Eq \
    -e "${CMD_POS_PREFIX}([^[:space:];|&]*/)?(bash|sh|zsh)([[:space:]][^;|&]*)?[[:space:]]-[^[:space:]]*c([[:space:]]|\$)" \
    -e "${CMD_POS_PREFIX}eval([[:space:]]|\$)"
}

nested_shell_projection() {
  printf '%s' "$1" | tr -d "'\""
}

has_nested_shell_background_operator() {
  local cmd=$1 projected
  has_nested_shell_evaluator "$cmd" || return 1
  projected=$(nested_shell_projection "$cmd")
  has_bare_background_operator "$projected"
}

has_shell_list_operator() {
  local cmd=$1
  printf '%s' "$cmd" | grep -Eq '&&|\|\|' && return 0
  has_bare_background_operator "$cmd" && return 0
  return 1
}

has_command_or_process_substitution() {
  local cmd=$1
  local LC_ALL=C
  local i len ch next in_single=0 in_double=0 escaped=0
  len=${#cmd}
  for ((i = 0; i < len; i++)); do
    ch=${cmd:i:1}
    if [ "$escaped" -eq 1 ]; then
      escaped=0
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = "\\" ]; then
      escaped=1
      continue
    fi
    if [ "$in_double" -eq 0 ] && [ "$ch" = "'" ]; then
      if [ "$in_single" -eq 0 ]; then in_single=1; else in_single=0; fi
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = '"' ]; then
      if [ "$in_double" -eq 0 ]; then in_double=1; else in_double=0; fi
      continue
    fi
    [ "$in_single" -eq 0 ] || continue

    next=""
    [ "$((i + 1))" -lt "$len" ] && next=${cmd:i+1:1}
    [ "$ch" = "$" ] && [ "$next" = "(" ] && return 0
    [ "$ch" = '`' ] && return 0
    { [ "$ch" = "<" ] || [ "$ch" = ">" ]; } && [ "$next" = "(" ] && return 0
  done
  return 1
}

has_shell_redirection() {
  local cmd=$1
  local LC_ALL=C
  local i len ch in_single=0 in_double=0 escaped=0
  len=${#cmd}
  for ((i = 0; i < len; i++)); do
    ch=${cmd:i:1}
    if [ "$escaped" -eq 1 ]; then
      escaped=0
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = "\\" ]; then
      escaped=1
      continue
    fi
    if [ "$in_double" -eq 0 ] && [ "$ch" = "'" ]; then
      if [ "$in_single" -eq 0 ]; then in_single=1; else in_single=0; fi
      continue
    fi
    if [ "$in_single" -eq 0 ] && [ "$ch" = '"' ]; then
      if [ "$in_double" -eq 0 ]; then in_double=1; else in_double=0; fi
      continue
    fi
    if [ "$in_single" -ne 0 ] || [ "$in_double" -ne 0 ]; then
      continue
    fi
    { [ "$ch" = "<" ] || [ "$ch" = ">" ]; } && return 0
  done
  return 1
}

is_backgrounded() {
  local cmd=$1
  has_bare_background_operator "$cmd" && return 0
  has_nested_shell_background_operator "$cmd" && return 0
  printf '%s' "$cmd" | grep -Eq '\b(nohup|disown)\b' && return 0
  return 1
}

has_nested_shell_redirection() {
  local cmd=$1 projected
  has_nested_shell_evaluator "$cmd" || return 1
  projected=$(nested_shell_projection "$cmd")
  has_shell_redirection "$projected"
}

has_nested_command_or_process_substitution() {
  local cmd=$1 projected
  has_nested_shell_evaluator "$cmd" || return 1
  projected=$(nested_shell_projection "$cmd")
  has_command_or_process_substitution "$projected"
}

# Piped into a tool that can tear down attach-and-wait early.
is_piped_truncated() {
  printf '%s' "$1" | grep -Eq '\|[[:space:]]*(head|tail|timeout)\b|\|[[:space:]]*sed[[:space:]]+-n\b'
}

# Count top-level statements, treating ';', '&&', '||', and newlines as
# separators. Only used as a fallback signal once the blessed-shape check
# below has already ruled the command out, so it never needs to special-case
# the guarded x-mode source clause.
statement_count() {
  local cmd=$1 normalized
  normalized=$(printf '%s' "$cmd" | sed -E 's/&&/\n/g; s/\|\|/\n/g; s/;/\n/g')
  printf '%s\n' "$normalized" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -c '[^[:space:]]'
}

# The blessed shape: optional cd/export/guarded-x-mode-source leading
# statements, then a sole final exec of fm-watch-arm.sh (optional --restart)
# or a sole fm-watch-checkpoint.sh invocation. No pipes, background operator,
# redirection, or command/process substitution anywhere. Both the relative
# (bin/, ./bin/) and absolute (/.../bin/) invocations are blessed, and the
# x-mode source clause accepts the repo-relative path or the rendered
# absolute path (optionally single-quoted, as bin/fm-supervision-instructions.sh
# emits it).
BLESSED_PATH_PREFIX='((\./)?|/[^[:space:]]*/)'
X_MODE_ENV_RE="(config/x-mode\\.env|/[^[:space:]']*/config/x-mode\\.env|'/[^']*/config/x-mode\\.env')"

is_blessed_shape() {
  local cmd=$1
  printf '%s' "$cmd" | grep -Eq '\|' && return 1
  is_backgrounded "$cmd" && return 1
  has_shell_redirection "$cmd" && return 1
  has_command_or_process_substitution "$cmd" && return 1

  local normalized line trimmed
  normalized=$(printf '%s' "$cmd" | tr ';' '\n')
  local -a stmts=()
  while IFS= read -r line; do
    trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -n "$trimmed" ] && stmts+=("$trimmed")
  done <<EOF
$normalized
EOF

  local n=${#stmts[@]}
  [ "$n" -ge 1 ] || return 1

  local last=${stmts[$((n - 1))]}
  has_shell_list_operator "$last" && return 1
  local last_ok=1
  printf '%s' "$last" | grep -Eq "^(exec[[:space:]]+)?${BLESSED_PATH_PREFIX}bin/fm-watch-arm\\.sh([[:space:]]+--restart)?[[:space:]]*\$" && last_ok=0
  if [ "$last_ok" -ne 0 ]; then
    printf '%s' "$last" | grep -Eq "^${BLESSED_PATH_PREFIX}bin/fm-watch-checkpoint\\.sh([[:space:]]+[^[:space:]]+)*[[:space:]]*\$" && last_ok=0
  fi
  [ "$last_ok" -eq 0 ] || return 1

  local i stmt
  for ((i = 0; i < n - 1; i++)); do
    stmt=${stmts[$i]}
    printf '%s' "$stmt" | grep -Eq "^\\[[[:space:]]+-f[[:space:]]+${X_MODE_ENV_RE}[[:space:]]+\\][[:space:]]+&&[[:space:]]+(\\.|source)[[:space:]]+${X_MODE_ENV_RE}\$" && continue
    has_shell_list_operator "$stmt" && return 1
    printf '%s' "$stmt" | grep -Eq '^cd[[:space:]]+[^[:space:]]+$' && continue
    printf '%s' "$stmt" | grep -Eq '^export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=.*$' && continue
    printf '%s' "$stmt" | grep -Eq "^(\\.|source)[[:space:]]+${X_MODE_ENV_RE}\$" && continue
    return 1
  done
  return 0
}

json_escape() {
  # Minimal JSON string escaper, dependency-free so CLI mode never needs jq.
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '
}

# --- decision -----------------------------------------------------------------

# Raw-substring pre-filter: every deny needs an fm-watch token in some
# projection (pkill denies also require an fm-watch target), and the
# projections only drop quote delimiters, backslashes, and quoted content -
# so no deny can fire unless 'fm-watch' or 'pkill' appears in the
# delimiter-free raw text. This hook runs on every shell call; the filter
# keeps the per-character projection walkers off that hot path. Any new deny
# token must extend this anchor set.
printf '%s' "$CMD" | tr -d "'\"\\\\" | grep -Eq 'fm-watch|pkill' || exit 0

DENY=0
REASON=""

if is_pkill_watch "$CMD"; then
  DENY=1
  REASON="broad pkill against the firstmate watcher is forbidden: it matches every firstmate home's watcher (secondmate homes run the same script) and can kill a sibling's supervision. Use bin/fm-watch-arm.sh --restart for a home-scoped restart, never pkill -f fm-watch."
elif is_relevant "$CMD"; then
  if is_blessed_shape "$CMD"; then
    DENY=0
  elif is_backgrounded "$CMD"; then
    DENY=1
    REASON="backgrounds the watcher arm/checkpoint with a shell '&' (or nohup/disown). That child is reaped the instant this tool call ends, leaving no watcher running - run bin/fm-watch-arm.sh as the harness's own standalone background tool call instead, never fired with a trailing '&'."
  elif is_piped_truncated "$CMD"; then
    DENY=1
    REASON="pipes the watcher arm/checkpoint through head/tail/timeout/sed -n, which can tear down attach-and-wait before the watcher confirms it started."
  elif has_shell_redirection "$CMD"; then
    DENY=1
    REASON="redirects the watcher arm/checkpoint stdio with shell redirection, which can hide the status and wake lines the primary relies on."
  elif has_nested_shell_redirection "$CMD"; then
    DENY=1
    REASON="redirects the watcher arm/checkpoint stdio inside a nested shell payload, which can hide the status and wake lines the primary relies on."
  elif has_command_or_process_substitution "$CMD"; then
    DENY=1
    REASON="runs command or process substitution inside a watcher arm/checkpoint command. Run the watcher arm/checkpoint as its own literal standalone command."
  elif has_nested_command_or_process_substitution "$CMD"; then
    DENY=1
    REASON="runs command or process substitution inside a nested shell watcher arm/checkpoint payload. Run the watcher arm/checkpoint as its own literal standalone command."
  elif [ "$(statement_count "$CMD")" -gt 1 ]; then
    DENY=1
    REASON="bundles the watcher arm/checkpoint with other work in a multi-statement command. Run it as its own standalone command, optionally preceded only by cd/export/source config/x-mode.env."
  fi
fi

if [ "$DENY" -eq 1 ]; then
  # Lazy scope gate: only a would-be deny pays the git calls, and only the
  # primary checkout actually denies - crewmate/scout worktrees and secondmate
  # homes inherit the tracked hook files but are not the supervision loop this
  # seatbelt protects.
  is_primary_checkout || exit 0
  ESCAPED=$(json_escape "$REASON")
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"%s"}\n' "$ESCAPED" >&2
  # Claude Code only honors the stderr deny when stdout is empty; see the
  # --claude usage note above. Every other consumer needs the Grok-shaped
  # decision JSON on stdout.
  [ "$CLAUDE_MODE" -eq 1 ] || printf '{"decision":"deny","reason":"%s"}\n' "$ESCAPED"
  exit 2
fi

exit 0
