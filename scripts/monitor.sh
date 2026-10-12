#!/usr/bin/env bash
#
# monitor.sh - service health check + syslog error counter.
#
# Usage:   monitor.sh <service>
# Exit:    0 service active
#          1 service not active
#          2 usage error
#          3 service not found
#          4 systemd not available
#
set -uo pipefail

SYSLOG="${SYSLOG_FILE:-/var/log/syslog}"
WINDOW_MIN=60

usage() {
  echo "Usage: $0 <service>" >&2
  echo "Example: $0 docker" >&2
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
[[ $# -eq 1 ]] || { usage; exit 2; }

svc="${1%.service}"
if [[ ! "$svc" =~ ^[A-Za-z0-9@._:-]+$ ]]; then
  echo "ERROR: invalid service name: '$1'" >&2
  exit 2
fi

command -v systemctl >/dev/null 2>&1 || { echo "ERROR: systemctl not found (no systemd?)" >&2; exit 4; }

# 1. Does the unit exist?
load_state="$(systemctl show -p LoadState --value "${svc}.service" 2>/dev/null)"
if [[ -z "$load_state" || "$load_state" == "not-found" ]]; then
  echo "ERROR: service '${svc}' not found" >&2
  exit 3
fi

# 2. Is it running?
rc=0
state="$(systemctl is-active "$svc" 2>/dev/null)"
if [[ "$state" == "active" ]]; then
  echo "[OK]   ${svc}: active"
else
  echo "[FAIL] ${svc}: ${state:-unknown}"
  echo "--- last 10 journal lines for ${svc} ---"
  logs="$(journalctl -u "$svc" -n 10 --no-pager 2>&1)"
  if [[ -z "$logs" || "$logs" == *"-- No entries --"* ]]; then
    echo "(no journal entries for ${svc})"
  else
    echo "$logs"
  fi
  rc=1
fi

# 3. Errors in syslog during the last hour
if [[ ! -e "$SYSLOG" ]]; then
  echo "WARN: ${SYSLOG} does not exist (install rsyslog?); error count skipped" >&2
elif [[ ! -r "$SYSLOG" ]]; then
  echo "WARN: ${SYSLOG} is not readable (add user to 'adm' group or use sudo); error count skipped" >&2
elif [[ ! -s "$SYSLOG" ]]; then
  echo "syslog errors in last ${WINDOW_MIN} min: 0 (log is empty)"
elif ! grep -aqE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$SYSLOG"; then
  echo "WARN: unsupported syslog timestamp format; error count skipped" >&2
else
  cutoff="$(date -d "-${WINDOW_MIN} minutes" '+%Y-%m-%dT%H:%M:%S')"
  count="$(tr -d '\000' < "$SYSLOG" | grep -ai 'error' | awk -v c="$cutoff" '$1 >= c { n++ } END { print n+0 }')"
  echo "syslog errors in last ${WINDOW_MIN} min: ${count}"
fi

exit "$rc"
