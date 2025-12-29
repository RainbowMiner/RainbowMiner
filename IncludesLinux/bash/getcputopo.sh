#!/bin/sh
# getcputopo.sh - POSIX sh CPU topology exporter (JSON)
# Tries (in order):
#   1) sysfs: /sys/devices/system/cpu (best; uses thread_siblings_list)
#   2) lscpu: lscpu -p=CPU,SOCKET,CORE (if it runs successfully)
#   3) /proc/cpuinfo (best effort: physical/core ids if present)
#   4) dense fallback from /proc/cpuinfo counts (0..cores-1, cores..threads-1)
#
# Output: JSON array of objects sorted by socket,core,thread,cpu:
#   {"cpu":N,"socket":S,"core":C,"thread":T,"online":true|false}
#
# Notes:
# - "online" is derived like Linux sysfs: if cpuN/online missing/unreadable => online=true
# - All non-JSON noise is suppressed; stdout should always be valid JSON.

set -eu
export LC_ALL=C

SYSCPU="/sys/devices/system/cpu"
CPUINFO="/proc/cpuinfo"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

choose_tmpdir() {
  pid="$$"
  for d in "${TMPDIR:-}" "/tmp" "."; do
    [ -n "$d" ] || continue
    [ -d "$d" ] || continue
    testfile="$d/.cpu_topo_test.$pid"
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
# IMPORTANT FIX:
# Do NOT trust core_id on some ARM/Android kernels (may repeat per cluster).
# Instead define the core by thread_siblings_list group, and set core = min(cpu in group).
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
    socket="0"
    siblings=""

    if [ -r "$topo/physical_package_id" ]; then
      socket=$(cat "$topo/physical_package_id" 2>/dev/null || echo "0")
    fi
    if [ -r "$topo/thread_siblings_list" ]; then
      siblings=$(cat "$topo/thread_siblings_list" 2>/dev/null || true)
    fi
    [ -n "$siblings" ] || siblings="$cpu"

    case "$socket" in (*[!0-9]*|'') socket="0";; esac

    # record: cpu|socket|siblingslist
    printf '%s|%s|%s\n' "$cpu" "$socket" "$siblings" >> "$tmp.sys.raw"
  done

  # Expand siblings groups and emit: socket core(mincpu) thread cpu
  awk -F'|' '
    function add_exist(c){ exist[c]=1 }

    # expand "0-3,8,10-11" to sorted unique array sorted[1..sc]
    function expand(list,   a,n,i,part,lo,hi,j,outn,k,m,t) {
      n = split(list, a, /,/)
      outn = 0
      for (i=1;i<=n;i++) {
        part = a[i]
        gsub(/^[ \t]+|[ \t]+$/, "", part)
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
      delete arr
      for (k in seen) arr[++m]=k+0

      # sort arr ascending (small m)
      for (i=1;i<=m;i++) for (j=i+1;j<=m;j++) if (arr[j] < arr[i]) { t=arr[i]; arr[i]=arr[j]; arr[j]=t }

      delete sorted
      sc=0
      for (i=1;i<=m;i++) sorted[++sc]=arr[i]
      return sc
    }

    # join sorted array into canonical key string
    function join_sorted(sc,   i,s) {
      s=""
      for (i=1;i<=sc;i++) {
        if (s!="") s=s ","
        s=s sorted[i]
      }
      return s
    }

    {
      cpu=$1+0; socket=$2+0; sib=$3
      add_exist(cpu)

      # Build a canonical group key: socket + canonical siblings cpu list
      delete sorted
      sc = expand(sib)
      canon = join_sorted(sc)
      key = socket ":" canon

      if (!(key in group_canon)) {
        group_canon[key]=canon
        group_socket[key]=socket
      }
    }

    END{
      # For each group, emit socket core(mincpu) thread cpu, filtering to CPUs that exist
      for (key in group_canon) {
        socket = group_socket[key]+0
        canon = group_canon[key]

        # rebuild sorted[] from canon (already sorted)
        n = split(canon, a, /,/)
        # find min existing cpu to define core id
        core = -1
        for (i=1;i<=n;i++) {
          c = a[i]+0
          if (exist[c]) { core = c; break }
        }
        if (core < 0) continue

        tidx=0
        for (i=1;i<=n;i++) {
          c = a[i]+0
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

# ----- lscpu runtime-validated cache -----
LSCPU_TRIED=0
LSCPU_OK=0
LSCPU_P_OUT=""

init_lscpu_p() {
  if [ "$LSCPU_TRIED" -eq 1 ]; then
    [ "$LSCPU_OK" -eq 1 ] && return 0 || return 1
  fi
  LSCPU_TRIED=1

  command -v lscpu >/dev/null 2>&1 || { LSCPU_OK=0; return 1; }

  out="$(lscpu -p=CPU,SOCKET,CORE 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    LSCPU_OK=1
    LSCPU_P_OUT="$out"
    return 0
  fi

  LSCPU_OK=0
  LSCPU_P_OUT=""
  return 1
}

LSCPU_FULL_TRIED=0
LSCPU_FULL_OK=0
LSCPU_FULL_OUT=""

init_lscpu_full() {
  if [ "$LSCPU_FULL_TRIED" -eq 1 ]; then
    [ "$LSCPU_FULL_OK" -eq 1 ] && return 0 || return 1
  fi
  LSCPU_FULL_TRIED=1

  command -v lscpu >/dev/null 2>&1 || { LSCPU_FULL_OK=0; return 1; }

  out="$(lscpu 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    LSCPU_FULL_OK=1
    LSCPU_FULL_OUT="$out"
    return 0
  fi

  LSCPU_FULL_OK=0
  LSCPU_FULL_OUT=""
  return 1
}

lscpu_threads_per_core() {
  # default unknown -> 0
  init_lscpu_full >/dev/null 2>&1 || { echo 0; return; }

  printf '%s\n' "$LSCPU_FULL_OUT" | awk -F: '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    tolower(trim($1))=="thread(s) per core" {
      v=trim($2)
      if (v ~ /^[0-9]+$/) { print v+0; exit }
    }
    END { }
  ' 2>/dev/null | awk 'NR==1{print; exit}'
}

# ----- 2) lscpu -----
try_lscpu() {
  init_lscpu_p >/dev/null 2>&1 || return 1

  tpc="$(lscpu_threads_per_core 2>/dev/null || echo 0)"
  case "$tpc" in (*[!0-9]*|'') tpc=0;; esac

  # Parse lscpu -p into socket core cpu
  printf '%s\n' "$LSCPU_P_OUT" | awk -F',' '
    $0 ~ /^#/ { next }
    $1 ~ /^[0-9]+$/ {
      cpu=$1+0
      socket = ($2 ~ /^[0-9]+$/) ? $2+0 : 0
      core   = ($3 ~ /^[0-9]+$/) ? $3+0 : cpu
      print socket, core, cpu
    }
  ' | sort -n -k1,1 -k2,2 -k3,3 > "$tmp.ls.sorted"

  [ -s "$tmp.ls.sorted" ] || return 1

  # Detect collisions: if any (socket,core) has >1 cpu but ThreadsPerCore <= 1,
  # then CORE ids are unreliable (common on ARM clusters) -> force core=cpu.
  maxgrp=$(awk '
    { key=$1 ":" $2; c[key]++ }
    END{
      m=0
      for (k in c) if (c[k] > m) m=c[k]
      print m+0
    }
  ' "$tmp.ls.sorted")

  case "$maxgrp" in (*[!0-9]*|'') maxgrp=0;; esac

  if [ "$tpc" -le 1 ] && [ "$maxgrp" -gt 1 ]; then
    # No SMT expected, but grouping happened -> fix by making each cpu its own core
    awk '
      { socket=$1; cpu=$3; printf "%d %d %d\n", socket, cpu, cpu }
    ' "$tmp.ls.sorted" | sort -n -k1,1 -k2,2 -k3,3 > "$tmp.ls.fixed"
    mv "$tmp.ls.fixed" "$tmp.ls.sorted"
  fi

  # Now assign thread index within each (socket,core)
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
try_dense_fallback() {
  [ -r "$CPUINFO" ] || return 1

  processors=$(awk -F':' '
    $1 ~ /^[ \t]*processor[ \t]*$/ && $2 ~ /^[ \t]*[0-9]+[ \t]*$/ { c++ }
    END { print (c+0) }
  ' "$CPUINFO" 2>/dev/null || echo 0)

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

  if [ "$siblings" -le 0 ] && [ "$processors" -gt 0 ]; then siblings=$processors; fi
  if [ "$cores" -le 0 ] && [ "$siblings" -gt 0 ]; then cores=$siblings; fi
  if [ "$cores" -gt "$siblings" ]; then cores=$siblings; fi

  if [ "$cores" -le 0 ] || [ "$siblings" -le 0 ]; then
    return 1
  fi

  : > "$tmp.dense"
  i=0
  while [ "$i" -lt "$cores" ]; do
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
