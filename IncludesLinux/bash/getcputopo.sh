#!/bin/sh
# getcputopo.sh - POSIX sh CPU topology exporter (JSON)
# Tries (in order):
#   1) sysfs: /sys/devices/system/cpu (best; uses thread_siblings_list)
#   2) lscpu: lscpu -p=CPU,SOCKET,CORE (if it runs successfully)
#   3) /proc/cpuinfo (best effort: physical/core ids if present)
#   4) synthetic fallback (robust): enumerate CPUs from sysfs present/possible/online, else /proc/stat, else /proc/cpuinfo
#
# Output: JSON array of objects sorted by socket,core,thread,cpu:
#   {"cpu":N,"socket":S,"core":C,"thread":T,"online":true|false,"source":"sysfs|lscpu|cpuinfo|synthetic"}

set -eu
export LC_ALL=C

SYSCPU="/sys/devices/system/cpu"
CPUINFO="/proc/cpuinfo"
PROCSTAT="/proc/stat"

choose_tmpdir() {
  pid="$$"
  # Note: POSIX sh cannot safely preserve TMPDIR with spaces without extra complexity.
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

# ---------------- CPU range/list helpers ----------------
# Expand a cpulist like "0-3,8,10-11" to one CPU id per line, sorted unique.
expand_cpulist() {
  # stdin: one line with list
  awk '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function emit_range(lo,hi,  i){ for(i=lo;i<=hi;i++) print i }
    {
      line=trim($0)
      if (line=="") exit 1
      n = split(line, a, /,/)
      for (i=1;i<=n;i++) {
        part=a[i]
        gsub(/^[ \t]+|[ \t]+$/, "", part)
        if (part ~ /^[0-9]+-[0-9]+$/) {
          split(part, r, /-/); lo=r[1]+0; hi=r[2]+0
          if (hi>=lo) emit_range(lo,hi)
        } else if (part ~ /^[0-9]+$/) {
          print part+0
        }
      }
    }
  ' 2>/dev/null | sort -n | awk '{ if (!seen[$1]++) print $1 }'
}

# Try to enumerate CPUs via sysfs "present/possible/online" (best effort),
# else /proc/stat cpuN lines, else /proc/cpuinfo processor fields.
# Output: one cpu id per line (sorted unique). Return 0 if any cpu found.
enumerate_cpus() {
  # 1) sysfs present
  if [ -r "$SYSCPU/present" ]; then
    if expand_cpulist < "$SYSCPU/present" > "$tmp.cpulist" 2>/dev/null && [ -s "$tmp.cpulist" ]; then
      cat "$tmp.cpulist"
      return 0
    fi
  fi

  # 2) sysfs possible
  if [ -r "$SYSCPU/possible" ]; then
    if expand_cpulist < "$SYSCPU/possible" > "$tmp.cpulist" 2>/dev/null && [ -s "$tmp.cpulist" ]; then
      cat "$tmp.cpulist"
      return 0
    fi
  fi

  # 3) sysfs online (may be restricted, but sometimes readable even when topology isn't)
  if [ -r "$SYSCPU/online" ]; then
    if expand_cpulist < "$SYSCPU/online" > "$tmp.cpulist" 2>/dev/null && [ -s "$tmp.cpulist" ]; then
      cat "$tmp.cpulist"
      return 0
    fi
  fi

  # 4) /proc/stat cpuN lines
  if [ -r "$PROCSTAT" ]; then
    awk '
      $1 ~ /^cpu[0-9]+$/ {
        sub(/^cpu/,"",$1)
        if ($1 ~ /^[0-9]+$/) print $1+0
      }
    ' "$PROCSTAT" 2>/dev/null | sort -n | awk '{ if (!seen[$1]++) print $1 }' > "$tmp.cpulist" || true
    if [ -s "$tmp.cpulist" ]; then
      cat "$tmp.cpulist"
      return 0
    fi
  fi

  # 5) /proc/cpuinfo processor fields
  if [ -r "$CPUINFO" ]; then
    awk -F':' '
      $1 ~ /^[ \t]*processor[ \t]*$/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        if ($2 ~ /^[0-9]+$/) print $2+0
      }
    ' "$CPUINFO" 2>/dev/null | sort -n | awk '{ if (!seen[$1]++) print $1 }' > "$tmp.cpulist" || true
    if [ -s "$tmp.cpulist" ]; then
      cat "$tmp.cpulist"
      return 0
    fi
  fi

  return 1
}

# ---------------- Online detection ----------------
# Build online cpu set from /sys/devices/system/cpu/online.
# Writes one CPU number per line to $tmp.online.set if possible.
# Returns 0 if it could build the set, else 1.
build_online_set() {
  : > "$tmp.online.set" 2>/dev/null || true
  [ -r "$SYSCPU/online" ] || return 1
  if expand_cpulist < "$SYSCPU/online" > "$tmp.online.set" 2>/dev/null && [ -s "$tmp.online.set" ]; then
    return 0
  fi
  return 1
}

ONLINESET_OK=0
if build_online_set; then ONLINESET_OK=1; else ONLINESET_OK=0; fi

# Append online column (0/1)
# stdin:  "socket core thread cpu"
# stdout: "socket core thread cpu online"
# Strategy:
#   - Prefer global /sys/devices/system/cpu/online list when readable
#   - Else fall back to per-cpu online file:
#       * if readable and != "1" => offline
#       * if missing/unreadable => assume online (Linux convention)
add_online_column() {
  awk -v ONLINESET_OK="$ONLINESET_OK" -v ONLINESET_FILE="$tmp.online.set" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

    function load_onlineset(   v) {
      if (ONLINESET_OK+0 != 1) return 0
      while ((getline v < ONLINESET_FILE) > 0) {
        v = trim(v)
        if (v ~ /^[0-9]+$/) on[v+0]=1
      }
      close(ONLINESET_FILE)
      return 1
    }

    BEGIN { have_set = load_onlineset() }

    {
      socket=$1+0; core=$2+0; thread=$3+0; cpu=$4+0;
      online=1

      if (have_set) {
        online = (cpu in on) ? 1 : 0
      } else {
        path=sprintf("/sys/devices/system/cpu/cpu%d/online", cpu)
        if ((getline v < path) > 0) {
          v = trim(v)
          if (v != "1") online=0
        }
        close(path)
      }

      printf "%d %d %d %d %d\n", socket, core, thread, cpu, online
    }
  '
}

# JSON emitter from 5-column lines
# stdin: sorted "socket core thread cpu online(0|1)"
emit_json_from_lines() {
  SRC="${1:-unknown}"
  awk -v SRC="$SRC" '
    BEGIN { first=1; print "[" }
    {
      online = ($5+0==1) ? "true" : "false";
      if (!first) print ",";
      first=0;
      printf "  {\"cpu\":%d,\"socket\":%d,\"core\":%d,\"thread\":%d,\"online\":%s,\"source\":\"%s\"}",
        $4, $1, $2, $3, online, SRC
    }
    END { print ""; print "]" }
  '
}

# ---------------- 1) sysfs ----------------
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
    printf '%s|%s|%s\n' "$cpu" "$socket" "$siblings" >> "$tmp.sys.raw"
  done

  # Expand siblings groups and emit: socket core(mincpu) thread cpu
  awk -F'|' '
    function add_exist(c){ exist[c]=1 }

    function expand(list,   n,i,part,lo,hi,j,outn,k,m,t) {
      delete out
      n = split(list, parts, /,/)
      outn = 0
      for (i=1;i<=n;i++) {
        part = parts[i]
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

      for (i=1;i<=m;i++) for (j=i+1;j<=m;j++) if (arr[j] < arr[i]) { t=arr[i]; arr[i]=arr[j]; arr[j]=t }

      delete sorted
      sc=0
      for (i=1;i<=m;i++) sorted[++sc]=arr[i]
      return sc
    }

    function join_sorted(sc,   i,s) {
      s=""
      for (i=1;i<=sc;i++) { if (s!="") s=s ","; s=s sorted[i] }
      return s
    }

    {
      cpu=$1+0; socket=$2+0; sib=$3
      add_exist(cpu)
      sc = expand(sib)
      canon = join_sorted(sc)
      key = socket ":" canon
      if (!(key in group_canon)) { group_canon[key]=canon; group_socket[key]=socket }
    }

    END{
      for (key in group_canon) {
        socket = group_socket[key]+0
        canon = group_canon[key]
        n = split(canon, a, /,/)

        core = -1
        for (i=1;i<=n;i++) { c = a[i]+0; if (exist[c]) { core = c; break } }
        if (core < 0) continue

        tidx=0
        for (i=1;i<=n;i++) {
          c = a[i]+0
          if (exist[c]) { printf "%d %d %d %d\n", socket, core, tidx, c; tidx++ }
        }
      }
    }
  ' "$tmp.sys.raw" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  emit_json_from_lines "sysfs" < "$tmp.out"
  return 0
}

# ---------------- 2) lscpu ----------------
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
  init_lscpu_full >/dev/null 2>&1 || { echo 0; return; }

  printf '%s\n' "$LSCPU_FULL_OUT" | awk -F: '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    tolower(trim($1))=="thread(s) per core" {
      v=trim($2)
      if (v ~ /^[0-9]+$/) { print v+0; exit }
    }
  ' 2>/dev/null | awk 'NR==1{print; exit}'
}

try_lscpu() {
  init_lscpu_p >/dev/null 2>&1 || return 1

  tpc="$(lscpu_threads_per_core 2>/dev/null || echo 0)"
  case "$tpc" in (*[!0-9]*|'') tpc=0;; esac

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
    awk '{ socket=$1; cpu=$3; printf "%d %d %d\n", socket, cpu, cpu }' "$tmp.ls.sorted" \
      | sort -n -k1,1 -k2,2 -k3,3 > "$tmp.ls.fixed"
    mv "$tmp.ls.fixed" "$tmp.ls.sorted"
  fi

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
  emit_json_from_lines "lscpu" < "$tmp.out"
  return 0
}

# ---------------- 3) /proc/cpuinfo ----------------
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

    /^[ \t]*$/ { flush(); cpu=""; socket=""; coreid=""; next }

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
  emit_json_from_lines "cpuinfo" < "$tmp.out"
  return 0
}

# ---------------- 4) synthetic fallback (robust) ----------------
# Goal: return something consistent for affinity even when topology is unavailable.
# Approach:
#   - enumerate CPU IDs as reliably as possible
#   - map each CPU to its own core: socket=0 core=cpu thread=0
# This avoids inventing SMT/core layouts (which is dangerous on servers like EPYC).
try_synthetic_fallback() {
  enumerate_cpus > "$tmp.syn.cpus" 2>/dev/null || return 1
  [ -s "$tmp.syn.cpus" ] || return 1

  # Build lines: socket core thread cpu
  awk '
    $1 ~ /^[0-9]+$/ {
      cpu=$1+0
      printf "0 %d 0 %d\n", cpu, cpu
    }
  ' "$tmp.syn.cpus" \
    | add_online_column \
    | sort -n -k1,1 -k2,2 -k3,3 -k4,4 > "$tmp.out"

  [ -s "$tmp.out" ] || return 1
  emit_json_from_lines "synthetic" < "$tmp.out"
  return 0
}

# ---------------- Main ----------------
if try_sysfs; then exit 0; fi
if try_lscpu; then exit 0; fi
if try_cpuinfo; then exit 0; fi
if try_synthetic_fallback; then exit 0; fi

# Nothing worked -> still return valid JSON
echo "[]"
exit 0
