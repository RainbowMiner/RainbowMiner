#!/bin/sh
# getcputopo.sh - POSIX sh CPU topology exporter (JSON)
# Tries (in order):
#   1) sysfs: /sys/devices/system/cpu (best, uses thread_siblings_list)
#   2) lscpu: lscpu -p=CPU,SOCKET,CORE
#   3) /proc/cpuinfo (best effort: physical/core ids if present)
#   4) dense fallback from /proc/cpuinfo counts (0..cores-1, cores..threads-1)
#
# Output: JSON array of objects sorted by socket,core,thread,cpu:
#   {"cpu":N,"socket":S,"core":C,"thread":T,"online":true|false}
#
# Notes:
# - "online" is derived like Linux sysfs: if cpuN/online missing => online=true
# - All non-JSON noise is suppressed; stdout should always be valid JSON.

set -eu
export LC_ALL=C

SYSCPU="/sys/devices/system/cpu"
CPUINFO="/proc/cpuinfo"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

choose_tmpdir() {
  pid="$$"

  # Try TMPDIR first (if set), then /tmp, then current dir
  for d in "${TMPDIR:-}" "/tmp" "."; do
    [ -n "$d" ] || continue
    [ -d "$d" ] || continue

    testfile="$d/.cpu_topo_test.$pid"

    # IMPORTANT: redirection errors must be caught by redirecting the subshell
    if ( : > "$testfile" ) 2>/dev/null; then
      rm -f "$testfile" 2>/dev/null || true
      printf '%s\n' "$d"
      return 0
    fi
  done

  return 1
}

TMPBASE="$(choose_tmpdir 2>/dev/null || printf '%s\n' ".")"
tmp="$TMPBASE/cpu_topology.$$"

cleanup() { rm -f "$tmp" "$tmp".* 2>/dev/null || true; }
trap 'cleanup' EXIT INT HUP TERM

# ----- Append online column (0/1) -----
# stdin:  "socket core thread cpu"
# stdout: "socket core thread cpu online"
add_online_column() {
  awk '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    {
      socket=$1+0; core=$2+0; thread=$3+0; cpu=$4+0;
      online=1;
      path=sprintf("/sys/devices/system/cpu/cpu%d/online", cpu);

      # POSIX awk: attempt to read cpu online state; if file missing/unreadable -> treat as online
      if ((getline v < path) > 0) {
        v = trim(v);
        if (v != "1") online=0;
      }
      close(path);

      printf "%d %d %d %d %d\n", socket, core, thread, cpu, online
    }
  '
}

# ----- JSON emitter from 5-column lines -----
# stdin must be sorted: "socket core thread cpu online(0|1)"
emit_json_from_lines() {
  awk '
    BEGIN { first=1; print "[" }
    {
      online = ($5+0==1) ? "true" : "false";
      if (!first) print ",";
      first=0;
      printf "  {\"cpu\":%d,\"socket\":%d,\"core\":%d,\"thread\":%d,\"online\":%s}", $4, $1, $2, $3, online
    }
    END { print ""; print "]" }
  '
}

# ----- 1) sysfs -----
try_sysfs() {
  [ -d "$SYSCPU" ] || return 1
  ls "$SYSCPU"/cpu[0-9]* >/dev/null 2>&1 || return 1

  : > "$tmp.sys.raw"
  for d in "$SYSCPU"/cpu[0-9]*; do
    [ -d "$d" ] || continue
    bn=$(basename "$d")
    cpu=${bn#cpu}
    case "$cpu" in (*[!0-9]*|'') continue;; esac

    topo="$d/topology"
    socket="-1"
    core="-1"
    siblings=""

    if [ -r "$topo/physical_package_id" ]; then
      socket=$(cat "$topo/physical_package_id" 2>/dev/null || echo "-1")
    fi
    if [ -r "$topo/core_id" ]; then
      core=$(cat "$topo/core_id" 2>/dev/null || echo "-1")
    fi
    if [ -r "$topo/thread_siblings_list" ]; then
      siblings=$(cat "$topo/thread_siblings_list" 2>/dev/null || true)
    fi
    [ -n "$siblings" ] || siblings="$cpu"

    case "$socket" in (*[!0-9]*|'') socket="-1";; esac
    case "$core"   in (*[!0-9]*|'') core="-1";; esac

    printf '%s|%s|%s|%s\n' "$cpu" "$socket" "$core" "$siblings" >> "$tmp.sys.raw"
  done

  # Expand thread_siblings_list per (socket,core) and assign thread index by siblings order.
  awk -F'|' '
    function add_exist(c){ exist[c]=1 }
    function expand(list, a, n, i, part, lo, hi) {
      n = split(list, a, /,/)
      outn = 0
      for (i=1;i<=n;i++) {
        part = a[i]
        if (part ~ /^[0-9]+-[0-9]+$/) {
          split(part, r, /-/); lo=r[1]+0; hi=r[2]+0
          for (j=lo;j<=hi;j++) out[++outn]=j
        } else if (part ~ /^[0-9]+$/) {
          out[++outn]=part+0
        }
      }
      delete seen
      for (i=1;i<=outn;i++) seen[out[i]]=1
      m=0
      for (k in seen) arr[++m]=k+0
      for (i=1;i<=m;i++) for (j=i+1;j<=m;j++) if (arr[j] < arr[i]) {t=arr[i];arr[i]=arr[j];arr[j]=t}
      sc=0
      for (i=1;i<=m;i++) sorted[++sc]=arr[i]
      return sc
    }
    {
      cpu=$1+0; socket=$2+0; core=$3+0; sib=$4
      add_exist(cpu)
      key = socket SUBSEP core
      if (!(key in siblist)) siblist[key]=sib
    }
    END{
      for (key in siblist) {
        split(key, kk, SUBSEP); socket=kk[1]+0; core=kk[2]+0
        delete sorted
        sc = expand(siblist[key], tmpa)
        tidx=0
        for (i=1;i<=sc;i++) {
          c = sorted[i]+0
          if (exist[c]) {
            printf "%d %d %d %d\n", socket, core, tidx, c
            tidx++
          }
        }
      }
    }
  ' "$tmp.sys.raw" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  cat "$tmp.out" | emit_json_from_lines
  return 0
}

# ----- 2) lscpu -----
try_lscpu() {
  have_cmd lscpu || return 1

  lscpu -p=CPU,SOCKET,CORE 2>/dev/null | awk -F',' '
    $0 ~ /^#/ { next }
    $1 ~ /^[0-9]+$/ {
      cpu=$1+0
      socket = ($2 ~ /^[0-9]+$/) ? $2+0 : 0
      core   = ($3 ~ /^[0-9]+$/) ? $3+0 : cpu
      print socket, core, cpu
    }
  ' | sort -n -k1,1 -k2,2 -k3,3 > "$tmp.ls.sorted"

  [ -s "$tmp.ls.sorted" ] || return 1

  awk '
    {
      socket=$1; core=$2; cpu=$3
      key=socket ":" core
      tidx[key]++
      thread=tidx[key]-1
      printf "%d %d %d %d\n", socket, core, thread, cpu
    }
  ' "$tmp.ls.sorted" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  cat "$tmp.out" | emit_json_from_lines
  return 0
}

# ----- 3) /proc/cpuinfo (POSIX awk safe) -----
try_cpuinfo() {
  [ -r "$CPUINFO" ] || return 1

  # Output "socket core cpu" per processor block.
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

    function flush() {
      if (cpu == "") return
      if (socket == "") socket = "0"
      if (coreid == "") coreid = cpu
      printf "%d %d %d\n", socket+0, coreid+0, cpu+0
    }

    BEGIN { cpu=""; socket=""; coreid="" }

    /^[ \t]*$/ {
      flush()
      cpu=""; socket=""; coreid=""
      next
    }

    {
      pos = index($0, ":")
      if (pos <= 0) next

      key = trim(substr($0, 1, pos-1))
      val = trim(substr($0, pos+1))

      if (key == "processor" && val ~ /^[0-9]+$/) cpu = val
      else if ((key == "physical id" || key == "package_id" || key == "socket" || key == "socket id") && val ~ /^[0-9]+$/) socket = val
      else if ((key == "core id" || key == "core_id" || key == "core") && val ~ /^[0-9]+$/) coreid = val
    }

    END { flush() }
  ' "$CPUINFO" | sort -n -k1,1 -k2,2 -k3,3 > "$tmp.proc.sorted"

  [ -s "$tmp.proc.sorted" ] || return 1

  awk '
    {
      socket=$1; core=$2; cpu=$3
      key=socket ":" core
      tidx[key]++
      thread=tidx[key]-1
      printf "%d %d %d %d\n", socket, core, thread, cpu
    }
  ' "$tmp.proc.sorted" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  cat "$tmp.out" | emit_json_from_lines
  return 0
}

# ----- 4) dense fallback from /proc/cpuinfo counts -----
# Cores -> 0..(cores-1), extra threads -> cores..(threads-1) where "threads" = total logical CPUs (siblings)
try_dense_fallback() {
  [ -r "$CPUINFO" ] || return 1

  # processors = count of "processor : N"
  processors=$(awk -F':' '
    $1 ~ /^[ \t]*processor[ \t]*$/ && $2 ~ /^[ \t]*[0-9]+[ \t]*$/ { c++ }
    END { print (c+0) }
  ' "$CPUINFO" 2>/dev/null || echo 0)

  # cores per socket (cpu cores) and threads per socket (siblings) from first occurrence
  cores=$(awk -F':' '
    $1 ~ /^[ \t]*cpu cores[ \t]*$/ && $2 ~ /^[ \t]*[0-9]+[ \t]*$/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }
  ' "$CPUINFO" 2>/dev/null || echo "")
  siblings=$(awk -F':' '
    $1 ~ /^[ \t]*siblings[ \t]*$/ && $2 ~ /^[ \t]*[0-9]+[ \t]*$/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }
  ' "$CPUINFO" 2>/dev/null || echo "")

  case "$processors" in (*[!0-9]*|'') processors=0;; esac
  case "$cores"      in (*[!0-9]*|'') cores=0;; esac
  case "$siblings"   in (*[!0-9]*|'') siblings=0;; esac

  if [ "$processors" -le 0 ] && [ "$cores" -le 0 ] && [ "$siblings" -le 0 ]; then
    return 1
  fi

  # If siblings missing, use processors; if still missing, use cores.
  if [ "$siblings" -le 0 ]; then
    if [ "$processors" -gt 0 ]; then siblings=$processors; fi
  fi
  if [ "$cores" -le 0 ]; then
    if [ "$siblings" -gt 0 ]; then cores=$siblings; fi
  fi

  if [ "$cores" -gt "$siblings" ]; then cores=$siblings; fi
  if [ "$cores" -le 0 ] || [ "$siblings" -le 0 ]; then
    return 1
  fi

  : > "$tmp.dense"
  i=0
  while [ "$i" -lt "$cores" ]; do
    # socket=0, core=i, thread=0, cpu=i
    printf "0 %d 0 %d\n" "$i" "$i" >> "$tmp.dense"
    i=$((i+1))
  done

  if [ "$siblings" -gt "$cores" ]; then
    cpu=$cores
    extra=0
    while [ "$cpu" -lt "$siblings" ]; do
      core=$((extra % cores))
      thr=$((1 + (extra / cores)))
      printf "0 %d %d %d\n" "$core" "$thr" "$cpu" >> "$tmp.dense"
      cpu=$((cpu+1))
      extra=$((extra+1))
    done
  fi

  cat "$tmp.dense" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  cat "$tmp.out" | emit_json_from_lines
  return 0
}

# ----- Main -----
if try_sysfs; then exit 1; fi
if try_lscpu; then exit 2; fi
if try_cpuinfo; then exit 3; fi
if try_dense_fallback; then exit 4; fi

# Nothing worked -> still return valid JSON
echo "[]"
exit 0
