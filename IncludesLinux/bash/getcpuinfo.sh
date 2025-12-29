#!/bin/sh
# getcpuinfo.sh - POSIX sh CPU info exporter (JSON, stdout only)
# Best effort sources: lscpu -> sysfs -> getconf
# Avoids /proc/cpuinfo (may be permission denied in jailed/shared systems)

set -eu
export LC_ALL=C

SYSCPU="/sys/devices/system/cpu"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# -------- JSON string escape (minimal, POSIX) --------
json_escape() {
  # Escapes \ and " and control newlines/tabs/carriage returns
  # shellcheck disable=SC2001
  echo "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/\t/\\t/g' \
    -e 's/\r/\\r/g' \
    -e 's/\n/\\n/g'
}

# -------- parse cpu list "0-3,8,10-11" -> count --------
count_cpuset() {
  # stdin: cpuset string
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

# -------- collect features into JSON map (best effort) --------
# Output: {"feat":true,...} (may be empty {})
features_json_from_lscpu() {
  # lscpu "Flags:" line (x86) or "Features:" (arm)
  # make keys lowercase, strip non [a-z0-9_]
  if have_cmd lscpu; then
    lscpu 2>/dev/null | awk -F: '
      BEGIN{ found=0 }
      tolower($1) ~ /^[ \t]*(flags|features)[ \t]*$/ {
        found=1
        val=$2
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        print val
        exit
      }
      END{ if(!found) exit 1 }
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
    ' 2>/dev/null && return 0
  fi
  echo "{}"
}

# -------- read first readable sysfs file --------
read_first() {
  # args: file1 file2 ...
  for p in "$@"; do
    if [ -r "$p" ]; then
      v=$(cat "$p" 2>/dev/null || true)
      [ -n "$v" ] || continue
      echo "$v" | awk 'NR==1{print; exit}'
      return 0
    fi
  done
  return 1
}

# -------- sysfs: manufacturer/vendor if exposed --------
sysfs_vendor() {
  # Some kernels expose vendor_id in sysfs under cpu0/uevent or in DMI (often restricted).
  # We keep it best-effort and conservative.
  u="$SYSCPU/cpu0/uevent"
  if [ -r "$u" ]; then
    # sometimes contains "OF_COMPATIBLE_0=..." not vendor. Still try.
    v=$(awk -F= 'tolower($1)=="vendor" || tolower($1)=="vendor_id" {print $2; exit}' "$u" 2>/dev/null || true)
    [ -n "$v" ] && echo "$v" && return 0
  fi
  return 1
}

# -------- sysfs: architecture --------
sysfs_arch() {
  # uname -m is usually allowed
  uname -m 2>/dev/null || echo ""
}

# -------- sysfs: max MHz --------
sysfs_max_mhz() {
  # cpufreq may be missing in VMs/containers
  p1="$SYSCPU/cpu0/cpufreq/cpuinfo_max_freq"
  p2="$SYSCPU/cpu0/cpufreq/scaling_max_freq"
  v=$(read_first "$p1" "$p2" || true)
  case "$v" in
    ''|*[!0-9]* ) echo 0;;
    * ) echo $((v/1000));;
  esac
}

# -------- sysfs: L3 cache size in KB (best effort) --------
sysfs_l3_kb() {
  # Look for cache/index*/level==3 then size like "8192K"
  base="$SYSCPU/cpu0/cache"
  [ -d "$base" ] || { echo 0; return; }
  for idx in "$base"/index*; do
    [ -d "$idx" ] || continue
    lvl=$(read_first "$idx/level" || true)
    [ "$lvl" = "3" ] || continue
    sz=$(read_first "$idx/size" || true)
    # size formats: "8192K" or "32M"
    case "$sz" in
      *K|*k)
        n=$(echo "$sz" | tr -d 'Kk' | awk '{print $1+0}')
        echo "$n"
        return
        ;;
      *M|*m)
        n=$(echo "$sz" | tr -d 'Mm' | awk '{print $1+0}')
        echo $((n*1024))
        return
        ;;
    esac
  done
  echo 0
}

# -------- sysfs: counts (threads, cores, sockets) --------
sysfs_counts() {
  # threads = online cpus count if available, else possible count, else dirs count
  threads=0
  cores=0
  sockets=0

  if [ -r "$SYSCPU/online" ]; then
    threads=$(cat "$SYSCPU/online" 2>/dev/null | count_cpuset)
  elif [ -r "$SYSCPU/possible" ]; then
    threads=$(cat "$SYSCPU/possible" 2>/dev/null | count_cpuset)
  else
    # fallback: count cpuN dirs
    threads=$(ls "$SYSCPU"/cpu[0-9]* 2>/dev/null | awk 'END{print NR+0}')
  fi

  # sockets/cores by topology ids if readable
  if [ -d "$SYSCPU" ]; then
    # Build sets via awk
    ls "$SYSCPU"/cpu[0-9]* 2>/dev/null | awk '
      function add(set, k){ if(!(k in set)){ set[k]=1; return 1 } return 0 }
      BEGIN{ s=0; c=0 }
      {
        # path ends with /cpuN
        cpu=$0
        pkg=cpu "/topology/physical_package_id"
        cid=cpu "/topology/core_id"
        pkgv=""; cidv=""
        if ((getline v < pkg) > 0) { pkgv=v+0 } close(pkg)
        if ((getline v2 < cid) > 0) { cidv=v2+0 } close(cid)

        # If either missing, skip that dimension
        if (pkgv != "") {
          if (!(pkgv in pkgs)) { pkgs[pkgv]=1; s++ }
        }
        if (pkgv != "" && cidv != "") {
          key=pkgv ":" cidv
          if (!(key in cores)) { cores[key]=1; c++ }
        }
      }
      END{
        # If no topology data, cores=threads, sockets=1
        if (s==0) s=1
        if (c==0) c=0
        printf "%d %d %d\n", s, c, 0
      }
    ' > /dev/null 2>&1 || true

    # Re-run with output capture (some awk can't write to /dev/null in restricted env; keep simple)
    out=$(ls "$SYSCPU"/cpu[0-9]* 2>/dev/null | awk '
      BEGIN{ s=0; c=0 }
      {
        cpu=$0
        pkg=cpu "/topology/physical_package_id"
        cid=cpu "/topology/core_id"
        pkgv=""; cidv=""
        if ((getline v < pkg) > 0) { pkgv=v+0 } close(pkg)
        if ((getline v2 < cid) > 0) { cidv=v2+0 } close(cid)
        if (pkgv != "") {
          if (!(pkgv in pkgs)) { pkgs[pkgv]=1; s++ }
        }
        if (pkgv != "" && cidv != "") {
          key=pkgv ":" cidv
          if (!(key in cores)) { cores[key]=1; c++ }
        }
      }
      END{
        if (s==0) s=1
        print s, c
      }
    ' 2>/dev/null || echo "1 0")

    sockets=$(echo "$out" | awk '{print $1+0}')
    cores=$(echo "$out" | awk '{print $2+0}')
  fi

  # If cores couldn't be computed, conservative fallback: cores = threads (no SMT knowledge)
  if [ "$cores" -le 0 ]; then cores=$threads; fi
  if [ "$sockets" -le 0 ]; then sockets=1; fi

  echo "$cores $threads $sockets"
}

# -------- lscpu parser (preferred) --------
lscpu_get() {
  key="$1"
  lscpu 2>/dev/null | awk -F: -v k="$key" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    {
      kk=trim($1)
      if (tolower(kk) == tolower(k)) {
        vv=trim($2)
        print vv
        exit
      }
    }
  ' 2>/dev/null || true
}

# -------- Main collection --------
Name=""
Manufacturer=""
Cores=0
Threads=0
PhysicalCPUs=1
L3CacheKB=0
MaxClockMHz=0
Architecture="$(sysfs_arch)"
Features="$(features_json_from_lscpu)"

if have_cmd lscpu; then
  # Name
  Name="$(lscpu_get "Model name")"
  [ -n "$Name" ] || Name="$(lscpu_get "Model")"

  # Vendor/Manufacturer
  Manufacturer="$(lscpu_get "Vendor ID")"
  [ -n "$Manufacturer" ] || Manufacturer="$(lscpu_get "Vendor")"

  # Counts
  Threads="$(lscpu_get "CPU(s)")"
  Cores="$(lscpu_get "Core(s) per socket")"
  Sockets="$(lscpu_get "Socket(s)")"

  # Normalize ints
  case "$Threads" in (*[!0-9]*|'') Threads=0;; esac
  case "$Cores"   in (*[!0-9]*|'') Cores=0;; esac
  case "$Sockets" in (*[!0-9]*|'') Sockets=0;; esac

  if [ "$Sockets" -gt 0 ] && [ "$Cores" -gt 0 ]; then
    PhysicalCPUs="$Sockets"
    Cores=$((Cores * Sockets))
  fi

  # Cache (prefer lscpu L3 cache)
  l3="$(lscpu_get "L3 cache")"
  # l3 like "16 MiB" or "8192K"
  if [ -n "$l3" ]; then
    # grab first number and unit
    num=$(echo "$l3" | awk '{print $1}')
    unit=$(echo "$l3" | awk '{print tolower($2)}')
    case "$num" in (*[!0-9.]*|'') num="";; esac
    if [ -n "$num" ]; then
      # handle MiB / KiB
      case "$unit" in
        mib|mb) L3CacheKB=$(awk -v n="$num" 'BEGIN{printf "%d", (n*1024)+0}');;
        kib|kb) L3CacheKB=$(awk -v n="$num" 'BEGIN{printf "%d", (n)+0}');;
        *) L3CacheKB=0;;
      esac
    fi
  fi

  # Max MHz (lscpu "CPU max MHz" sometimes)
  mx="$(lscpu_get "CPU max MHz")"
  case "$mx" in
    '' ) : ;;
    * ) MaxClockMHz=$(echo "$mx" | awk '{printf "%d", ($1+0)}');;
  esac
fi

# sysfs fallback for anything missing
if [ -z "$Name" ]; then
  # try DMI model if readable; often restricted
  if [ -r /sys/devices/virtual/dmi/id/product_name ]; then
    Name="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null | awk 'NR==1{print; exit}')"
  fi
fi

if [ -z "$Manufacturer" ]; then
  Manufacturer="$(sysfs_vendor || true)"
fi

if [ "$MaxClockMHz" -le 0 ]; then
  MaxClockMHz="$(sysfs_max_mhz)"
fi

if [ "$L3CacheKB" -le 0 ]; then
  L3CacheKB="$(sysfs_l3_kb)"
fi

if [ "$Threads" -le 0 ] || [ "$Cores" -le 0 ]; then
  if [ -d "$SYSCPU" ]; then
    set -- $(sysfs_counts)
    Cores="$1"
    Threads="$2"
    PhysicalCPUs="$3"
  fi
fi

# last fallback: getconf processors
if [ "$Threads" -le 0 ]; then
  Threads="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
  case "$Threads" in (*[!0-9]*|'') Threads=0;; esac
fi
if [ "$Threads" -gt 0 ] && [ "$Cores" -le 0 ]; then
  Cores="$Threads"
fi
if [ "$PhysicalCPUs" -le 0 ]; then PhysicalCPUs=1; fi
if [ -z "$Name" ]; then Name="Unknown"; fi
if [ -z "$Manufacturer" ]; then Manufacturer="Unknown"; fi

# Emit JSON (stdout only)
jn="$(json_escape "$Name")"
jm="$(json_escape "$Manufacturer")"
ja="$(json_escape "$Architecture")"

printf '{'
printf '"Name":"%s",' "$jn"
printf '"Manufacturer":"%s",' "$jm"
printf '"Cores":%d,' "$Cores"
printf '"Threads":%d,' "$Threads"
printf '"PhysicalCPUs":%d,' "$PhysicalCPUs"
printf '"L3CacheKB":%d,' "$L3CacheKB"
printf '"MaxClockMHz":%d,' "$MaxClockMHz"
printf '"Architecture":"%s",' "$ja"
printf '"Features":%s' "$Features"
printf '}\n'
