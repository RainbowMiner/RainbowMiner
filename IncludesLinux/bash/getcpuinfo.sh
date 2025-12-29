#!/bin/sh
# getcpuinfo_raw.sh - POSIX sh CPU info exporter (JSON)
# Best effort sources: lscpu (ONLY if it actually works) -> sysfs -> /proc/cpuinfo (if readable) -> getconf
# stdout: JSON only
# Includes Name/Manufacturer guesses plus ArmParts for armdb.json mapping.

set -eu
export LC_ALL=C

SYSCPU="/sys/devices/system/cpu"
CPUINFO="/proc/cpuinfo"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---- choose writable temp base (TMPDIR -> /tmp -> .), suppress redirect errors ----
choose_tmpdir() {
  pid="$$"
  for d in "${TMPDIR:-}" "/tmp" "."; do
    [ -n "$d" ] || continue
    [ -d "$d" ] || continue
    testfile="$d/.cpu_raw_test.$pid"
    if ( : > "$testfile" ) 2>/dev/null; then
      rm -f "$testfile" 2>/dev/null || true
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

TMPBASE="$(choose_tmpdir 2>/dev/null || printf '%s\n' ".")"
tmp="$TMPBASE/cpu_raw.$$"
cleanup() { rm -f "$tmp" "$tmp".* 2>/dev/null || true; }
trap 'cleanup' EXIT INT HUP TERM

# ---- lscpu cache (treat lscpu as available only if it RUNS successfully) ----
LSCPU_TRIED=0
LSCPU_OK=0
LSCPU_OUT=""

init_lscpu() {
  if [ "$LSCPU_TRIED" -eq 1 ]; then
    [ "$LSCPU_OK" -eq 1 ] && return 0 || return 1
  fi
  LSCPU_TRIED=1

  if command -v lscpu >/dev/null 2>&1; then
    out="$(lscpu 2>/dev/null)"; rc=$?
    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
      LSCPU_OK=1
      LSCPU_OUT="$out"
      return 0
    fi
  fi

  LSCPU_OK=0
  LSCPU_OUT=""
  return 1
}

# ---- minimal JSON string escape ----
json_escape() {
  echo "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/\t/\\t/g' \
    -e 's/\r/\\r/g' \
    -e 's/\n/\\n/g'
}

# ---- expand CPU set like 0-3,8,10-11 to count ----
count_cpuset() {
  awk '
    function emit(a,b){ for(i=a;i<=b;i++) c++ }
    {
      gsub(/,/," ")
      n=split($0,toks," ")
      for(i=1;i<=n;i++){
        if(toks[i] ~ /^[0-9]+-[0-9]+$/){ split(toks[i],r,"-"); emit(r[1]+0,r[2]+0) }
        else if(toks[i] ~ /^[0-9]+$/){ c++ }
      }
    }
    END{ print (c+0) }
  '
}

# ---- sysfs: threads count ----
sys_threads() {
  if [ -r "$SYSCPU/online" ]; then
    cat "$SYSCPU/online" 2>/dev/null | count_cpuset
    return
  fi
  if [ -r "$SYSCPU/possible" ]; then
    cat "$SYSCPU/possible" 2>/dev/null | count_cpuset
    return
  fi
  ls "$SYSCPU"/cpu[0-9]* 2>/dev/null | awk 'END{print NR+0}'
}

# ---- sysfs: max MHz ----
sys_max_mhz() {
  v=""
  if [ -r "$SYSCPU/cpu0/cpufreq/cpuinfo_max_freq" ]; then
    v=$(cat "$SYSCPU/cpu0/cpufreq/cpuinfo_max_freq" 2>/dev/null || true)
  elif [ -r "$SYSCPU/cpu0/cpufreq/scaling_max_freq" ]; then
    v=$(cat "$SYSCPU/cpu0/cpufreq/scaling_max_freq" 2>/dev/null || true)
  fi
  v=$(echo "${v:-}" | awk 'NR==1{print; exit}')
  case "$v" in (''|*[!0-9]*) echo 0;; (*) echo $((v/1000));; esac
}

# ---- sysfs: L3 KB (best effort) ----
sys_l3_kb() {
  base="$SYSCPU/cpu0/cache"
  [ -d "$base" ] || { echo 0; return; }
  for idx in "$base"/index*; do
    [ -d "$idx" ] || continue
    lvl=$(cat "$idx/level" 2>/dev/null | awk 'NR==1{print; exit}')
    [ "$lvl" = "3" ] || continue
    sz=$(cat "$idx/size" 2>/dev/null | awk 'NR==1{print; exit}')
    case "$sz" in
      *K|*k) echo "$sz" | tr -d 'Kk' | awk '{print $1+0}'; return ;;
      *M|*m) n=$(echo "$sz" | tr -d 'Mm' | awk '{print $1+0}'); echo $((n*1024)); return ;;
    esac
  done
  echo 0
}

# ---- uname architecture ----
arch="$(uname -m 2>/dev/null || echo "")"

# ---- lscpu get key (from cached output) ----
lscpu_get() {
  key="$1"
  init_lscpu >/dev/null 2>&1 || return 1
  printf '%s\n' "$LSCPU_OUT" | awk -F: -v k="$key" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    tolower(trim($1))==tolower(k) { print trim($2); exit }
  ' 2>/dev/null || true
}

# ---- /proc/cpuinfo simple key read (first match) ----
cpuinfo_get_first() {
  key="$1"
  [ -r "$CPUINFO" ] || return 1
  awk -F: -v k="$key" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    tolower(trim($1))==tolower(k) { print trim($2); exit }
  ' "$CPUINFO" 2>/dev/null || true
}

# ---- IsARM heuristic ----
is_arm=0
case "$arch" in
  arm*|aarch64*) is_arm=1 ;;
esac
if [ "$is_arm" -eq 0 ] && [ -r "$CPUINFO" ]; then
  if awk -F: 'tolower($1) ~ /cpu implementer/ {found=1} END{exit(found?0:1)}' "$CPUINFO" 2>/dev/null; then
    is_arm=1
  fi
fi

# ---- Name guess ----
Name=""
if init_lscpu >/dev/null 2>&1; then
  Name="$(lscpu_get "Model name" || echo "")"
  [ -n "$Name" ] || Name="$(lscpu_get "Model" || echo "")"

  if [ -n "$Name" ]; then
    # trim leading/trailing spaces (POSIX)
    Name="$(printf '%s' "$Name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    case "$Name" in
      # only digits
      ""|*[!0-9]*)
        : ;;  # not "only digits" (or empty) -> keep checking below
      *)
        Name=""
        ;;
    esac

    if [ -n "$Name" ]; then
      case "$Name" in
        0x*|0X*)
          # ensure everything after 0x is hex and at least one digit exists
          rest=${Name#0x}; rest=${rest#0X}
          case "$rest" in
            ""|*[!0-9a-fA-F]*)
              : ;;     # not pure hex -> keep
            *)
              Name=""  # pure 0x[hex]+ -> discard
              ;;
          esac
          ;;
      esac
    fi
  fi
fi

# Some environments provide multiple model names (big.LITTLE) – keep first as Name guess
if [ -z "$Name" ] && [ -r "$CPUINFO" ]; then
  Name="$(cpuinfo_get_first "model name" || echo "")"
  [ -n "$Name" ] || Name="$(cpuinfo_get_first "Processor" || echo "")"
  [ -n "$Name" ] || Name="$(cpuinfo_get_first "Hardware" || echo "")"
fi

if [ -z "$Name" ] && [ -r /sys/devices/virtual/dmi/id/product_name ]; then
  Name="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null | awk 'NR==1{print; exit}')"
fi

[ -n "$Name" ] || Name="Unknown"

# ---- Manufacturer guess ----
Manufacturer=""
if init_lscpu >/dev/null 2>&1; then
  Manufacturer="$(lscpu_get "Vendor ID" || echo "")"
  [ -n "$Manufacturer" ] || Manufacturer="$(lscpu_get "Vendor" || echo "")"
fi

# cpuinfo vendor_id (x86)
if [ -z "$Manufacturer" ] && [ -r "$CPUINFO" ]; then
  Manufacturer="$(cpuinfo_get_first "vendor_id" || echo "")"
fi

# DMI sys vendor if readable
if [ -z "$Manufacturer" ] && [ -r /sys/devices/virtual/dmi/id/sys_vendor ]; then
  Manufacturer="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null | awk 'NR==1{print; exit}')"
fi

# ARM fallback label
if [ -z "$Manufacturer" ] && [ "$is_arm" -eq 1 ]; then
  Manufacturer="ARM"
fi
[ -n "$Manufacturer" ] || Manufacturer="Unknown"

# ---- features map ----
features_json() {
  if init_lscpu >/dev/null 2>&1; then
    printf '%s\n' "$LSCPU_OUT" | awk -F: '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      tolower(trim($1)) ~ /^(flags|features)$/ {
        v=trim($2); if(v!=""){ print v; exit }
      }
    ' 2>/dev/null | awk '
      BEGIN{ printf "{"; first=1 }
      {
        n=split($0,a,/ +/)
        for(i=1;i<=n;i++){
          f=a[i]
          gsub(/[^a-z0-9_]/,"",f)
          if(f!=""){
            if(!first) printf ","
            first=0
            printf "\"%s\":true", f
          }
        }
      }
      END{ printf "}" }
    ' 2>/dev/null && return
  fi

  if [ -r "$CPUINFO" ]; then
    awk -F: '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      tolower(trim($1))=="features" || tolower(trim($1))=="flags" {
        v=trim($2); if(v!=""){ print v; exit }
      }
    ' "$CPUINFO" 2>/dev/null | awk '
      BEGIN{ printf "{"; first=1 }
      {
        n=split($0,a,/ +/)
        for(i=1;i<=n;i++){
          f=a[i]
          gsub(/[^a-z0-9_]/,"",f)
          if(f!=""){
            if(!first) printf ","
            first=0
            printf "\"%s\":true", f
          }
        }
      }
      END{ printf "}" }
    ' 2>/dev/null && return
  fi

  echo "{}"
}

# ---- ARM parts list from /proc/cpuinfo (unique tuples + count) ----
arm_parts_from_cpuinfo() {
  [ -r "$CPUINFO" ] || { echo "[]"; return; }

  awk -F: '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function flush(){
      if(impl=="" && part=="" && var=="" && rev=="") return
      key=impl "|" part "|" var "|" rev
      cnt[key]++
      implv[key]=impl; partv[key]=part; varv[key]=var; revv[key]=rev
    }
    BEGIN{ impl=""; part=""; var=""; rev="" }
    /^[ \t]*$/ { flush(); impl=""; part=""; var=""; rev=""; next }
    {
      k=trim($1); v=trim($2)
      lk=tolower(k)
      if(lk=="cpu implementer") impl=v
      else if(lk=="cpu part") part=v
      else if(lk=="cpu variant") var=v
      else if(lk=="cpu revision") rev=v
    }
    END{
      flush()
      first=1
      printf "["
      for(k in cnt){
        if(!first) printf ","
        first=0
        printf "{"
        printf "\"implementer\":\"%s\",", implv[k]
        printf "\"part\":\"%s\",", partv[k]
        printf "\"variant\":\"%s\",", varv[k]
        rv=revv[k]
        if(rv ~ /^[0-9]+$/) printf "\"revision\":%d,", rv+0
        else printf "\"revision\":0,"
        printf "\"count\":%d", cnt[k]+0
        printf "}"
      }
      printf "]"
    }
  ' "$CPUINFO" 2>/dev/null
}

# ---- multi model names list from lscpu (unique, preserve order) ----
lscpu_models_json() {
  init_lscpu >/dev/null 2>&1 || { echo "[]"; return; }
  printf '%s\n' "$LSCPU_OUT" | awk -F: '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    tolower(trim($1))=="model name" {
      v=trim($2)
      if(v!=""){ a[++n]=v }
    }
    END{
      for(i=1;i<=n;i++){
        if(!(a[i] in seen)){ seen[a[i]]=1; u[++m]=a[i] }
      }
      printf "["
      for(i=1;i<=m;i++){
        gsub(/\\/,"\\\\",u[i]); gsub(/"/,"\\\"",u[i])
        if(i>1) printf ","
        printf "\"%s\"", u[i]
      }
      printf "]"
    }
  ' 2>/dev/null
}

Threads="$(sys_threads)"
case "$Threads" in (''|*[!0-9]*) Threads=0;; esac
Cores="$Threads"
PhysicalCPUs=1

# prefer lscpu threads if available (only if lscpu truly works)
if init_lscpu >/dev/null 2>&1; then
  t="$(lscpu_get "CPU(s)" || echo "")"
  case "$t" in (*[!0-9]*|'') : ;; (*) Threads="$t"; Cores="$t";; esac
fi

MaxClockMHz="$(sys_max_mhz)"
L3CacheKB="$(sys_l3_kb)"
Features="$(features_json)"
Hardware="$(cpuinfo_get_first "Hardware" || echo "")"
Models="$(lscpu_models_json)"
ArmParts="$(arm_parts_from_cpuinfo)"

# last fallback threads from getconf
if [ "$Threads" -le 0 ]; then
  Threads="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
  case "$Threads" in (*[!0-9]*|'') Threads=0;; esac
  [ "$Threads" -gt 0 ] && Cores="$Threads"
fi

# emit JSON
jn="$(json_escape "$Name")"
jm="$(json_escape "$Manufacturer")"
ja="$(json_escape "$arch")"
jh="$(json_escape "$Hardware")"

printf '{'
printf '"Name":"%s",' "$jn"
printf '"Manufacturer":"%s",' "$jm"
printf '"Architecture":"%s",' "$ja"
printf '"IsARM":%s,' "$( [ "$is_arm" -eq 1 ] && echo true || echo false )"
printf '"Threads":%d,' "$Threads"
printf '"Cores":%d,' "$Cores"
printf '"PhysicalCPUs":%d,' "$PhysicalCPUs"
printf '"MaxClockMHz":%d,' "$MaxClockMHz"
printf '"L3CacheKB":%d,' "$L3CacheKB"
printf '"Hardware":"%s",' "$jh"
printf '"ModelNames":%s,' "$Models"
printf '"ArmParts":%s,' "$ArmParts"
printf '"Features":%s' "$Features"
printf '}\n'
