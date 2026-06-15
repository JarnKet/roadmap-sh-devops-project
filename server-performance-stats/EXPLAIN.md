# Explanation of `server-stats.sh`

This document explains how `server-stats.sh` works for someone who is new to Bash or shell scripting.

The script is a command-line tool that prints basic Linux server performance information:

- Total CPU usage
- Memory usage
- Disk usage
- Top 5 processes by CPU usage
- Top 5 processes by memory usage
- Extra system information such as OS version, uptime, load average, logged-in users, and failed login attempts

This script is designed for Linux systems. It reads Linux-specific files such as `/proc/stat`, `/proc/loadavg`, and `/etc/os-release`.

## How to Run the Script

From inside the project directory:

```bash
./server-stats.sh
```

If the script is not executable yet, run:

```bash
chmod +x server-stats.sh
```

Then run it again:

```bash
./server-stats.sh
```

On Windows, this script should be run in a Linux-like environment such as WSL, a Linux virtual machine, or a real Linux server.

## What the Script Prints

The output is split into sections:

```text
==============================================
 CPU USAGE
==============================================
  Total CPU usage: 12.3%

==============================================
 MEMORY USAGE
==============================================
  Total: 15962 MB
  Used:  4231 MB (26.5%)
  Free:  8290 MB (51.9%)
```

The exact values depend on the machine where the script runs.

## Big Picture Flow

The script does the following:

1. Enables safer Bash behavior with `set -euo pipefail`.
2. Defines a helper function named `section`.
3. Reads CPU counters from `/proc/stat`.
4. Waits one second.
5. Reads CPU counters again.
6. Calculates CPU usage during that one-second window.
7. Prints memory usage using `free -m`.
8. Prints disk usage using `df -h`.
9. Prints the top 5 CPU-consuming processes using `ps`.
10. Prints the top 5 memory-consuming processes using `ps`.
11. Prints extra system information.
12. Tries to count failed SSH login attempts.

## Line-by-Line Explanation

### Line 1

```bash
#!/usr/bin/env bash
```

This is called a shebang.

It tells the operating system to run this file using Bash.

`/usr/bin/env bash` searches for the `bash` program in the current environment. This is more portable than writing a fixed path such as `/bin/bash`, because Bash can be installed in different locations on different systems.

### Lines 2-7

```bash
#
# server-stats.sh - analyse basic server performance stats on any Linux host.
#
# Usage:
#   ./server-stats.sh
#
```

These are comments.

In Bash, anything after `#` is ignored by the shell, except for the shebang on the first line.

These comments explain:

- The purpose of the script.
- How to run the script.

### Line 8

```bash
set -euo pipefail
```

This makes the script safer.

`set` changes how Bash behaves.

The options are:

- `-e`: Exit immediately if a command fails.
- `-u`: Treat unset variables as errors.
- `-o pipefail`: If a pipeline fails in the middle, treat the whole pipeline as failed.

A pipeline is a chain of commands connected with `|`.

Example:

```bash
command1 | command2 | command3
```

Without `pipefail`, Bash usually only checks whether the last command failed. With `pipefail`, Bash notices if any command in the chain failed.

## Section Helper Function

### Lines 10-16

```bash
# A small helper to print section titles consistently.
section() {
  echo
  echo "=============================================="
  echo " $1"
  echo "=============================================="
}
```

This defines a function named `section`.

A function is a reusable block of code.

Instead of repeating the same `echo` commands every time the script needs a title, the script can call:

```bash
section "CPU USAGE"
```

That prints:

```text

==============================================
 CPU USAGE
==============================================
```

### `section() {`

This starts the function definition.

The function name is:

```text
section
```

### `echo`

The first `echo` prints a blank line.

This creates spacing between sections.

### `echo "=============================================="`

This prints a separator line.

It is only for readability.

### `echo " $1"`

Inside a function, `$1` means the first argument passed to that function.

For example:

```bash
section "MEMORY USAGE"
```

Inside the function:

```text
$1 = MEMORY USAGE
```

So this line prints:

```text
 MEMORY USAGE
```

### `}`

This ends the function definition.

## CPU Usage Section

### Lines 18-21

```bash
# ---- CPU USAGE --------------------------------------------------------------
# We read /proc/stat twice, 1 second apart, and look at how the counters moved.
# /proc/stat's "cpu" line counts time spent in each state since boot (in "jiffies").
# CPU usage = (work done) / (total time) over that 1-second window.
```

These comments explain the strategy used to calculate CPU usage.

Linux stores CPU time counters in:

```text
/proc/stat
```

The script reads those counters twice:

1. First reading
2. Wait one second
3. Second reading

Then it compares the difference.

That difference shows how busy the CPU was during that one-second period.

### What Is `/proc/stat`?

`/proc/stat` is a virtual file provided by the Linux kernel.

It is not a normal file saved on disk. It is generated by the operating system when you read it.

The first line usually looks something like this:

```text
cpu  2255 34 2290 22625563 6290 127 456 0 0 0
```

The values are counters for how much time the CPU has spent in different states since the system booted.

Common fields include:

- `user`: time spent running normal user programs.
- `nice`: time spent running low-priority user programs.
- `system`: time spent running kernel code.
- `idle`: time spent doing nothing.
- `iowait`: time spent waiting for disk or network I/O.
- `irq`: time spent handling hardware interrupts.
- `softirq`: time spent handling software interrupts.
- `steal`: time taken by other virtual machines on a shared host.

These values are measured in units often called jiffies.

## `read_cpu_times` Function

### Lines 23-30

```bash
read_cpu_times() {
  # Fields: cpu user nice system idle iowait irq softirq steal ...
  local cpu user nice system idle iowait irq softirq steal
  read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
  local idle_all=$((idle + iowait))
  local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  echo "$total $idle_all"
}
```

This defines a function named `read_cpu_times`.

Its job is to read CPU timing data from `/proc/stat` and print two numbers:

1. Total CPU time
2. Idle CPU time

The script later uses those two numbers to calculate CPU usage.

### Line 23

```bash
read_cpu_times() {
```

This starts a function named `read_cpu_times`.

The function does not take named parameters. It reads directly from `/proc/stat`.

### Line 24

```bash
# Fields: cpu user nice system idle iowait irq softirq steal ...
```

This comment explains the fields read from `/proc/stat`.

The first word is usually `cpu`, followed by numbers.

### Line 25

```bash
local cpu user nice system idle iowait irq softirq steal
```

This creates local variables.

`local` means these variables only exist inside this function.

That prevents them from accidentally interfering with variables elsewhere in the script.

The variables are:

- `cpu`
- `user`
- `nice`
- `system`
- `idle`
- `iowait`
- `irq`
- `softirq`
- `steal`

### Line 26

```bash
read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
```

This reads the first line of `/proc/stat` and splits it into variables.

`read` reads one line of input.

`-r` tells `read` not to treat backslashes as special escape characters. This is generally safer.

The redirection:

```bash
< /proc/stat
```

means:

```text
Use /proc/stat as input for the read command.
```

If the first line of `/proc/stat` is:

```text
cpu  2255 34 2290 22625563 6290 127 456 0 0 0
```

Then Bash assigns:

```text
cpu=cpu
user=2255
nice=34
system=2290
idle=22625563
iowait=6290
irq=127
softirq=456
steal=0
```

The final `_` receives the remaining values, if there are any.

Using `_` is a common way to say:

```text
I do not need the rest of the fields.
```

### Line 27

```bash
local idle_all=$((idle + iowait))
```

This calculates total idle-like CPU time.

Bash arithmetic uses:

```bash
$(( ... ))
```

This line adds:

- `idle`: time when the CPU was idle.
- `iowait`: time when the CPU was waiting for input/output.

The result is stored in a local variable named `idle_all`.

### Line 28

```bash
local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
```

This calculates total CPU time.

It adds all the major CPU state counters together.

The result is stored in a local variable named `total`.

### Line 29

```bash
echo "$total $idle_all"
```

This prints two values separated by a space.

Example:

```text
12345678 9876543
```

The first value is total CPU time.

The second value is idle CPU time.

The rest of the script captures these two values into variables.

### Line 30

```bash
}
```

This ends the `read_cpu_times` function.

## Reading CPU Values Twice

### Line 32

```bash
read -r total1 idle1 < <(read_cpu_times)
```

This calls the `read_cpu_times` function and stores its output in two variables:

- `total1`
- `idle1`

This is the first CPU reading.

### Understanding `< <(...)`

This part can look confusing:

```bash
< <(read_cpu_times)
```

It uses process substitution.

`read_cpu_times` prints output like:

```text
12345678 9876543
```

Then `read` receives that output as input.

So this line means:

```text
Run read_cpu_times, then read its two output values into total1 and idle1.
```

### Line 33

```bash
sleep 1
```

This pauses the script for one second.

The pause is important because CPU usage is calculated over time.

If the script only read `/proc/stat` once, it would only know total CPU time since boot. Reading twice gives the script a time window to compare.

### Line 34

```bash
read -r total2 idle2 < <(read_cpu_times)
```

This takes the second CPU reading after the one-second pause.

It stores the values in:

- `total2`
- `idle2`

Now the script has two snapshots:

```text
First snapshot:  total1, idle1
Second snapshot: total2, idle2
```

## Calculating CPU Usage

### Lines 36-42

```bash
# Delta over the 1s window. We use awk for clean decimal math.
cpu_usage=$(awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2" \
  'BEGIN {
     total_diff = t2 - t1
     idle_diff  = i2 - i1
     printf "%.1f", (total_diff - idle_diff) / total_diff * 100
   }')
```

This calculates the CPU usage percentage.

Bash can do integer math, but it is not good for decimal math. This script uses `awk` because `awk` can easily handle decimal calculations.

### `cpu_usage=$(...)`

This is command substitution.

It runs the command inside `$(...)` and stores the output in the `cpu_usage` variable.

### `awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2"`

This starts an `awk` program and passes Bash variables into it.

The `-v` option creates variables inside `awk`.

For example:

```bash
-v t1="$total1"
```

Means:

```text
Create an awk variable named t1 using the Bash variable total1.
```

The script passes:

- `t1`: first total CPU reading
- `i1`: first idle CPU reading
- `t2`: second total CPU reading
- `i2`: second idle CPU reading

### `\`

The backslash at the end of the line means the command continues on the next line.

This is used to make long commands easier to read.

### `BEGIN { ... }`

In `awk`, a `BEGIN` block runs before reading any input.

This script does not need to process a file line by line here. It only needs `awk` for math, so it does all the work in `BEGIN`.

### `total_diff = t2 - t1`

This calculates how much total CPU time passed between the two readings.

### `idle_diff = i2 - i1`

This calculates how much idle CPU time passed between the two readings.

### `(total_diff - idle_diff) / total_diff * 100`

This calculates CPU usage percentage.

In plain English:

```text
busy time = total time - idle time
CPU usage percent = busy time / total time * 100
```

### `printf "%.1f", ...`

This prints the result with one decimal place.

Example:

```text
12.3
```

## Printing CPU Usage

### Lines 44-45

```bash
section "CPU USAGE"
printf "  Total CPU usage: %s%%\n" "$cpu_usage"
```

The first line prints a section header.

The second line prints the CPU usage value.

### Why `%%`?

In `printf`, `%` has special meaning. It starts a placeholder such as `%s`.

To print a literal percent sign, you write:

```bash
%%
```

So:

```bash
printf "  Total CPU usage: %s%%\n" "$cpu_usage"
```

Prints something like:

```text
  Total CPU usage: 12.3%
```

## Memory Usage Section

### Lines 47-48

```bash
# ---- MEMORY USAGE -----------------------------------------------------------
# `free -m` reports memory in MB. We parse the "Mem:" row and compute percentages.
```

These comments explain that the script uses the `free` command to get memory information.

### Lines 50-56

```bash
section "MEMORY USAGE"
free -m | awk '/^Mem:/ {
  total = $2; used = $3; free = $4
  printf "  Total: %d MB\n", total
  printf "  Used:  %d MB (%.1f%%)\n", used, used/total*100
  printf "  Free:  %d MB (%.1f%%)\n", free, free/total*100
}'
```

This prints memory usage.

### `section "MEMORY USAGE"`

This prints the memory section title.

### `free -m`

`free` shows memory usage.

The `-m` option shows values in megabytes.

Example output:

```text
              total        used        free      shared  buff/cache   available
Mem:          15962        4231        8290         120        3440       11300
Swap:          2047           0        2047
```

### `|`

The pipe symbol sends the output of one command into another command.

This:

```bash
free -m | awk '...'
```

Means:

```text
Run free -m, then send its output to awk.
```

### `awk '/^Mem:/ { ... }'`

This tells `awk` to only process the line that starts with `Mem:`.

The pattern:

```awk
/^Mem:/
```

Means:

```text
Match lines that begin with Mem:
```

The `^` means "start of line".

### `total = $2; used = $3; free = $4`

In `awk`, `$1`, `$2`, `$3`, and so on refer to columns.

For the `Mem:` line:

```text
Mem: 15962 4231 8290 ...
```

The fields are:

```text
$1 = Mem:
$2 = 15962
$3 = 4231
$4 = 8290
```

So the script sets:

```text
total = total memory
used  = used memory
free  = free memory
```

### Memory `printf` Lines

```bash
printf "  Total: %d MB\n", total
printf "  Used:  %d MB (%.1f%%)\n", used, used/total*100
printf "  Free:  %d MB (%.1f%%)\n", free, free/total*100
```

These lines print:

- Total memory in MB
- Used memory in MB and percentage
- Free memory in MB and percentage

`%d` prints an integer.

`%.1f` prints a decimal number with one digit after the decimal point.

## Disk Usage Section

### Lines 58-60

```bash
# ---- DISK USAGE -------------------------------------------------------------
# `df` shows filesystem usage. --total adds a summary row. We exclude pseudo
# filesystems (tmpfs, devtmpfs, overlay) so we only count real disks.
```

These comments explain that the script uses `df` to check disk usage.

### Lines 62-68

```bash
section "DISK USAGE"
df -h --total -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk '
  /^total/ {
    printf "  Total: %s\n", $2
    printf "  Used:  %s (%s)\n", $3, $5
    printf "  Free:  %s\n", $4
  }'
```

This prints total disk usage.

### `df`

`df` means disk free.

It reports filesystem disk space usage.

### `-h`

The `-h` option means human-readable.

It prints values like:

```text
20G
512M
1.5T
```

instead of raw block counts.

### `--total`

This adds a final summary line named `total`.

The script uses that summary line instead of printing every filesystem separately.

### `-x tmpfs -x devtmpfs -x overlay`

The `-x` option excludes filesystem types.

The script excludes:

- `tmpfs`
- `devtmpfs`
- `overlay`

These are often temporary, virtual, or container-related filesystems.

The goal is to focus on real disk usage.

### `2>/dev/null`

This hides error messages from `df`.

`2>` redirects standard error.

`/dev/null` is a special Linux location that discards anything written to it.

So:

```bash
2>/dev/null
```

Means:

```text
Send error messages nowhere.
```

### `awk '/^total/ { ... }'`

This processes only the line that starts with `total`.

Example `df` output might include:

```text
total   100G   35G   65G   35%   -
```

Then:

```text
$2 = 100G
$3 = 35G
$4 = 65G
$5 = 35%
```

The script prints those fields as total, used, and free disk space.

## Top 5 Processes by CPU

### Lines 70-71

```bash
# ---- TOP 5 PROCESSES BY CPU -------------------------------------------------
# ps lists processes; --sort=-%cpu orders by CPU descending; we take the top 5.
```

These comments explain that the script uses `ps` to list running processes.

### Lines 73-76

```bash
section "TOP 5 PROCESSES BY CPU"
printf "  %-8s %-25s %s\n" "PID" "COMMAND" "%CPU"
ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | head -n 5 | \
  awk '{ printf "  %-8s %-25s %s\n", $1, $2, $3 }'
```

This prints the top 5 processes using the most CPU.

### Header Line

```bash
printf "  %-8s %-25s %s\n" "PID" "COMMAND" "%CPU"
```

This prints column names:

```text
PID      COMMAND                   %CPU
```

`printf` is used because it gives better formatting control than `echo`.

### `%-8s`

This means:

```text
Print a string, left-aligned, using 8 characters of space.
```

### `%-25s`

This means:

```text
Print a string, left-aligned, using 25 characters of space.
```

This keeps the columns lined up.

### `ps -eo pid,comm,%cpu`

`ps` shows running processes.

The `-e` option means:

```text
Show every process.
```

The `-o` option chooses output columns.

This script asks for:

- `pid`: process ID
- `comm`: command name
- `%cpu`: CPU usage percentage

### `--sort=-%cpu`

This sorts the process list by CPU usage.

The minus sign means descending order, so the highest CPU usage appears first.

### `--no-headers`

This removes the header line from `ps` output.

The script prints its own header with `printf`, so it does not need the default `ps` header.

### `head -n 5`

`head` prints the first lines of input.

`-n 5` means:

```text
Print only the first 5 lines.
```

Because the process list is already sorted by CPU usage, the first 5 lines are the top 5 CPU processes.

### Final `awk`

```bash
awk '{ printf "  %-8s %-25s %s\n", $1, $2, $3 }'
```

This formats the process list into aligned columns.

For each line:

- `$1` is the process ID.
- `$2` is the command name.
- `$3` is CPU usage.

## Top 5 Processes by Memory

### Lines 78-83

```bash
# ---- TOP 5 PROCESSES BY MEMORY ----------------------------------------------

section "TOP 5 PROCESSES BY MEMORY"
printf "  %-8s %-25s %s\n" "PID" "COMMAND" "%MEM"
ps -eo pid,comm,%mem --sort=-%mem --no-headers | head -n 5 | \
  awk '{ printf "  %-8s %-25s %s\n", $1, $2, $3 }'
```

This section is almost the same as the CPU process section.

The difference is that it sorts by memory usage instead of CPU usage.

### `%mem`

`%mem` means the percentage of system memory used by the process.

### `--sort=-%mem`

This sorts processes by memory usage in descending order.

The first 5 results are the processes using the most memory.

## Extra System Information

### Lines 85-87

```bash
# ---- STRETCH GOALS ----------------------------------------------------------

section "SYSTEM INFO (extra)"
```

This starts the extra system information section.

The script calls this "extra" because the main performance requirements are CPU, memory, disk, and process usage.

## OS Version

### Lines 89-94

```bash
# OS version (from the standard /etc/os-release file)
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf "  OS:            %s\n" "${PRETTY_NAME:-unknown}"
fi
```

This prints the operating system name.

### `/etc/os-release`

`/etc/os-release` is a standard Linux file containing OS information.

It may contain values like:

```text
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
```

### `if [[ -r /etc/os-release ]]; then`

This checks whether `/etc/os-release` is readable.

`-r` means:

```text
The file exists and the current user can read it.
```

### `. /etc/os-release`

The dot command is also called `source`.

It loads variables from a file into the current shell.

After this line runs, variables from `/etc/os-release` become available to the script.

For example:

```bash
PRETTY_NAME="Ubuntu 24.04 LTS"
```

### `# shellcheck disable=SC1091`

This is a comment for ShellCheck, a tool that checks shell scripts for problems.

ShellCheck may warn when a script sources a file that it cannot inspect. This comment tells ShellCheck to ignore that specific warning for the next line.

It does not affect how Bash runs the script.

### `${PRETTY_NAME:-unknown}`

This is Bash parameter expansion.

It means:

```text
Use PRETTY_NAME if it exists and is not empty.
Otherwise, use unknown.
```

So if `PRETTY_NAME` is available, the script prints:

```text
OS: Ubuntu 24.04 LTS
```

If not, it prints:

```text
OS: unknown
```

### `fi`

`fi` ends an `if` block.

It is `if` spelled backward.

## Uptime

### Line 97

```bash
printf "  Uptime:        %s\n" "$(uptime -p 2>/dev/null || echo unknown)"
```

This prints how long the system has been running.

### `uptime -p`

`uptime` shows how long the system has been up.

The `-p` option means pretty format.

Example:

```text
up 2 days, 4 hours, 10 minutes
```

### `2>/dev/null`

This hides error messages from the `uptime` command.

### `|| echo unknown`

`||` means OR in shell command logic.

In this context, it means:

```text
If uptime -p fails, run echo unknown.
```

So the script will print `unknown` if the uptime command is unavailable or fails.

### `"$(...)"`

This is command substitution.

It runs the command inside `$(...)` and inserts the output into the `printf` command.

## Load Average

### Lines 99-101

```bash
# Load average (1, 5, 15 minutes) - read straight from /proc/loadavg
read -r l1 l5 l15 _ < /proc/loadavg
printf "  Load average:  %s (1m)  %s (5m)  %s (15m)\n" "$l1" "$l5" "$l15"
```

This prints system load average.

### What Is Load Average?

Load average is a measure of how much work is waiting for CPU or I/O resources.

Linux usually reports load average for:

- 1 minute
- 5 minutes
- 15 minutes

A low load average means the system is not very busy.

A high load average means many processes are running or waiting.

The meaning of "high" depends on how many CPU cores the machine has.

For example, on a 1-core machine, a load average of `1.00` means roughly fully loaded. On a 4-core machine, `4.00` means roughly fully loaded.

### `/proc/loadavg`

This Linux virtual file contains load average values.

Example:

```text
0.15 0.20 0.18 1/234 12345
```

The first three fields are:

```text
0.15 = 1 minute load average
0.20 = 5 minute load average
0.18 = 15 minute load average
```

### `read -r l1 l5 l15 _ < /proc/loadavg`

This reads values from `/proc/loadavg`.

It stores:

- First value in `l1`
- Second value in `l5`
- Third value in `l15`

The `_` stores the rest of the values, which the script does not use.

## Logged-In Users

### Lines 103-104

```bash
# Logged-in users
printf "  Logged-in users: %s\n" "$(who | wc -l)"
```

This prints the number of currently logged-in users.

### `who`

The `who` command lists logged-in users.

Example:

```text
alice    pts/0        2026-06-15 10:00
bob      pts/1        2026-06-15 10:10
```

### `wc -l`

`wc` means word count.

The `-l` option counts lines.

So:

```bash
who | wc -l
```

Means:

```text
Count how many lines the who command prints.
```

Since each logged-in session usually appears on one line, this gives the number of logged-in users or sessions.

## Failed Login Attempts

### Lines 106-109

```bash
# Failed login attempts (best-effort; needs read access to auth logs).
# Note: `grep -c` ALWAYS prints a count to stdout, but EXITS 1 when the count
# is 0. So `grep -c ... || echo X` would print BOTH the "0" and the fallback.
# We use `|| true` to swallow only the exit code, then default empty to 0.
```

These comments explain that counting failed logins is best-effort.

It may not work on every system because:

- Different Linux distributions store authentication logs in different places.
- The user may not have permission to read authentication logs.
- Some systems use `journalctl` instead of `/var/log/auth.log`.

### Line 110

```bash
fails="n/a"
```

This creates a variable named `fails` and sets it to:

```text
n/a
```

This means "not available".

The script uses this as the default value before trying to count failed logins.

### Lines 111-115

```bash
if [[ -r /var/log/auth.log ]]; then
  fails=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || true)
elif command -v journalctl >/dev/null 2>&1; then
  fails=$(journalctl _COMM=sshd 2>/dev/null | grep -c "Failed password" || true)
fi
```

This block tries two methods to count failed SSH login attempts.

### First Method: `/var/log/auth.log`

```bash
if [[ -r /var/log/auth.log ]]; then
```

This checks if `/var/log/auth.log` is readable.

On Debian and Ubuntu systems, SSH authentication messages are often stored in:

```text
/var/log/auth.log
```

If the file is readable, the script runs:

```bash
grep -c "Failed password" /var/log/auth.log 2>/dev/null || true
```

### `grep -c "Failed password" /var/log/auth.log`

`grep` searches text.

The `-c` option counts matching lines.

This command counts how many lines contain:

```text
Failed password
```

That phrase commonly appears in SSH logs when someone enters a wrong password.

### Why `|| true`?

This script uses `set -e`, which means the script exits if a command fails.

`grep -c` has a special behavior:

- It prints a count.
- But if the count is zero, it exits with status `1`.

Because `set -e` is enabled, that exit status could stop the whole script even though zero failed logins is not really an error.

So the script uses:

```bash
|| true
```

This means:

```text
If grep exits with a failure status, ignore that failure and continue.
```

### Second Method: `journalctl`

```bash
elif command -v journalctl >/dev/null 2>&1; then
```

This runs if `/var/log/auth.log` was not readable.

`command -v journalctl` checks whether the `journalctl` command exists.

`journalctl` is used on many systemd-based Linux systems to read system logs.

The redirection:

```bash
>/dev/null 2>&1
```

hides both normal output and error output.

This check only cares whether the command exists.

If `journalctl` exists, the script runs:

```bash
journalctl _COMM=sshd 2>/dev/null | grep -c "Failed password" || true
```

This asks the system journal for logs from the `sshd` process, then counts lines containing `Failed password`.

### Line 116

```bash
[[ -z "$fails" ]] && fails=0
```

This checks whether `fails` is empty.

`-z` means:

```text
String length is zero.
```

The `&&` operator means:

```text
If the command on the left succeeds, run the command on the right.
```

So this line means:

```text
If fails is empty, set fails to 0.
```

### Line 117

```bash
printf "  Failed logins: %s\n" "$fails"
```

This prints the failed login count.

If the script could count failed logins, it may print:

```text
Failed logins: 3
```

If it could not check logs, it may print:

```text
Failed logins: n/a
```

### Line 119

```bash
echo
```

This prints a final blank line.

It makes the terminal output look cleaner.

## Important Bash Concepts Used

### Variables

Variables store values.

Example:

```bash
cpu_usage="12.3"
```

To use a variable, put `$` before its name:

```bash
echo "$cpu_usage"
```

### Functions

Functions group commands under a name.

Example:

```bash
section() {
  echo "$1"
}
```

Then you can call:

```bash
section "CPU USAGE"
```

### Command Substitution

Command substitution runs a command and uses its output.

Example:

```bash
now="$(date)"
```

This stores the output of `date` in the variable `now`.

This script uses command substitution in lines like:

```bash
cpu_usage=$(awk ...)
```

and:

```bash
printf "  Uptime: %s\n" "$(uptime -p)"
```

### Arithmetic Expansion

Bash arithmetic uses:

```bash
$(( ... ))
```

Example:

```bash
total=$((user + nice + system + idle))
```

This script uses arithmetic expansion to add CPU counters.

### Pipes

A pipe sends the output of one command into another command.

Example:

```bash
free -m | awk '/^Mem:/ { print $2 }'
```

This means:

```text
Run free -m, then let awk process its output.
```

### Redirection

Redirection changes where input or output goes.

Examples:

```bash
read line < file.txt
```

Reads input from `file.txt`.

```bash
command 2>/dev/null
```

Discards error output.

```bash
command >/dev/null 2>&1
```

Discards both normal output and error output.

### Conditions

The script uses `if` statements to make decisions.

Example:

```bash
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
fi
```

This means:

```text
If /etc/os-release is readable, load it.
```

### `awk`

`awk` is a text-processing tool.

It is useful for:

- Reading columns
- Filtering lines
- Doing calculations
- Formatting output

This script uses `awk` for memory, disk, process formatting, and CPU percentage math.

### `printf`

`printf` prints formatted text.

It is more predictable than `echo` when formatting columns or decimal values.

Example:

```bash
printf "CPU: %.1f%%\n" 12.345
```

Prints:

```text
CPU: 12.3%
```

## Commands Used by the Script

### `sleep`

Pauses the script.

Used here to wait one second between CPU readings.

### `free`

Shows memory usage.

Used here with:

```bash
free -m
```

### `df`

Shows disk space usage.

Used here with:

```bash
df -h --total
```

### `ps`

Shows running processes.

Used here to find top processes by CPU and memory.

### `head`

Shows the first lines of input.

Used here with:

```bash
head -n 5
```

### `who`

Shows logged-in users.

### `wc`

Counts words, lines, or characters.

Used here with:

```bash
wc -l
```

to count logged-in user sessions.

### `grep`

Searches text.

Used here to count failed SSH password attempts.

### `journalctl`

Reads systemd journal logs.

Used as a fallback when `/var/log/auth.log` is not readable.

## Example Output

The output may look like this:

```text
==============================================
 CPU USAGE
==============================================
  Total CPU usage: 8.4%

==============================================
 MEMORY USAGE
==============================================
  Total: 15962 MB
  Used:  4231 MB (26.5%)
  Free:  8290 MB (51.9%)

==============================================
 DISK USAGE
==============================================
  Total: 100G
  Used:  35G (35%)
  Free:  65G

==============================================
 TOP 5 PROCESSES BY CPU
==============================================
  PID      COMMAND                   %CPU
  1234     nginx                     3.2
  2345     postgres                  2.8
  3456     node                      1.5
  4567     sshd                      0.7
  5678     bash                      0.1

==============================================
 TOP 5 PROCESSES BY MEMORY
==============================================
  PID      COMMAND                   %MEM
  2345     postgres                  12.5
  3456     node                      8.1
  1234     nginx                     2.3
  4567     sshd                      0.4
  5678     bash                      0.1

==============================================
 SYSTEM INFO (extra)
==============================================
  OS:            Ubuntu 24.04 LTS
  Uptime:        up 2 days, 4 hours
  Load average:  0.15 (1m)  0.20 (5m)  0.18 (15m)
  Logged-in users: 1
  Failed logins: 0
```

## Why CPU Usage Is Calculated Differently

Memory and disk usage can be read directly from commands like `free` and `df`.

CPU usage is different because `/proc/stat` gives totals since boot, not a direct current percentage.

That is why the script:

1. Reads CPU counters.
2. Waits one second.
3. Reads CPU counters again.
4. Calculates how much of that one-second period was busy time.

This gives a useful snapshot of current CPU activity.

## Limitations

This script is intentionally simple.

Some limitations:

- It only works properly on Linux.
- Failed login counting depends on log permissions.
- `ps` command output can vary slightly between Unix-like systems.
- CPU usage is a one-second sample, not a long-term average.
- Disk usage excludes `tmpfs`, `devtmpfs`, and `overlay`, which may or may not be what every environment wants.
- In containers, some values may represent the container environment rather than the full host.

## Summary

`server-stats.sh` is a Bash script that gathers useful Linux performance information using standard system files and commands.

The most important parts are:

- `/proc/stat` for CPU counters
- `free -m` for memory usage
- `df -h --total` for disk usage
- `ps` for top processes
- `/etc/os-release` for OS information
- `/proc/loadavg` for load average
- `who | wc -l` for logged-in users
- `grep` or `journalctl` for failed login attempts

The script is a good example of practical shell scripting because it combines functions, variables, command substitution, pipes, redirection, conditionals, arithmetic, and text processing.
