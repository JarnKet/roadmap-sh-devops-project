#!/usr/bin/env bash
#
# log-archive — compress a log directory into a timestamped tar.gz archive.
#
# Usage:
#   log-archive <log-directory> [output-directory]
#
# Examples:
#   log-archive /var/log
#   log-archive /var/log /backups/logs
#

# Fail fast and loud:
#   -e  exit immediately if any command fails
#   -u  treat unset variables as an error
#   -o pipefail  a pipeline fails if ANY command in it fails (not just the last)
set -euo pipefail

# ---- Helpers ----------------------------------------------------------------

usage() {
  cat <<EOF
Usage: log-archive <log-directory> [output-directory]

Compresses the contents of <log-directory> into a timestamped .tar.gz file
and records each run in an archive history log.

Arguments:
  log-directory     Directory whose logs to archive (e.g. /var/log)
  output-directory  Where to store the archive (default: ./log-archives)

Examples:
  log-archive /var/log
  log-archive /var/log /backups/logs
EOF
}

# ---- Argument validation ----------------------------------------------------

# $# is the number of arguments passed to the script.
if [[ $# -lt 1 ]]; then
  echo "Error: missing log directory argument." >&2   # >&2 writes to stderr
  echo >&2
  usage >&2
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

LOG_DIR="$1"
# Parameter expansion: use $2 if given, otherwise default to ./log-archives
OUTPUT_DIR="${2:-./log-archives}"

if [[ ! -d "$LOG_DIR" ]]; then
  echo "Error: '$LOG_DIR' is not a directory or does not exist." >&2
  exit 1
fi

# ---- Build paths ------------------------------------------------------------

# Timestamp like 20240816_100648
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="logs_archive_${TIMESTAMP}.tar.gz"

# -p creates parent dirs as needed AND doesn't error if the dir already exists.
mkdir -p "$OUTPUT_DIR"

ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"
ARCHIVE_LOG="${OUTPUT_DIR}/archive_history.log"

# ---- Create the archive -----------------------------------------------------

# tar flags:
#   -c  create a new archive
#   -z  compress it with gzip
#   -f  the next argument is the output filename
#   -C  cd into LOG_DIR *before* archiving, then archive "."
#       This keeps paths inside the tarball relative (./syslog) instead of
#       absolute (/var/log/syslog), and avoids tar's "removing leading /" warning.
tar -czf "$ARCHIVE_PATH" -C "$LOG_DIR" .

# ---- Record the run ---------------------------------------------------------

echo "$(date '+%Y-%m-%d %H:%M:%S')  archived '${LOG_DIR}' -> '${ARCHIVE_PATH}'" \
  >> "$ARCHIVE_LOG"

echo "✓ Archived '${LOG_DIR}'"
echo "  Archive: ${ARCHIVE_PATH}"
echo "  History: ${ARCHIVE_LOG}"
