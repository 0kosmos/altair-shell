#!/usr/bin/env bash
# Measure Altair's CPU and memory use.
#
#   scripts/perf.sh [seconds]     (default: 10)
#
# CPU is the average over the window, as % of ONE core (100% = one core busy).
# RSS counts shared libraries fully; PSS splits shared pages fairly and is the
# better number to compare. Run it once idle, once with a panel open, and once
# with effects off to compare.
set -euo pipefail

secs="${1:-10}"
[[ "$secs" =~ ^[0-9]+$ && "$secs" -gt 0 ]] || { echo "usage: $0 [seconds]" >&2; exit 2; }

# Find the quickshell process running the altair config.
pid=""
for p in $(pgrep -x quickshell || true; pgrep -x qs || true); do
    if tr '\0' ' ' < "/proc/$p/cmdline" | grep -qE -- '(-c|--config)[ =]altair|altair-shell'; then
        pid="$p"; break
    fi
done
[[ -n "$pid" ]] || { echo "Altair is not running (no quickshell process with -c altair)." >&2; exit 1; }

ticks() { awk '{print $14 + $15}' "/proc/$pid/stat"; }   # utime + stime
hz=$(getconf CLK_TCK)

t0=$(ticks); s0=$(date +%s.%N)
sleep "$secs"
t1=$(ticks); s1=$(date +%s.%N)

cpu=$(awk -v a="$t0" -v b="$t1" -v hz="$hz" -v s0="$s0" -v s1="$s1" \
      'BEGIN { printf "%.2f", (b - a) / hz / (s1 - s0) * 100 }')
rss=$(awk '/^VmRSS/ {printf "%.1f", $2/1024}' "/proc/$pid/status")
pss=$(awk '/^Pss:/ {printf "%.1f", $2/1024}' "/proc/$pid/smaps_rollup")
threads=$(awk '/^Threads/ {print $2}' "/proc/$pid/status")

printf 'pid %s  over %ss\n  CPU      %s %%\n  RSS      %s MiB\n  PSS      %s MiB\n  threads  %s\n' \
    "$pid" "$secs" "$cpu" "$rss" "$pss" "$threads"
