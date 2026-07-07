#!/usr/bin/env bash
# Acknowledge a task's terminal report so the watcher stops re-escalating its
# deliberately parked window. Records the status log's current last line in
# state/<task-id>.stale-ack; while that line is unchanged, the watcher and the
# away-mode daemon absorb the window's stale-type wakes (no queue entry, no
# wedge escalation - policy: stale_is_acked in bin/fm-classify-lib.sh). A NEW
# status append changes the last line and self-invalidates the ack, returning
# the task to normal triage; signal and check wakes are never suppressed.
# This is an explicit firstmate action for a task that must stay parked
# awaiting an external event (e.g. a PR merge gating teardown) AFTER its report
# was relayed - never ack a report the captain has not seen yet.
# fm-teardown.sh removes the marker with the task's other state files.
# Usage: fm-stale-ack.sh <task-id>          record the ack
#        fm-stale-ack.sh <task-id> --clear  remove the ack (normal triage resumes)
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
"$FM_ROOT/bin/fm-guard.sh" || true
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"

usage() { grep '^# Usage' -A1 "$0" | sed 's/^# //'; }
[ $# -ge 1 ] || { usage >&2; exit 2; }
ID=$1
ACK="$STATE/$ID.stale-ack"

if [ "${2:-}" = "--clear" ]; then
  rm -f "$ACK"
  echo "cleared: $ID stale-ack removed (normal stale triage resumes)"
  exit 0
fi

[ -f "$STATE/$ID.meta" ] || { echo "error: no meta for task $ID at $STATE/$ID.meta" >&2; exit 1; }
LAST=$(last_status_line "$STATE/$ID.status")
[ -n "$LAST" ] || { echo "error: task $ID has no status line to acknowledge" >&2; exit 1; }
status_is_captain_relevant "$LAST" \
  || echo "warning: acked line carries no captain-relevant verb - stale wakes for it will still be suppressed: $LAST" >&2
printf '%s' "$LAST" > "$ACK"
echo "acked: $ID stale wakes suppressed while its status log still ends with: $LAST"
