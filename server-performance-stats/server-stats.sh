#!/usr/bin/env bash
#
# server-stats.sh — analyse basic server performance stats on any Linux host.
#
# Usage:
#   ./server-stats.sh
#
set -euo pipefail

# A small helper to print section titles consistently.
section() {
  echo
  echo "=============================================="
  echo " $1"
  echo "=============================================="
}

# ---- CPU USAGE --------------------------------------------------------------
# We read /proc/stat twice, 1 second apart, and look at how the counters moved.
# /proc/stat's "cpu" line counts time spent in each state since boot (in "jiffies").
# CPU usage = (work done) / (total time) over that 1-second window.

read_cpu_times() {
  # Fields: cpu user nice system idle iowait irq softirq steal ...
  local cpu user nice system idle iowait irq softirq steal
  read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
  local idle_all=$((idle + iowait))
  local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  echo "$total $idle_all"
}

read -r total1 idle1 < <(read_cpu_times)
sleep 1
read -r total2 idle2 < <(read_cpu_times)

# Delta over the 1s window. We use awk for clean decimal math.
cpu_usage=$(awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2" \
  'BEGIN {
     total_diff = t2 - t1
     idle_diff  = i2 - i1
     printf "%.1f", (total_diff - idle_diff) / total_diff * 100
   }')

section "CPU USAGE"
printf "  Total CPU usage: %s%%\n" "$cpu_usage"

# ---- MEMORY USAGE -----------------------------------------------------------
# `free -m` reports memory in MB. We parse the "Mem:" row and compute percentages.

section "MEMORY USAGE"
free -m | awk '/^Mem:/ {
  total = $2; used = $3; free = $4
  printf "  Total: %d MB\n", total
  printf "  Used:  %d MB (%.1f%%)\n", used, used/total*100
  printf "  Free:  %d MB (%.1f%%)\n", free, free/total*100
}'

# ---- DISK USAGE -------------------------------------------------------------
# `df` shows filesystem usage. --total adds a summary row. We exclude pseudo
# filesystems (tmpfs, devtmpfs, overlay) so we only count real disks.

section "DISK USAGE"
df -h --total -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk '
  /^total/ {
    printf "  Total: %s\n", $2
    printf "  Used:  %s (%s)\n", $3, $5
    printf "  Free:  %s\n", $4
  }'

# ---- TOP 5 PROCESSES BY CPU -------------------------------------------------
# ps lists processes; --sort=-%cpu orders by CPU descending; we take the top 5.

section "TOP 5 PROCESSES BY CPU"
printf "  %-8s %-25s %s\n" "PID" "COMMAND" "%CPU"
ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | head -n 5 | \
  awk '{ printf "  %-8s %-25s %s\n", $1, $2, $3 }'

# ---- TOP 5 PROCESSES BY MEMORY ----------------------------------------------

section "TOP 5 PROCESSES BY MEMORY"
printf "  %-8s %-25s %s\n" "PID" "COMMAND" "%MEM"
ps -eo pid,comm,%mem --sort=-%mem --no-headers | head -n 5 | \
  awk '{ printf "  %-8s %-25s %s\n", $1, $2, $3 }'

# ---- STRETCH GOALS ----------------------------------------------------------

section "SYSTEM INFO (extra)"

# OS version (from the standard /etc/os-release file)
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf "  OS:            %s\n" "${PRETTY_NAME:-unknown}"
fi

# Uptime in human-readable form
printf "  Uptime:        %s\n" "$(uptime -p 2>/dev/null || echo unknown)"

# Load average (1, 5, 15 minutes) — read straight from /proc/loadavg
read -r l1 l5 l15 _ < /proc/loadavg
printf "  Load average:  %s (1m)  %s (5m)  %s (15m)\n" "$l1" "$l5" "$l15"

# Logged-in users
printf "  Logged-in users: %s\n" "$(who | wc -l)"

# Failed login attempts (best-effort; needs read access to auth logs).
# Note: `grep -c` ALWAYS prints a count to stdout, but EXITS 1 when the count
# is 0. So `grep -c ... || echo X` would print BOTH the "0" and the fallback.
# We use `|| true` to swallow only the exit code, then default empty to 0.
fails="n/a"
if [[ -r /var/log/auth.log ]]; then
  fails=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || true)
elif command -v journalctl >/dev/null 2>&1; then
  fails=$(journalctl _COMM=sshd 2>/dev/null | grep -c "Failed password" || true)
fi
[[ -z "$fails" ]] && fails=0
printf "  Failed logins: %s\n" "$fails"

echo
