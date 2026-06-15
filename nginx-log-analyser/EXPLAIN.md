# Explanation of `log-analyzer.sh`

This document explains how `log-analyzer.sh` works for someone who is new to Bash or shell scripting.

The script reads an nginx access log and prints summaries:

- Top 5 IP addresses with the most requests
- Top 5 most requested paths
- Top 5 response status codes
- Top 5 user agents

It does this with standard command-line tools such as `awk`, `sort`, `uniq`, and `head`.

## How to Run the Script

From inside the project directory:

```bash
./log-analyzer.sh
```

By default, the script reads this file:

```text
nginx-access.log
```

You can also pass a custom log file path:

```bash
./log-analyzer.sh /var/log/nginx/access.log
```

If the script is not executable yet, run:

```bash
chmod +x log-analyzer.sh
```

Then run it again.

## What Is an nginx Access Log?

An nginx access log records HTTP requests received by an nginx server.

A typical nginx combined log line looks like this:

```text
192.168.1.10 - - [16/Aug/2024:10:06:48 +0000] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

This line contains useful information:

- IP address: `192.168.1.10`
- Date and time: `[16/Aug/2024:10:06:48 +0000]`
- Request method: `GET`
- Request path: `/index.html`
- Protocol: `HTTP/1.1`
- Status code: `200`
- Response size: `1024`
- Referrer: `-`
- User agent: `Mozilla/5.0`

The script reads many lines like this and counts the most common values.

## What the Script Prints

Example output:

```text
Top 5 IP addresses with the most requests:
178.128.94.113 - 1087 requests
142.93.143.8 - 889 requests
138.68.248.85 - 662 requests
159.89.185.30 - 540 requests
86.134.118.70 - 497 requests

Top 5 most requested paths:
/api/users - 934 requests
/ - 812 requests
/login - 614 requests
/favicon.ico - 332 requests
/robots.txt - 291 requests

Top 5 response status codes:
200 - 3200 requests
404 - 900 requests
301 - 300 requests
500 - 50 requests
403 - 25 requests

Top 5 user agents:
Mozilla/5.0 - 1200 requests
curl/7.68.0 - 700 requests
Googlebot/2.1 - 300 requests
python-requests/2.31.0 - 250 requests
Wget/1.20.3 - 100 requests
```

The exact output depends on the contents of the log file.

## Big Picture Flow

The script does this:

1. Enables safer Bash behavior with `set -euo pipefail`.
2. Chooses which log file to read.
3. Checks that the log file exists.
4. Defines a reusable function named `format_top5`.
5. Extracts IP addresses from the log and counts the top 5.
6. Extracts requested paths from the log and counts the top 5.
7. Extracts response status codes from the log and counts the top 5.
8. Extracts user agents from the log and counts the top 5.

## Line-by-Line Explanation

### Line 1

```bash
#!/usr/bin/env bash
```

This is called a shebang.

It tells the operating system to run this script using Bash.

`/usr/bin/env bash` searches for the `bash` program in the current environment. This is more portable than hardcoding a path such as `/bin/bash`.

### Lines 2-11

```bash
#
# log-analyzer.sh - summarise an nginx access log.
#
# Usage:
#   ./log-analyzer.sh [path-to-log]   (defaults to ./nginx-access.log)
#
# nginx "combined" log line looks like:
#   IP - - [date] "METHOD /path HTTP/1.1" STATUS SIZE "referrer" "user agent"
#    $1         $4          $6  $7  $8      $9   $10
#
```

These are comments.

In Bash, anything after `#` is ignored by the shell, except for the shebang on the first line.

These comments explain:

- What the script does.
- How to run it.
- What an nginx combined log line looks like.

The usage line:

```text
./log-analyzer.sh [path-to-log]
```

Means the log file argument is optional.

If you do not provide a log path, the script uses:

```text
nginx-access.log
```

## Safe Bash Settings

### Line 12

```bash
set -euo pipefail
```

This makes the script safer.

The options are:

- `-e`: Exit immediately if a command fails.
- `-u`: Treat unset variables as errors.
- `-o pipefail`: If a pipeline fails in the middle, treat the whole pipeline as failed.

A pipeline is a chain of commands connected with `|`.

Example:

```bash
awk '{ print $1 }' "$LOG" | sort | uniq -c
```

Without `pipefail`, Bash usually only checks whether the last command failed. With `pipefail`, Bash notices if any command in the chain failed.

## Choosing the Log File

### Line 14

```bash
LOG="${1:-nginx-access.log}"
```

This creates a variable named `LOG`.

It stores the path to the log file that the script should read.

### What Is `$1`?

`$1` means the first command-line argument.

If you run:

```bash
./log-analyzer.sh /var/log/nginx/access.log
```

Then:

```text
$1 = /var/log/nginx/access.log
```

### What Does `${1:-nginx-access.log}` Mean?

This is Bash parameter expansion.

It means:

```text
Use $1 if it exists and is not empty.
Otherwise, use nginx-access.log.
```

Example 1:

```bash
./log-analyzer.sh /var/log/nginx/access.log
```

Result:

```text
LOG=/var/log/nginx/access.log
```

Example 2:

```bash
./log-analyzer.sh
```

Result:

```text
LOG=nginx-access.log
```

The quotes around the value are important because file paths can contain spaces.

## Checking That the Log File Exists

### Lines 15-18

```bash
if [[ ! -f "$LOG" ]]; then
  echo "Error: log file '$LOG' not found." >&2
  exit 1
fi
```

This checks whether the log file exists.

### `if [[ ... ]]; then`

This starts a conditional statement.

It means:

```text
If this condition is true, run the commands below.
```

### `-f`

`-f` checks whether a path exists and is a regular file.

### `!`

`!` means NOT.

So:

```bash
[[ ! -f "$LOG" ]]
```

Means:

```text
If LOG is not a regular file
```

### `echo "Error: log file '$LOG' not found." >&2`

`echo` prints text.

`>&2` sends the message to standard error instead of standard output.

There are two common output streams:

- `stdout`: normal output.
- `stderr`: error output.

Error messages should usually go to `stderr`.

### `exit 1`

This stops the script and returns exit code `1`.

Exit codes usually mean:

- `0`: success.
- Non-zero, such as `1`: failure.

### `fi`

`fi` ends an `if` block.

It is `if` spelled backward.

## The Reusable Counting Pipeline

### Lines 20-31

```bash
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
```

These comments explain the most important idea in the script.

The script repeatedly needs to answer this question:

```text
What are the 5 most common values?
```

For example:

- What are the 5 most common IP addresses?
- What are the 5 most common paths?
- What are the 5 most common status codes?
- What are the 5 most common user agents?

Instead of writing the same counting logic four times, the script defines one reusable function.

## `format_top5` Function

### Lines 32-35

```bash
format_top5() {
  sort | uniq -c | sort -rn | head -n 5 | \
    awk '{ count=$1; $1=""; sub(/^[ \t]+/, ""); printf "%s - %s requests\n", $0, count }'
}
```

This defines a function named `format_top5`.

The function expects input where each line contains one value.

Example input:

```text
/login
/api/users
/login
/
/api/users
/api/users
```

The function turns that into:

```text
/api/users - 3 requests
/login - 2 requests
/ - 1 requests
```

### Line 32

```bash
format_top5() {
```

This starts the function definition.

A function is a reusable block of commands.

The function can be called later like this:

```bash
awk '{ print $1 }' "$LOG" | format_top5
```

That means:

```text
Extract some values from the log, then send them into format_top5.
```

### Line 33

```bash
sort | uniq -c | sort -rn | head -n 5 | \
```

This is a pipeline.

Each command sends its output to the next command.

The pipeline is:

```text
sort -> uniq -c -> sort -rn -> head -n 5
```

### `sort`

`sort` sorts lines alphabetically.

Example input:

```text
b
a
b
c
a
```

After `sort`:

```text
a
a
b
b
c
```

This step matters because `uniq -c` only counts repeated lines that are next to each other.

### `uniq -c`

`uniq` removes repeated adjacent lines.

The `-c` option also counts them.

Example input:

```text
a
a
b
b
c
```

After `uniq -c`:

```text
2 a
2 b
1 c
```

The first number is the count.

### `sort -rn`

This sorts the counted results by number.

The options are:

- `-r`: reverse order, highest first.
- `-n`: numeric sort.

Example input:

```text
2 a
10 b
1 c
```

Without `-n`, text sorting can put `10` in the wrong place. With `-n`, numbers are sorted correctly.

After `sort -rn`:

```text
10 b
2 a
1 c
```

### `head -n 5`

`head` prints the first lines of input.

`-n 5` means:

```text
Keep only the first 5 lines.
```

Because the results are already sorted highest first, this gives the top 5 values.

### `\`

The backslash at the end of line 33 means the command continues on the next line.

It is used here to keep the long pipeline readable.

### Line 34

```bash
awk '{ count=$1; $1=""; sub(/^[ \t]+/, ""); printf "%s - %s requests\n", $0, count }'
```

This reformats the output.

Before this `awk`, a line might look like:

```text
1087 178.128.94.113
```

After this `awk`, it becomes:

```text
178.128.94.113 - 1087 requests
```

### `count=$1`

In `awk`, `$1` means the first field.

After `uniq -c`, the first field is the count.

So this saves the count in a variable named `count`.

### `$1=""`

This removes the first field from the current line.

Why?

Because the script wants to print the value first, then the count.

For example, it wants:

```text
Mozilla/5.0 - 20 requests
```

Not:

```text
20 Mozilla/5.0
```

### `sub(/^[ \t]+/, "")`

After removing `$1`, the line may start with spaces or tabs.

This removes leading whitespace.

Breaking it down:

- `sub(...)`: substitute text once.
- `/.../`: regular expression pattern.
- `^`: start of the line.
- `[ \t]+`: one or more spaces or tabs.
- `""`: replace with nothing.

So this means:

```text
Remove leading spaces and tabs from the line.
```

### `printf "%s - %s requests\n", $0, count`

This prints the final formatted line.

`$0` means the whole current line in `awk`.

At this point, `$0` is the value, such as:

```text
Mozilla/5.0
```

`count` is the request count.

`%s` is a string placeholder.

`\n` prints a newline.

### Why Not Just Use `$2`?

Some values contain spaces.

User agents often look like this:

```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
```

If the script used only `$2`, it would keep only the first word:

```text
Mozilla/5.0
```

That would lose most of the user agent.

By removing only the count and keeping the rest of the line, the script preserves values that contain spaces.

### Line 35

```bash
}
```

This ends the `format_top5` function.

## Top 5 IP Addresses

### Lines 37-41

```bash
# --- 1. Top 5 IP addresses ---------------------------------------------------
# The IP is the first whitespace-separated field.
echo "Top 5 IP addresses with the most requests:"
awk '{ print $1 }' "$LOG" | format_top5
echo
```

This section prints the 5 IP addresses that made the most requests.

### `echo "Top 5 IP addresses with the most requests:"`

This prints a title.

### `awk '{ print $1 }' "$LOG"`

This reads the log file and prints the first field from each line.

In a normal nginx access log line:

```text
192.168.1.10 - - [16/Aug/2024:10:06:48 +0000] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

The first field is:

```text
192.168.1.10
```

So this command extracts only the IP address from every log line.

Example output from this `awk` command:

```text
192.168.1.10
192.168.1.10
10.0.0.5
203.0.113.25
10.0.0.5
```

### `| format_top5`

The pipe sends the extracted IP addresses into the `format_top5` function.

Then `format_top5` counts them and prints the top 5.

### `echo`

This prints a blank line after the section.

It makes the output easier to read.

## Top 5 Requested Paths

### Lines 43-50

```bash
# --- 2. Top 5 requested paths ------------------------------------------------
# Counting fields by position breaks on malformed probe requests (e.g.
# "\x04\x01...") that contain no spaces and shift the columns. Instead we split
# the line on the quote ("), so the request is ALWAYS field 2, then take the
# path (the 2nd space-separated token of "METHOD PATH PROTOCOL").
echo "Top 5 most requested paths:"
awk -F'"' '{ split($2, a, " "); print (a[2] == "" ? "-" : a[2]) }' "$LOG" | format_top5
echo
```

This section prints the 5 most requested URL paths.

Examples of paths:

```text
/
/login
/api/users
/favicon.ico
```

### Why This Section Is More Careful

It might seem like the path is always field 7 if fields are split by spaces.

For a normal line:

```text
192.168.1.10 - - [date] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

Whitespace fields can look like:

```text
$1 = 192.168.1.10
$2 = -
$3 = -
$4 = [date]
$5 = timezone]
$6 = "GET
$7 = /index.html
$8 = HTTP/1.1"
$9 = 200
```

But malformed requests can break this pattern.

Some automated scanners or broken clients send unusual data that does not follow the normal request format.

To handle this better, the script splits each line by double quotes.

### `awk -F'"'`

This tells `awk` to use the double quote character as the field separator.

Normally, `awk` splits fields by whitespace.

With:

```bash
awk -F'"'
```

it splits fields wherever it sees:

```text
"
```

For this log line:

```text
192.168.1.10 - - [date] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

Splitting by `"` gives:

```text
$1 = 192.168.1.10 - - [date] 
$2 = GET /index.html HTTP/1.1
$3 =  200 1024 
$4 = -
$5 =  
$6 = Mozilla/5.0
```

The request is field `$2`.

### `split($2, a, " ")`

This splits the request field into an array named `a`, using spaces.

If:

```text
$2 = GET /index.html HTTP/1.1
```

Then:

```text
a[1] = GET
a[2] = /index.html
a[3] = HTTP/1.1
```

The path is:

```text
a[2]
```

### `print (a[2] == "" ? "-" : a[2])`

This prints the path.

It uses a conditional expression.

The format is:

```text
condition ? value_if_true : value_if_false
```

So:

```bash
a[2] == "" ? "-" : a[2]
```

Means:

```text
If a[2] is empty, print "-".
Otherwise, print a[2].
```

The `-` is used as a placeholder when the request path is missing or malformed.

### `| format_top5`

The extracted paths are sent into `format_top5`, which counts and prints the 5 most common paths.

## Top 5 Response Status Codes

### Lines 52-57

```bash
# --- 3. Top 5 response status codes ------------------------------------------
# Same idea: with FS='"', field 3 is " STATUS SIZE ", so the status is its
# first token. This stays correct even when the request field is garbage.
echo "Top 5 response status codes:"
awk -F'"' '{ split($3, a, " "); print a[1] }' "$LOG" | format_top5
echo
```

This section prints the 5 most common HTTP response status codes.

Examples:

- `200`: OK
- `301`: Moved Permanently
- `302`: Found
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

### Why Split by Quotes Again?

The script again uses:

```bash
awk -F'"'
```

For a normal combined log line:

```text
192.168.1.10 - - [date] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

The quoted fields are:

```text
$1 = 192.168.1.10 - - [date] 
$2 = GET /index.html HTTP/1.1
$3 =  200 1024 
$4 = -
$5 =  
$6 = Mozilla/5.0
```

Field `$3` contains:

```text
 200 1024 
```

That includes the status code and response size.

### `split($3, a, " ")`

This splits field `$3` by spaces.

If:

```text
$3 =  200 1024 
```

Then:

```text
a[1] = 200
a[2] = 1024
```

The status code is:

```text
a[1]
```

### `print a[1]`

This prints the status code for each log line.

Then the script pipes those status codes into `format_top5`.

## Top 5 User Agents

### Lines 59-64

```bash
# --- 4. Top 5 user agents ----------------------------------------------------
# The user agent is the last quoted string. Splitting the line on the double
# quote (") character, it becomes field 6. We strip a trailing \r in case the
# file uses Windows (CRLF) line endings.
echo "Top 5 user agents:"
awk -F'"' '{ ua=$6; sub(/\r$/, "", ua); print ua }' "$LOG" | format_top5
```

This section prints the 5 most common user agents.

### What Is a User Agent?

A user agent identifies the client making the request.

Examples:

```text
Mozilla/5.0
curl/7.68.0
Googlebot/2.1
python-requests/2.31.0
```

Browsers, bots, scripts, and command-line tools all send user agent strings.

### Why Is the User Agent Field `$6`?

Using the same quoted-field split:

```text
192.168.1.10 - - [date] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

Splitting by `"` gives:

```text
$1 = 192.168.1.10 - - [date] 
$2 = GET /index.html HTTP/1.1
$3 =  200 1024 
$4 = -
$5 =  
$6 = Mozilla/5.0
```

So `$6` is the user agent.

### `ua=$6`

This stores the user agent in an `awk` variable named `ua`.

### `sub(/\r$/, "", ua)`

This removes a trailing carriage return from the user agent, if one exists.

This matters when the log file uses Windows-style line endings.

There are two common line ending styles:

- Linux/macOS: `LF`, written as `\n`
- Windows: `CRLF`, written as `\r\n`

If a file has Windows line endings, the last field may contain a trailing `\r`.

The regular expression:

```awk
/\r$/
```

Means:

```text
Match a carriage return at the end of the string.
```

Breaking it down:

- `\r`: carriage return
- `$`: end of the string

The command:

```awk
sub(/\r$/, "", ua)
```

Means:

```text
Remove the trailing carriage return from ua.
```

### `print ua`

This prints the cleaned user agent.

Then the script pipes those user agents into `format_top5`.

## Important Bash Concepts Used

### Variables

Variables store values.

Example:

```bash
LOG="${1:-nginx-access.log}"
```

To use a variable, put `$` before its name:

```bash
echo "$LOG"
```

### Command-Line Arguments

When you run:

```bash
./log-analyzer.sh /var/log/nginx/access.log
```

Bash makes the argument available as:

```text
$1 = /var/log/nginx/access.log
```

This script uses `$1` as the optional log file path.

### Functions

Functions group commands together.

This script defines:

```bash
format_top5() {
  ...
}
```

Then it reuses that function for IPs, paths, status codes, and user agents.

### Pipes

A pipe sends output from one command into another.

Example:

```bash
awk '{ print $1 }' "$LOG" | format_top5
```

This means:

```text
Extract IP addresses, then send them into format_top5.
```

### Redirection

Redirection changes where input or output goes.

This script uses:

```bash
>&2
```

to send error messages to standard error.

### `awk`

`awk` is a text-processing tool.

This script uses `awk` to:

- Extract the first field for IP addresses.
- Split log lines by double quotes.
- Extract request paths.
- Extract status codes.
- Extract user agents.
- Reformat count results.

### `sort`

`sort` sorts lines.

It is needed before `uniq -c`, because `uniq` only counts adjacent duplicate lines.

### `uniq -c`

`uniq -c` counts repeated adjacent lines.

Example:

```text
3 /login
2 /
1 /api/users
```

### `head -n 5`

`head -n 5` keeps only the first 5 lines.

After sorting by count, this gives the top 5 values.

## Example: How IP Counting Works

Imagine the log has these IPs:

```text
10.0.0.1
10.0.0.2
10.0.0.1
10.0.0.3
10.0.0.2
10.0.0.1
```

First, `sort` produces:

```text
10.0.0.1
10.0.0.1
10.0.0.1
10.0.0.2
10.0.0.2
10.0.0.3
```

Then `uniq -c` produces:

```text
3 10.0.0.1
2 10.0.0.2
1 10.0.0.3
```

Then `sort -rn` keeps the highest counts first.

Then `head -n 5` keeps only the top 5.

Finally, `awk` formats the result:

```text
10.0.0.1 - 3 requests
10.0.0.2 - 2 requests
10.0.0.3 - 1 requests
```

## Why the Script Splits by Quotes

The script uses:

```bash
awk -F'"'
```

for paths, status codes, and user agents.

This is more reliable than only splitting by spaces because nginx access logs contain quoted sections.

For this line:

```text
IP - - [date] "METHOD /path HTTP/1.1" STATUS SIZE "referrer" "user agent"
```

The quoted sections are:

```text
"METHOD /path HTTP/1.1"
"referrer"
"user agent"
```

Splitting by quotes makes it easier to extract:

- Request: field `$2`
- Status and size: field `$3`
- Referrer: field `$4`
- User agent: field `$6`

This also helps when user agents contain spaces, which they often do.

## Limitations

This script is intentionally simple and practical.

Some limitations:

- It expects nginx access logs in combined or similar format.
- Very unusual log formats may not parse correctly.
- It does not validate every malformed line.
- It reads the whole log each time for each section.
- For extremely large logs, more optimized tools or a single-pass parser could be faster.
- It prints `1 requests` instead of `1 request`; this keeps the formatting simple.

## Summary

`log-analyzer.sh` is a Bash script that summarizes an nginx access log.

The most important reusable function is:

```bash
format_top5() {
  sort | uniq -c | sort -rn | head -n 5 | \
    awk '{ count=$1; $1=""; sub(/^[ \t]+/, ""); printf "%s - %s requests\n", $0, count }'
}
```

This function takes a list of values and returns the 5 most common ones.

The rest of the script extracts different values from the log:

- IP address: `awk '{ print $1 }'`
- Path: `awk -F'"' '{ split($2, a, " "); print (a[2] == "" ? "-" : a[2]) }'`
- Status code: `awk -F'"' '{ split($3, a, " "); print a[1] }'`
- User agent: `awk -F'"' '{ ua=$6; sub(/\r$/, "", ua); print ua }'`

Together, these commands provide a quick overview of traffic patterns in an nginx access log.
