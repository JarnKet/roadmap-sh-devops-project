#!/usr/bin/env bash
#
# log-analyzer.sh — summarise an nginx access log.
#
# Usage:
#   ./log-analyzer.sh [path-to-log]   (defaults to ./nginx-access.log)
#
# nginx "combined" log line looks like:
#   IP - - [date] "METHOD /path HTTP/1.1" STATUS SIZE "referrer" "user agent"
#    $1         $4          $6  $7  $8      $9   $10
#
set -euo pipefail

LOG="${1:-nginx-access.log}"
if [[ ! -f "$LOG" ]]; then
  echo "Error: log file '$LOG' not found." >&2
  exit 1
fi

# --- The reusable counting pipeline ------------------------------------------
# This is the heart of the whole project. Given a stream of values (one per
# line), it answers "what are the 5 most common values?":
#
#   sort        group identical lines next to each other
#   uniq -c     collapse runs of identical lines into "  <count> <value>"
#   sort -rn    sort by that count, highest first (-r reverse, -n numeric)
#   head -n 5   keep the top 5
#
# Then we reformat "  <count> <value>" -> "<value> - <count> requests".
# We rebuild the value with awk (not just $2) so values containing spaces,
# like user-agent strings, survive intact.
format_top5() {
  sort | uniq -c | sort -rn | head -n 5 | \
    awk '{ count=$1; $1=""; sub(/^[ \t]+/, ""); printf "%s - %s requests\n", $0, count }'
}

# --- 1. Top 5 IP addresses ---------------------------------------------------
# The IP is the first whitespace-separated field.
echo "Top 5 IP addresses with the most requests:"
awk '{ print $1 }' "$LOG" | format_top5
echo

# --- 2. Top 5 requested paths ------------------------------------------------
# Counting fields by position breaks on malformed probe requests (e.g.
# "\x04\x01...") that contain no spaces and shift the columns. Instead we split
# the line on the quote ("), so the request is ALWAYS field 2, then take the
# path (the 2nd space-separated token of "METHOD PATH PROTOCOL").
echo "Top 5 most requested paths:"
awk -F'"' '{ split($2, a, " "); print (a[2] == "" ? "-" : a[2]) }' "$LOG" | format_top5
echo

# --- 3. Top 5 response status codes ------------------------------------------
# Same idea: with FS='"', field 3 is " STATUS SIZE ", so the status is its
# first token. This stays correct even when the request field is garbage.
echo "Top 5 response status codes:"
awk -F'"' '{ split($3, a, " "); print a[1] }' "$LOG" | format_top5
echo

# --- 4. Top 5 user agents ----------------------------------------------------
# The user agent is the last quoted string. Splitting the line on the double
# quote (") character, it becomes field 6. We strip a trailing \r in case the
# file uses Windows (CRLF) line endings.
echo "Top 5 user agents:"
awk -F'"' '{ ua=$6; sub(/\r$/, "", ua); print ua }' "$LOG" | format_top5
