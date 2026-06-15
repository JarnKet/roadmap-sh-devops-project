# Explanation of `log-archive.sh`

This document explains how `log-archive.sh` works for someone who is new to Bash or shell scripting.

The script is a command-line tool that takes a directory of log files, compresses that directory into a `.tar.gz` archive, saves the archive in an output folder, and records the archive operation in a history log file.

## What the Script Does

In simple terms, this script:

1. Checks that the user provided a log directory.
2. Allows the user to ask for help with `-h` or `--help`.
3. Verifies that the provided log directory exists.
4. Creates a timestamp such as `20240816_100648`.
5. Builds an archive filename such as `logs_archive_20240816_100648.tar.gz`.
6. Creates the output directory if it does not already exist.
7. Compresses the log directory into a `.tar.gz` file.
8. Writes a record of the archive operation to `archive_history.log`.
9. Prints the archive location and history log location to the terminal.

## What Is a Bash Script?

A Bash script is a text file containing commands that are executed by the Bash shell.

Instead of typing commands one by one in the terminal, you can put them in a file and run the file.

For example, this script can be run like this:

```bash
./log-archive.sh /var/log
```

Or with a custom output directory:

```bash
./log-archive.sh /var/log /backups/logs
```

The first argument is the directory to archive.

The second argument is optional and tells the script where to save the archive.

## Full Script Flow

If you run:

```bash
./log-archive.sh /var/log /backups/logs
```

Then the script understands:

```text
$1 = /var/log
$2 = /backups/logs
```

It then creates something like:

```text
/backups/logs/logs_archive_20240816_100648.tar.gz
```

And it appends a history entry to:

```text
/backups/logs/archive_history.log
```

## Line-by-Line Explanation

### Line 1

```bash
#!/usr/bin/env bash
```

This is called a shebang.

It tells the operating system to run this script using Bash.

`/usr/bin/env bash` searches for the `bash` program in the user's environment. This is more portable than hardcoding something like `/bin/bash`, because Bash may be installed in different locations on different systems.

### Lines 2-11

```bash
#
# log-archive - compress a log directory into a timestamped tar.gz archive.
#
# Usage:
#   log-archive <log-directory> [output-directory]
#
# Examples:
#   log-archive /var/log
#   log-archive /var/log /backups/logs
#
```

These are comments.

In Bash, anything after `#` is ignored by the shell, except for the shebang on the first line.

These comments explain:

- What the script does.
- How to use it.
- Example commands.

The syntax:

```text
log-archive <log-directory> [output-directory]
```

Means:

- `<log-directory>` is required.
- `[output-directory]` is optional.

### Lines 13-17

```bash
# Fail fast and loud:
#   -e  exit immediately if any command fails
#   -u  treat unset variables as an error
#   -o pipefail  a pipeline fails if ANY command in it fails (not just the last)
set -euo pipefail
```

This makes the script safer.

`set` changes shell behavior.

The options are:

- `-e`: Stop the script immediately if a command fails.
- `-u`: Treat missing or unset variables as errors.
- `-o pipefail`: If commands are connected with pipes, the whole pipeline fails if any command in the pipeline fails.

Without this line, some errors might be ignored and the script could continue running with bad data.

### Line 19

```bash
# ---- Helpers ----------------------------------------------------------------
```

This is just a comment used as a section header.

It helps humans read the script.

### Lines 21-36

```bash
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
```

This defines a function named `usage`.

A function is a reusable block of code. The code inside this function only runs when the script calls:

```bash
usage
```

The function prints help text explaining how to use the script.

#### `cat <<EOF`

This part:

```bash
cat <<EOF
...
EOF
```

is called a heredoc.

It sends multiple lines of text into the `cat` command.

`cat` then prints that text to the terminal.

The first `EOF` marks the start of the text, and the second `EOF` marks the end.

`EOF` means "end of file", but here it is just a marker name. You could technically use another marker name, but `EOF` is common.

### Line 38

```bash
# ---- Argument validation ----------------------------------------------------
```

This is another section comment.

The next part of the script checks whether the user passed correct input.

### Lines 40-46

```bash
# $# is the number of arguments passed to the script.
if [[ $# -lt 1 ]]; then
  echo "Error: missing log directory argument." >&2   # >&2 writes to stderr
  echo >&2
  usage >&2
  exit 1
fi
```

This block checks whether the user forgot to provide the required log directory.

#### `$#`

`$#` means the number of command-line arguments passed to the script.

For example:

```bash
./log-archive.sh
```

Here:

```text
$# = 0
```

Because no arguments were provided.

But with:

```bash
./log-archive.sh /var/log
```

Here:

```text
$# = 1
```

Because one argument was provided.

#### `if [[ $# -lt 1 ]]; then`

This means:

```text
If the number of arguments is less than 1, then run the commands below.
```

`-lt` means "less than".

The `[[ ... ]]` syntax is Bash's conditional test syntax.

#### `echo "Error: missing log directory argument." >&2`

`echo` prints text.

`>&2` sends that text to standard error instead of standard output.

There are two common output streams:

- `stdout`: normal output.
- `stderr`: error output.

Using `stderr` is good practice for error messages.

#### `echo >&2`

This prints a blank line to `stderr`.

It is only used to make the error output easier to read.

#### `usage >&2`

This calls the `usage` function and sends its output to `stderr`.

Because this is an error case, the help text is shown as error output.

#### `exit 1`

This stops the script.

Exit codes tell the operating system whether a command succeeded or failed.

- `exit 0` means success.
- `exit 1` usually means failure.

#### `fi`

`fi` ends an `if` block in Bash.

It is `if` spelled backward.

### Lines 48-51

```bash
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi
```

This checks whether the first argument is `-h` or `--help`.

`$1` means the first command-line argument.

For example:

```bash
./log-archive.sh --help
```

Here:

```text
$1 = --help
```

The condition:

```bash
[[ "$1" == "-h" || "$1" == "--help" ]]
```

Means:

```text
If the first argument is "-h" OR the first argument is "--help"
```

`||` means OR.

If the condition is true, the script:

1. Prints the usage help.
2. Exits successfully with `exit 0`.

### Line 53

```bash
LOG_DIR="$1"
```

This creates a variable named `LOG_DIR`.

It stores the first command-line argument.

For example, if the user runs:

```bash
./log-archive.sh /var/log
```

Then:

```text
LOG_DIR=/var/log
```

The double quotes around `$1` are important.

They protect paths that contain spaces.

For example:

```bash
./log-archive.sh "/home/user/my logs"
```

Without quotes, Bash might split that path into multiple pieces.

### Lines 54-55

```bash
# Parameter expansion: use $2 if given, otherwise default to ./log-archives
OUTPUT_DIR="${2:-./log-archives}"
```

This creates a variable named `OUTPUT_DIR`.

It uses the second command-line argument if the user provided one.

If the user did not provide a second argument, it uses:

```text
./log-archives
```

#### `${2:-./log-archives}`

This is Bash parameter expansion.

It means:

```text
Use $2 if it exists and is not empty.
Otherwise, use ./log-archives.
```

Example 1:

```bash
./log-archive.sh /var/log /backups/logs
```

Result:

```text
OUTPUT_DIR=/backups/logs
```

Example 2:

```bash
./log-archive.sh /var/log
```

Result:

```text
OUTPUT_DIR=./log-archives
```

### Lines 57-60

```bash
if [[ ! -d "$LOG_DIR" ]]; then
  echo "Error: '$LOG_DIR' is not a directory or does not exist." >&2
  exit 1
fi
```

This checks whether `LOG_DIR` is a real directory.

#### `-d`

`-d` tests whether a path is a directory.

#### `!`

`!` means NOT.

So this condition:

```bash
[[ ! -d "$LOG_DIR" ]]
```

Means:

```text
If LOG_DIR is not a directory
```

If the directory does not exist, the script prints an error and stops.

This prevents the script from trying to archive something invalid.

### Line 62

```bash
# ---- Build paths ------------------------------------------------------------
```

This section builds names and paths used for the archive file.

### Lines 64-65

```bash
# Timestamp like 20240816_100648
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
```

This creates a timestamp.

The `date` command prints the current date and time.

The format:

```bash
+%Y%m%d_%H%M%S
```

Means:

- `%Y`: four-digit year, such as `2024`.
- `%m`: two-digit month, such as `08`.
- `%d`: two-digit day, such as `16`.
- `%H`: two-digit hour in 24-hour time.
- `%M`: two-digit minute.
- `%S`: two-digit second.

So the output may look like:

```text
20240816_100648
```

#### `$(...)`

This is command substitution.

It runs a command and stores the output.

This line:

```bash
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
```

Means:

```text
Run the date command, then store its output in the TIMESTAMP variable.
```

### Line 66

```bash
ARCHIVE_NAME="logs_archive_${TIMESTAMP}.tar.gz"
```

This creates the archive filename.

`${TIMESTAMP}` inserts the value of the `TIMESTAMP` variable into the string.

If:

```text
TIMESTAMP=20240816_100648
```

Then:

```text
ARCHIVE_NAME=logs_archive_20240816_100648.tar.gz
```

The file extension `.tar.gz` means:

- `.tar`: files are bundled together into one archive.
- `.gz`: the archive is compressed with gzip.

### Lines 68-69

```bash
# -p creates parent dirs as needed AND doesn't error if the dir already exists.
mkdir -p "$OUTPUT_DIR"
```

This creates the output directory.

`mkdir` means "make directory".

The `-p` option means:

- Create parent directories if needed.
- Do not fail if the directory already exists.

Example:

```bash
mkdir -p /backups/logs
```

If `/backups` does not exist, it will be created.

If `/backups/logs` already exists, no error is shown.

### Line 71

```bash
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"
```

This builds the full path to the archive file.

If:

```text
OUTPUT_DIR=/backups/logs
ARCHIVE_NAME=logs_archive_20240816_100648.tar.gz
```

Then:

```text
ARCHIVE_PATH=/backups/logs/logs_archive_20240816_100648.tar.gz
```

### Line 72

```bash
ARCHIVE_LOG="${OUTPUT_DIR}/archive_history.log"
```

This builds the path to the history log file.

If:

```text
OUTPUT_DIR=/backups/logs
```

Then:

```text
ARCHIVE_LOG=/backups/logs/archive_history.log
```

This file records every archive operation.

### Line 74

```bash
# ---- Create the archive -----------------------------------------------------
```

This section creates the compressed archive.

### Lines 76-83

```bash
# tar flags:
#   -c  create a new archive
#   -z  compress it with gzip
#   -f  the next argument is the output filename
#   -C  cd into LOG_DIR *before* archiving, then archive "."
#       This keeps paths inside the tarball relative (./syslog) instead of
#       absolute (/var/log/syslog), and avoids tar's "removing leading /" warning.
tar -czf "$ARCHIVE_PATH" -C "$LOG_DIR" .
```

This is the main command that compresses the logs.

`tar` is a common Unix/Linux command used to bundle files together.

The command:

```bash
tar -czf "$ARCHIVE_PATH" -C "$LOG_DIR" .
```

Can be read as:

```text
Create a gzip-compressed tar archive at ARCHIVE_PATH.
Before collecting files, switch into LOG_DIR.
Archive everything in that directory.
```

#### `-c`

Create a new archive.

#### `-z`

Compress the archive using gzip.

This is why the file ends with `.gz`.

#### `-f "$ARCHIVE_PATH"`

Use the next value as the archive filename.

In this script, that filename is stored in `ARCHIVE_PATH`.

#### `-C "$LOG_DIR"`

Change into the log directory before archiving.

This matters because it keeps paths inside the archive relative.

For example, with `-C "$LOG_DIR" .`, the archive may contain:

```text
./syslog
./auth.log
./nginx/access.log
```

Instead of absolute paths like:

```text
/var/log/syslog
/var/log/auth.log
```

Relative paths are usually safer and easier to restore.

#### `.`

The dot means "the current directory".

Because `tar` first changes into `LOG_DIR`, the dot means:

```text
Archive everything inside LOG_DIR.
```

### Line 85

```bash
# ---- Record the run ---------------------------------------------------------
```

This section records that the archive operation happened.

### Lines 87-88

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S')  archived '${LOG_DIR}' -> '${ARCHIVE_PATH}'" \
  >> "$ARCHIVE_LOG"
```

This writes one line to the archive history log file.

The line will look similar to:

```text
2024-08-16 10:06:48  archived '/var/log' -> '/backups/logs/logs_archive_20240816_100648.tar.gz'
```

#### `date '+%Y-%m-%d %H:%M:%S'`

This prints the current date and time in a human-readable format.

Example:

```text
2024-08-16 10:06:48
```

#### `\`

The backslash at the end of line 87 means the command continues on the next line.

So these two physical lines are treated as one command by Bash.

#### `>> "$ARCHIVE_LOG"`

This appends text to the file stored in `ARCHIVE_LOG`.

There are two common redirection operators:

- `>` writes to a file and replaces the old content.
- `>>` appends to a file and keeps the old content.

This script uses `>>` because it wants to keep the full archive history.

If the file does not exist yet, Bash creates it.

### Lines 90-92

```bash
echo "✓ Archived '${LOG_DIR}'"
echo "  Archive: ${ARCHIVE_PATH}"
echo "  History: ${ARCHIVE_LOG}"
```

These lines print a success message to the terminal.

They tell the user:

- Which directory was archived.
- Where the archive file was saved.
- Where the history log was saved.

Example output:

```text
✓ Archived '/var/log'
  Archive: /backups/logs/logs_archive_20240816_100648.tar.gz
  History: /backups/logs/archive_history.log
```

The check mark is only visual. It does not change how the script works.

## Important Bash Concepts Used

### Variables

Variables store values.

Example:

```bash
LOG_DIR="$1"
```

This stores the first argument in a variable named `LOG_DIR`.

To use a variable, put `$` before its name:

```bash
echo "$LOG_DIR"
```

### Command-Line Arguments

When you run:

```bash
./log-archive.sh /var/log /backups/logs
```

Bash makes these values available as:

```text
$0 = ./log-archive.sh
$1 = /var/log
$2 = /backups/logs
$# = 2
```

`$0` is the script name.

`$1`, `$2`, `$3`, and so on are arguments.

`$#` is the number of arguments.

### Quoting

The script uses quotes around variables:

```bash
"$LOG_DIR"
"$OUTPUT_DIR"
"$ARCHIVE_PATH"
```

This is important because paths can contain spaces.

For example:

```text
/home/user/my logs
```

Without quotes, Bash may treat this as two separate words:

```text
/home/user/my
logs
```

Quoting prevents that.

### Conditions

The script uses `if` statements to make decisions.

Example:

```bash
if [[ ! -d "$LOG_DIR" ]]; then
  echo "Error"
  exit 1
fi
```

This means:

```text
If LOG_DIR is not a directory, print an error and stop.
```

### Exit Codes

Programs return exit codes.

Common meanings:

- `0`: success.
- Non-zero value such as `1`: failure.

This script uses:

```bash
exit 0
```

for successful help output, and:

```bash
exit 1
```

for errors.

### Redirection

Redirection sends command output somewhere else.

Examples:

```bash
echo "hello" > file.txt
```

Writes `hello` to `file.txt`, replacing old content.

```bash
echo "hello" >> file.txt
```

Appends `hello` to the end of `file.txt`.

```bash
echo "error" >&2
```

Sends `error` to standard error.

## Example Run

Command:

```bash
./log-archive.sh /var/log
```

Because no output directory is provided, the script uses:

```text
./log-archives
```

It creates:

```text
./log-archives/logs_archive_20240816_100648.tar.gz
```

It also creates or updates:

```text
./log-archives/archive_history.log
```

The terminal output looks like:

```text
✓ Archived '/var/log'
  Archive: ./log-archives/logs_archive_20240816_100648.tar.gz
  History: ./log-archives/archive_history.log
```

## Error Examples

### Missing Argument

Command:

```bash
./log-archive.sh
```

Result:

```text
Error: missing log directory argument.
```

The script also prints the usage instructions and exits with failure.

### Invalid Directory

Command:

```bash
./log-archive.sh /does/not/exist
```

Result:

```text
Error: '/does/not/exist' is not a directory or does not exist.
```

The script stops before trying to create an archive.

### Help

Command:

```bash
./log-archive.sh --help
```

Result:

The script prints the usage instructions and exits successfully.

## Files Created by the Script

### Archive File

Example:

```text
logs_archive_20240816_100648.tar.gz
```

This contains the compressed logs.

### History Log

Example:

```text
archive_history.log
```

This records when archives were created and where they were saved.

Each run adds one new line.

## Summary

`log-archive.sh` is a small but useful Bash script. It demonstrates common shell scripting concepts:

- Reading command-line arguments.
- Validating user input.
- Defining and calling functions.
- Using variables.
- Creating directories.
- Running system commands like `date`, `mkdir`, and `tar`.
- Redirecting output to files.
- Writing basic error handling.

The most important command is:

```bash
tar -czf "$ARCHIVE_PATH" -C "$LOG_DIR" .
```

That command creates the compressed archive from the selected log directory.
