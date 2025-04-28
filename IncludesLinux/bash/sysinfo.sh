#!/bin/sh
export LC_ALL=C

# Default behavior
SHOW_CPU=false
SHOW_MEM=false
SHOW_NVIDIA=false
SHOW_AMD=false
SHOW_INTEL=false
SHOW_OTHER=false
SHOW_DISKS=false
VERBOSE=false
SHOW_ALL=true

# Function to display help
show_help() {
    echo "RainbowMiner's sysinfo v2.0"
    echo "Usage: $0 [OPTIONS]"
    echo "  -V, --verbose     Show full CPU/GPU names"
    echo "  -A, --all         Show all CPU, GPU, and Memory info (default)"
    echo "  -m, --mem         Show memory section"
    echo "  -c, --cpu         Show CPU section"
    echo "  -g, --gpu         Show GPU section"
    echo "  -n, --nvidia      Show only NVIDIA GPUs"
    echo "  -a, --amd         Show only AMD GPUs"
    echo "  -i, --intel       Show only Intel GPUs"
    echo "  -o, --other       Show only other GPUs (e.g. ARM)"
    echo "  -h, --help        Show this help"
    exit 0
}

# Parse command-line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -V|--verbose)
            VERBOSE=true
            ;;
        -A|--all)
            SHOW_ALL=true
            ;;
        -g|--gpu)
            SHOW_GPU=true
            SHOW_ALL=false
            ;;
        -n|--nvidia)
            SHOW_NVIDIA=true
            SHOW_ALL=false
            SHOW_GPU=false
            ;;
        -a|--amd)
            SHOW_AMD=true
            SHOW_ALL=false
            SHOW_GPU=false
            ;;
        -i|--intel)
            SHOW_INTEL=true
            SHOW_ALL=false
            SHOW_GPU=false
            ;;
        -o|--other)
            SHOW_OTHER=true
            SHOW_ALL=false
            SHOW_GPU=false
            ;;
        -c|--cpu)
            SHOW_CPU=true
            SHOW_ALL=false
            ;;
        -m|--mem)
            SHOW_MEM=true
            SHOW_ALL=false
            ;;
        -d|--disks)
            SHOW_DISKS=true
            SHOW_ALL=false
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
    shift
done

# Function to check if a command is available
has_command() {
    type "$1" >/dev/null 2>&1
}

# Function to get OpenCL GPU order
get_opencl_gpus() {
    if has_command clinfo; then
        clinfo -l | awk -F' ' '/Device /{print $2}' | awk '{print NR-1, $1}'
    else
        echo "0 dummy"
    fi
}

# Function to get real GPU names
get_gpu_name() {
    if [ "$VERBOSE" = true ]; then
        pcie_id="$1"
        if has_command lspci; then
            gpu_name=$(lspci -nn | grep "$pcie_id" | sed -E 's/.*: (.*) \[.*\].*/\1/')
            [ -n "$gpu_name" ] && echo "$gpu_name" && return
        fi
        if has_command glxinfo; then
            gpu_name=$(glxinfo | grep "OpenGL renderer string" | cut -d":" -f2 | sed 's/^ *//')
            [ -n "$gpu_name" ] && echo "$gpu_name" && return
        fi
        echo "Unknown GPU"
    fi
}

# Function to get CPU information (Handles Multi-CPU Boards)
get_cpu_info() {
    cpu_name=""
    cpu_clock="null"
    cpu_load="null"
    cpu_temp="null"
    cpu_power="null"
    cpu_count=1

    # Fetch CPU name and socket count using lscpu (called only once)
    if [ "$VERBOSE" = true ]; then
        cpu_name="Unknown CPU"
        if has_command lscpu; then
            cpu_info=$(LC_ALL=C lscpu)
            cpu_name=$(echo "$cpu_info" | awk -F: '/Model name/ {print $2}' | sed 's/^ *//')
            cpu_count=$(echo "$cpu_info" | awk -F: '/Socket\(s\)/ {print $2}' | sed 's/^ *//')
            if ! echo "$cpu_count" | grep -qE '^[0-9]+$'; then
                cpu_count=1  # Default to 1 if it's not a valid number
            fi
        fi
    fi

    # Try reading CPU frequency from sysfs (for multi-CPU systems)
    if [ -d /sys/devices/system/cpu ]; then
        cpu_clock_sum=0
        cpu_clock_count=0

        for cpu_freq_file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
            if [ -f "$cpu_freq_file" ]; then
                cpu_freq=$(awk '{print $1/1000}' "$cpu_freq_file" 2>/dev/null)
                cpu_clock_sum=$(awk -v sum="$cpu_clock_sum" -v freq="$cpu_freq" 'BEGIN {print sum + freq}' 2>/dev/null)
                cpu_clock_count=$((cpu_clock_count + 1))
            fi
        done

        if [ "$cpu_clock_count" -gt 0 ]; then
            cpu_clock=$(awk -v sum="$cpu_clock_sum" -v count="$cpu_clock_count" 'BEGIN {print sum / count}' 2>/dev/null)
        fi
    fi

    # Fallback to lscpu if sysfs method fails
    if [ "$cpu_clock" = "null" ] || [ -z "$cpu_clock" ]; then
        if has_command lscpu; then
            [ -z "$cpu_info" ] && cpu_info=$(LC_ALL=C lscpu)
            cpu_clock=$(echo "$cpu_info" | awk '/CPU MHz:/ {print $3}' 2>/dev/null)
        fi
    fi

    # Final fallback to /proc/cpuinfo
    if [ "$cpu_clock" = "null" ] || [ -z "$cpu_clock" ]; then
        if grep -q "MHz" /proc/cpuinfo; then
            cpu_clock=$(grep "MHz" /proc/cpuinfo | awk '{print $4}' | head -n1 2>/dev/null)
        fi
    fi

    # If still empty, set it to "null" to avoid invalid JSON
    if [ -z "$cpu_clock" ] || ! echo "$cpu_clock" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        cpu_clock="null"
    fi

    # CPU load calculation
    cpu_load=$(grep 'cpu ' /proc/stat | awk '{idle=$5; total=$2+$3+$4+$5+$6+$7+$8; print 100-((idle-prev_idle)/(total-prev_total)*100); prev_idle=idle; prev_total=total;}')

    # CPU temperature detection
    for path in \
        /sys/devices/platform/coretemp.0/hwmon/hwmon3/temp1_input \
        /sys/devices/platform/coretemp.0/hwmon/hwmon1/temp1_input \
        /sys/devices/platform/coretemp.0/hwmon/hwmon2/temp1_input \
        /sys/class/hwmon/hwmon2/temp1_input \
        /sys/class/hwmon/hwmon0/temp1_input; do
        if [ -f "$path" ]; then
            cpu_temp=$(awk '{print $1/1000}' "$path" 2>/dev/null)
            break
        fi
    done

    # CPU power detection
    if [ -f /sys/class/powercap/intel-rapl:0/energy_uj ]; then
        energy1=$(cat /sys/class/powercap/intel-rapl:0/energy_uj 2>/dev/null)
        sleep 0.05  # 50 milliseconds
        energy2=$(cat /sys/class/powercap/intel-rapl:0/energy_uj 2>/dev/null)

        if [ -n "$energy1" ] && [ -n "$energy2" ] && echo "$energy1$energy2" | grep -qE '^[0-9]+$'; then
            delta=$(awk -v e1="$energy1" -v e2="$energy2" 'BEGIN {print e2 - e1}')
            if [ "$delta" -lt 0 ]; then
                # Handle counter wraparound
                delta=$((delta + 2**32))
            fi
            cpu_power=$(awk -v d="$delta" 'BEGIN {print (d / 1000000) * 20}')  # delta Joules * (1/0.05s) = Watt
        fi
    fi

    # Append "(xN)" only if there are multiple CPUs
    if [ "$cpu_count" -gt 1 ]; then
        cpu_name="${cpu_name} (x${cpu_count})"
    fi

    for var in cpu_load cpu_temp cpu_freq cpu_power; do
        eval "value=\$$var"  # Extract the variable value dynamically

        if [ -z "$value" ] || [ "$value" = "null" ]; then
            eval "$var=null"  # Set the variable to "null"
        else
            eval "$var=\$(printf \"%.1f\" \"$value\")"  # Format it as a float
        fi
    done

    printf "  \"CpuLoad\": ${cpu_load},\n"
    printf "  \"CPUs\": [\n    {\n      \"Name\": \"${cpu_name}\",\n      \"Clock\": ${cpu_clock},\n      \"Temperature\": ${cpu_temp},\n      \"PowerDraw\": ${cpu_power}\n    }\n  ]"
}

# Function to get Memory information
get_mem_info() {
    printf "  \"Memory\": {\n"
    if has_command free; then
        free -m | awk '
        /Mem:/ {
            printf "    \"TotalGB\": %.1f,\n", $2 / 1024
            printf "    \"UsedGB\": %.1f,\n", $3 / 1024
            printf "    \"UsedPercent\": %.2f\n", $3 * 100 / $2
        }'
    else
        printf "    \"TotalGB\": null,\n    \"UsedGB\": null,\n    \"UsedPercent\": null\n"
    fi
    printf "  }"
}

# Function to collect all GPU data before sorting
collect_gpu_data() {
    gpu_data=""
    gpu_index=0

    # NVIDIA GPUs
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ] || [ "$SHOW_NVIDIA" = true ]; then
        if has_command nvidia-smi; then
            nvidia_smi_data=$(LC_ALL=C nvidia-smi --query-gpu=gpu_bus_id,name,power.draw,temperature.gpu,fan.speed,utilization.gpu,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits 2>/dev/null)
            echo "$nvidia_smi_data" | while IFS="," read -r bus name power temp fan load clock clockmem; do
                gpu_data="$gpu_data$gpu_index,$bus,NVIDIA,$name,$power,$temp,$fan,$load,$clock,$clockmem\n"
                gpu_index=$((gpu_index+1))
            done
        fi
    fi

    # AMD GPUs
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ] || [ "$SHOW_AMD" = true ]; then
        if has_command sensors; then
            [ -z "$sensors_data_amd" ] && sensors_data_amd=$(LC_ALL=C sensors -j amdgpu-pci-* 2>/dev/null)
            amd_data=$(echo "$sensors_data_amd" | jq -r 'to_entries | map(select(.key | startswith("amdgpu-pci"))) |
            map({(.key | gsub("amdgpu-pci-"; "")): { "PCIe": .key, "vendor": "AMD", "name": .value.name, "power": .value.power1_input, "temp": .value.temp1_input, "fan": .value.fan1_input, "clock": .value.gpu_clock_input, "clockmem": .value.mem_clock_input }}) | add' 2>/dev/null)
            if [ -n "$amd_data" ]; then
                echo "$amd_data" | while IFS="," read -r bus name power temp fan clock clockmem; do
                    gpu_data="$gpu_data$gpu_index,$bus,AMD,$name,$power,$temp,$fan,null,$clock,$clockmem\n"
                    gpu_index=$((gpu_index+1))
                done
            fi
        fi
    fi

    # Intel GPUs (including modern Intel Arc support)
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ] || [ "$SHOW_INTEL" = true ]; then
        if [ -d /sys/class/drm ]; then
            for card in /sys/class/drm/card*/; do
                vendor=$(cat "$card/device/vendor" 2>/dev/null)
                device=$(cat "$card/device/device" 2>/dev/null)

                if [ "$vendor" = "0x8086" ]; then # Intel Vendor ID
                    # Get the driver name
                    name="Intel GPU"
                    if [ -f "$card/device/uevent" ]; then
                        driver_name=$(grep -m1 "DRIVER=" "$card/device/uevent" | cut -d"=" -f2)
                        case "$driver_name" in
                            "i915") name="Intel Integrated Graphics" ;;
                            "xe") name="Intel Arc Graphics" ;;
                        esac
                    fi

                    # Get the PCI Device ID
                    if [ -f "$card/device/device" ]; then
                        device_id=$(cat "$card/device/device" 2>/dev/null | sed 's/^0x//')
                    else
                        device_id="unknown"
                    fi

                    # Match known Intel GPUs (Mapping Device IDs to Model Names)
                    case "$device_id" in
                        "56a0") name="Intel Arc A770" ;;
                        "56a1") name="Intel Arc A750" ;;
                        "56a2") name="Intel Arc A580" ;;
                        "56a5") name="Intel Arc A380" ;;
                        "9a60"|"9a68"|"9a70") name="Intel UHD Graphics 750" ;;
                        "9bc5") name="Intel UHD Graphics 770" ;;
                        "9a40"|"9a49") name="Intel Iris Xe Graphics" ;;
                        "46c0") name="Intel UHD Graphics 730" ;;
                    esac
                
                    # Extract PCIe Bus ID
                    if [ -f "$card/device/uevent" ]; then
                        pcie_bus=$(grep -m1 "PCI_SLOT_NAME=" "$card/device/uevent" | cut -d"=" -f2)
                    else
                        pcie_bus="null"
                    fi

                    # Read GPU utilization (Load %)
                    if [ -f "$card/device/gpu_busy_percent" ]; then
                        intel_load=$(cat "$card/device/gpu_busy_percent" 2>/dev/null)
                    else
                        intel_load="null"
                    fi

                    # Read GPU Core Clock Speed (MHz)
                    if [ -f "$card/device/gt_cur_freq_mhz" ]; then
                        intel_clock=$(cat "$card/device/gt_cur_freq_mhz" 2>/dev/null)
                    else
                        intel_clock="null"
                    fi

                    # Read GPU Memory Clock Speed (MHz)
                    if [ -f "$card/device/mem_cur_freq_mhz" ]; then
                        intel_clockmem=$(cat "$card/device/mem_cur_freq_mhz" 2>/dev/null)
                    else
                        intel_clockmem="null"
                    fi

                    # Try reading power, temperature & fan speed from `sensors`
                    intel_power="null"
                    intel_temp="null"
                    intel_fan="null"
                    if has_command sensors; then
                        [ -z "$sensors_data_intel" ] && sensors_data_intel=$(LC_ALL=C sensors -j xe-pci-* 2>/dev/null)
                        intel_power=$(echo "$sensors_data_intel" | jq -r '.["xe-pci-*"].power1_input // "null"' 2>/dev/null)
                        intel_temp=$(echo "$sensors_data_intel" | jq -r '.["xe-pci-*"].temp1_input // "null"' 2>/dev/null)
                        intel_fan=$(echo "$sensors_data_intel" | jq -r '.["xe-pci-*"].fan1_input // "null"' 2>/dev/null)
                    fi

                    # Try reading power from `/sys/class/powercap`
                    if [ "$intel_power" = "null" ] && [ -f "/sys/class/powercap/intel-rapl:0/energy_uj" ]; then
                        energy_uj=$(cat "/sys/class/powercap/intel-rapl:0/energy_uj" 2>/dev/null)
                        intel_power=$(awk "BEGIN {print $energy_uj / 1000000}")  # Convert µJ to Watts
                    fi

                    # Estimate power if no direct reading is available
                    if [ "$intel_power" = "null" ] && [ "$intel_load" != "null" ]; then
                        case "$name" in
                            "Intel Arc A770") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 225}") ;;
                            "Intel Arc A750") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 190}") ;;
                            "Intel Arc A580") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 175}") ;;
                            "Intel Arc A380") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 75}") ;;
                            "Intel UHD Graphics 770") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 15}") ;;
                            "Intel UHD Graphics 750") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 15}") ;;
                            "Intel UHD Graphics 730") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 12}") ;;
                            "Intel Iris Xe Graphics") intel_power=$(awk "BEGIN {print ($intel_load / 100) * 28}") ;;
                            *) intel_power="null" ;; # Unknown GPU
                        esac
                    fi

                    # Read GPU Temperature (Celsius) - Fallbacks if sensors failed
                    if [ "$intel_temp" = "null" ]; then
                        if [ -f "$card/device/temp1_input" ]; then
                            intel_temp=$(awk '{print $1/1000}' "$card/device/temp1_input" 2>/dev/null)
                        elif [ -f "$card/device/temp2_input" ]; then
                            intel_temp=$(awk '{print $1/1000}' "$card/device/temp2_input" 2>/dev/null)
                        elif [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
                            intel_temp=$(awk '{print $1/1000}' "/sys/class/thermal/thermal_zone0/temp" 2>/dev/null)
                        fi
                    fi

                    gpu_data="$gpu_data$gpu_index,$pcie_bus,INTEL,$name,$intel_power,$intel_temp,$intel_fan,$intel_load,$intel_clock,$intel_clockmem\n"
                    gpu_index=$((gpu_index+1))
                fi
            done
        fi
    fi

    # ARM GPUs (Raspberry Pi, Jetson)
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ] || [ "$SHOW_OTHER" = true ]; then
        if has_command vcgencmd; then
            gpu_temp=$(LC_ALL=C vcgencmd measure_temp 2>/dev/null | cut -d "=" -f2 | cut -d "'" -f1)
            if echo "$gpu_temp" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                gpu_data="$gpu_data$gpu_index,null,ARM,Broadcom VideoCore,null,$gpu_temp,null,null,null,null\n"
                gpu_index=$((gpu_index+1))
            else
                gpu_data="$gpu_data$gpu_index,null,ARM,Broadcom VideoCore,null,null,null,null,null,null\n"
                gpu_index=$((gpu_index+1))
            fi
        fi
        if has_command tegrastats; then
            jetson_load=$(LC_ALL=C tegrastats --interval 100 2>/dev/null | awk '/GR3D/ {print $2}' | sed 's/%//g')
            jetson_temp=$(LC_ALL=C cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
            if echo "$jetson_temp" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                gpu_data="$gpu_data$gpu_index,null,ARM,NVIDIA Jetson,null,$jetson_temp,null,$jetson_load,null,null\n"
                gpu_index=$((gpu_index+1))
            else
                gpu_data="$gpu_data$gpu_index,null,ARM,NVIDIA Jetson,null,null,null,null,null,null\n"
                gpu_index=$((gpu_index+1))
            fi
        fi
    fi

    printf "$gpu_data"
}

# Merge all GPU data based on OpenCL sorting
merge_gpu_data() {
    collected_data=$(collect_gpu_data 2>/dev/null)

    # If no GPUs were found, return empty array
    if [ -z "$collected_data" ]; then
        printf "  \"GPUs\": []"
        return
    fi

    opencl_order=$(get_opencl_gpus 2>/dev/null)
    gpu_index=0
    comma=""

    printf "  \"GPUs\": [\n"
    
    if [ -n "$opencl_order" ]; then
        # Convert OpenCL bus IDs to lowercase for consistency
        echo "$opencl_order" | awk '{print tolower($0)}' | while read opencl_idx gpu_bus; do
            echo "$collected_data" | while IFS="," read index pcie vendor name power temp fan load clock clockmem; do
                pcie=$(echo "$pcie" | awk '{print tolower($0)}')  # Normalize to lowercase
                
                if [ "$gpu_bus" = "$pcie" ] || [ "$gpu_bus" = "dummy" ]; then
                    printf "$comma    {\n      \"Index\": $gpu_index,\n      \"BusId\": \"$pcie\",\n      \"Vendor\": \"$vendor\",\n      \"Name\": \"$name\",\n      \"PowerDraw\": $power,\n      \"Temperature\": $temp,\n      \"FanSpeed\": $fan,\n      \"Utilization\": $load,\n      \"Clock\": $clock,\n      \"ClockMem\": $clockmem\n    }"
                    comma=",\n"
                    gpu_index=$((gpu_index+1))
                    break
                fi
            done
        done
    fi

    # If OpenCL sorting failed, fallback to PCIe sorting
    if [ -z "$comma" ]; then
        echo "$collected_data" | awk -F"," '{print tolower($2), $0}' | sort | cut -d" " -f2- | while IFS="," read index pcie vendor name power temp fan load clock clockmem; do
            printf "$comma    {\n      \"Index\": $gpu_index,\n      \"BusId\": \"$pcie\",\n      \"Vendor\": \"$vendor\",\n      \"Name\": \"$name\",\n      \"PowerDraw\": $power,\n      \"Temperature\": $temp,\n      \"FanSpeed\": $fan,\n      \"Utilization\": $load,\n      \"Clock\": $clock,\n      \"ClockMem\": $clockmem\n    }"
            comma=",\n"
            gpu_index=$((gpu_index+1))
        done
    fi

    [ -n "$comma" ] && printf "\n"
    printf "  ]"
}

# Start JSON Output
comma=""
printf "{\n"  
if [ "$SHOW_ALL" = true ] || [ "$SHOW_CPU" = true ]; then
    get_cpu_info
    comma=",\n"
fi
if [ "$SHOW_ALL" = true ] || [ "$SHOW_MEM" = true ]; then
    printf "$comma"
    get_mem_info
    comma=",\n"
fi
if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ] || [ "$SHOW_NVIDIA" = true ] || [ "$SHOW_AMD" = true ] || [ "$SHOW_INTEL" = true ] || [ "$SHOW_OTHER" = true ]; then
    printf "$comma"
    merge_gpu_data
    comma=",\n"
fi

if [ "$SHOW_ALL" = true ] || [ "$SHOW_DISKS" = true ]; then
    printf "$comma"
    printf "  \"Disks\": null"
fi

# End JSON Output
printf "\n}"

