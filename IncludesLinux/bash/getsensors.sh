#!/bin/sh

# Function to check if jq is available
has_jq() {
    type jq >/dev/null 2>&1
}

# Function to get CPU information (fallback to awk)
get_cpu_info() {
    if has_jq; then
        cpu_power=`sensors -j 2>/dev/null | jq 'walk(if type == "object" then with_entries(select(.key | test("power.*_input$"))) else . end) | .. | objects | .power1_input?' | awk '{sum+=$1} END {print sum}'`
        cpu_temp=`sensors -j 2>/dev/null | jq '.. | objects | .temp1_input?' | awk '{sum+=$1; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    else
        cpu_power=`sensors 2>/dev/null | awk '/power1_input/ {sum+=$2} END {print sum}'`
        cpu_temp=`sensors 2>/dev/null | awk '/temp1_input/ {sum+=$2; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    fi
    cpu_load=`awk '{print $1}' /proc/stat | awk '{print (100 - $0)}'`

    echo "\"CPU\": {\"power\": ${cpu_power:-null}, \"temp\": ${cpu_temp:-null}, \"load\": ${cpu_load:-null}}"
}

# Function to get OpenCL GPU order
get_opencl_gpus() {
    if type clinfo >/dev/null 2>&1; then
        clinfo -l | awk -F' ' '/Device /{print $2}' | awk '{print NR-1, $1}'
    else
        echo ""
    fi
}

# Function to get NVIDIA GPU info
get_nvidia_gpus() {
    if type nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=gpu_bus_id,power.draw,temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null |
        awk -F', ' '{print $1, "NVIDIA", $2, $3, $4}'
    fi
}

# Function to get AMD GPU info (fallback for jq)
get_amd_gpus() {
    if has_jq; then
        sensors -j 2>/dev/null | jq -r 'to_entries | map(select(.key | startswith("amdgpu-pci"))) | 
        map({(.key | gsub("amdgpu-pci-"; "")): { "vendor": "AMD", "power": .value.power1_input, "temp": .value.temp1_input }}) | add' 2>/dev/null
    else
        sensors 2>/dev/null | awk '/amdgpu-pci/ {getline; getline; print $2, "AMD", $4, $6}'
    fi
}

# Function to get Intel GPU info
get_intel_gpus() {
    intel_load="null"
    intel_power="null"
    intel_temp="null"

    if type intel_gpu_top >/dev/null 2>&1; then
        intel_load=`intel_gpu_top -l 1 2>/dev/null | awk '/Render/ {print $2}' | sed 's/%//g'`
    fi

    if type intel_gpu_frequency >/dev/null 2>&1; then
        intel_power=`intel_gpu_frequency | awk '/Actual/ {print $2}'`
    fi

    if has_jq; then
        intel_temp=`sensors -j 2>/dev/null | jq '.. | objects | .temp1_input?' | awk '{sum+=$1; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    else
        intel_temp=`sensors 2>/dev/null | awk '/temp1_input/ {sum+=$2; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    fi

    echo "{ \"vendor\": \"INTEL\", \"power\": ${intel_power:-null}, \"temp\": ${intel_temp:-null}, \"load\": ${intel_load:-null} }"
}

# Merge all GPU data based on OpenCL sorting
merge_gpu_data() {
    opencl_order=`get_opencl_gpus`
    nvidia_data=`get_nvidia_gpus`
    amd_data=`get_amd_gpus`
    intel_data=`get_intel_gpus`

    echo "\"GPU\": {"
    comma=""

    echo "$opencl_order" | while read opencl_idx pci_bus; do
        vendor="Unknown"
        power="null"
        temp="null"
        load="null"

        echo "$nvidia_data" | while read bus nvidia_vendor nvidia_power nvidia_temp nvidia_load; do
            if [ "$pci_bus" = "$bus" ]; then
                vendor="$nvidia_vendor"
                power="$nvidia_power"
                temp="$nvidia_temp"
                load="$nvidia_load"
            fi
        done

        if [ -n "$amd_data" ]; then
            if has_jq; then
                amd_json=`echo "$amd_data" | jq -r --arg bus "$pci_bus" '.[$bus]? | select(.!=null) | @json'`
                if [ -n "$amd_json" ]; then
                    vendor="AMD"
                    power=`echo "$amd_json" | jq '.power' 2>/dev/null || echo "null"`
                    temp=`echo "$amd_json" | jq '.temp' 2>/dev/null || echo "null"`
                    load="null"
                fi
            else
                echo "$amd_data" | while read bus amd_vendor amd_power amd_temp; do
                    if [ "$pci_bus" = "$bus" ]; then
                        vendor="$amd_vendor"
                        power="$amd_power"
                        temp="$amd_temp"
                        load="null"
                    fi
                done
            fi
        fi

        if [ -n "$intel_data" ] && [ "$vendor" = "Unknown" ]; then
            vendor="INTEL"
            power=`echo "$intel_data" | awk -F'"power": ' '{print $2}' | awk -F',' '{print $1}'`
            temp=`echo "$intel_data" | awk -F'"temp": ' '{print $2}' | awk -F',' '{print $1}'`
            load=`echo "$intel_data" | awk -F'"load": ' '{print $2}' | awk -F'}' '{print $1}'`
        fi

        echo "$comma\"$opencl_idx\": {\"PCIe\": \"$pci_bus\", \"vendor\": \"$vendor\", \"power\": $power, \"temp\": $temp, \"load\": $load}"
        comma=","
    done

    echo "}"
}

# Start JSON Output
echo "{"

# Collect CPU Info
get_cpu_info
echo ","

# Collect GPU Info (NVIDIA, AMD, INTEL) and Sort by OpenCL Order
merge_gpu_data

# End JSON Output
echo "}"
