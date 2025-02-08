#!/bin/sh

# Function to check if jq is available
has_jq() {
    type jq >/dev/null 2>&1
}

# Detect system architecture
ARCH=`uname -m`
OS=`uname -s`

# Function to get CPU information
get_cpu_info() {
    if has_jq; then
        cpu_temp=`sensors -j 2>/dev/null | jq '.. | objects | .temp1_input?' | awk '{sum+=$1; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    else
        cpu_temp=`sensors 2>/dev/null | awk '/temp1_input/ {sum+=$2; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    fi
    cpu_load=`grep 'cpu ' /proc/stat | awk '{idle=$5; total=$2+$3+$4+$5+$6+$7+$8; print 100-((idle-prev_idle)/(total-prev_total)*100); prev_idle=idle; prev_total=total;}'`

    echo "\"CPU\": {\"power\": null, \"temp\": ${cpu_temp:-null}, \"load\": ${cpu_load:-null}}"
}

# Function to get OpenCL GPU order
get_opencl_gpus() {
    if type clinfo >/dev/null 2>&1; then
        clinfo -l | awk -F' ' '/Device /{print $2}' | awk '{print NR-1, $1}'
    else
        echo "0 dummy"
    fi
}

# Platform-specific GPU functions
if [ "$ARCH" = "x86_64" ]; then
    get_nvidia_gpus() {
        if type nvidia-smi >/dev/null 2>&1; then
            nvidia-smi --query-gpu=gpu_bus_id,power.draw,temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null |
            awk -F', ' '{print $1, "NVIDIA", $2, $3, $4}'
        fi
    }

    get_amd_gpus() {
        if has_jq; then
            sensors -j 2>/dev/null | jq -r 'to_entries | map(select(.key | startswith("amdgpu-pci"))) | 
            map({(.key | gsub("amdgpu-pci-"; "")): { "vendor": "AMD", "power": .value.power1_input, "temp": .value.temp1_input }}) | add' 2>/dev/null
        else
            sensors 2>/dev/null | awk '/amdgpu-pci/ {getline; getline; print $2, "AMD", $4, $6}'
        fi
    }
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
    get_rpi_gpu_info() {
        if type vcgencmd >/dev/null 2>&1; then
            gpu_temp=`vcgencmd measure_temp | cut -d "=" -f2 | cut -d "'" -f1`
            gpu_load="null"
            echo "Broadcom VideoCore $gpu_temp $gpu_load"
        else
            echo ""
        fi
    }

    get_mali_gpu_info() {
        mali_name="Mali GPU"
        mali_load="null"
        mali_temp="null"

        if [ -f /sys/devices/platform/mali/utilisation ]; then
            mali_load=`cat /sys/devices/platform/mali/utilisation | awk '{print $1}'`
        fi
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            mali_temp=`awk '{print $1/1000}' /sys/class/thermal/thermal_zone0/temp`
        fi

        echo "$mali_name $mali_temp $mali_load"
    }

    get_jetson_gpu_info() {
        if type tegrastats >/dev/null 2>&1; then
            jetson_load=`tegrastats --interval 100 | awk '/GR3D/ {print $2}' | sed 's/%//g'`
            jetson_temp=`cat /sys/devices/virtual/thermal/thermal_zone0/temp | awk '{print $1/1000}'`
            echo "NVIDIA Jetson $jetson_temp $jetson_load"
        else
            echo ""
        fi
    }
elif [ "$OS" = "Darwin" ]; then
    get_apple_gpu_info() {
        if type ioreg >/dev/null 2>&1; then
            apple_load=`ioreg -r -c AGXAccelerator | grep "GPU Usage" | awk '{print $3}'`
            apple_temp="null"
            echo "Apple M1/M2 $apple_temp $apple_load"
        else
            echo ""
        fi
    }
fi

# Merge all GPU data based on OpenCL sorting
merge_gpu_data() {
    opencl_order=`get_opencl_gpus`
    echo "\"GPU\": {"
    gpu_index=0
    comma=""

    if [ "$ARCH" = "x86_64" ]; then
        nvidia_data=`get_nvidia_gpus`
        amd_data=`get_amd_gpus`
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
        rpi_gpu_data=`get_rpi_gpu_info`
        mali_gpu_data=`get_mali_gpu_info`
        jetson_gpu_data=`get_jetson_gpu_info`
    elif [ "$OS" = "Darwin" ]; then
        apple_gpu_data=`get_apple_gpu_info`
    fi

    echo "$opencl_order" | while read opencl_idx gpu_bus; do
        gpu_name="Unknown"
        gpu_temp="null"
        gpu_load="null"
        vendor="Unknown"

        if [ "$ARCH" = "x86_64" ]; then
            echo "$nvidia_data" | while read bus nvidia_vendor nvidia_power nvidia_temp nvidia_load; do
                if [ "$gpu_bus" = "$bus" ]; then
                    vendor="$nvidia_vendor"
                    power="$nvidia_power"
                    gpu_temp="$nvidia_temp"
                    gpu_load="$nvidia_load"
                    gpu_name="NVIDIA GPU"
                fi
            done

            if [ -n "$amd_data" ]; then
                amd_json=`echo "$amd_data" | jq -r --arg bus "$gpu_bus" '.[$bus]? | select(.!=null) | @json'`
                if [ -n "$amd_json" ]; then
                    vendor="AMD"
                    power=`echo "$amd_json" | jq '.power' 2>/dev/null || echo "null"`
                    gpu_temp=`echo "$amd_json" | jq '.temp' 2>/dev/null || echo "null"`
                    gpu_name="AMD GPU"
                fi
            fi
        elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
            if [ -n "$rpi_gpu_data" ]; then gpu_name="Broadcom VideoCore"; fi
            if [ -n "$mali_gpu_data" ]; then gpu_name="Mali GPU"; fi
            if [ -n "$jetson_gpu_data" ]; then gpu_name="NVIDIA Jetson"; fi
        elif [ "$OS" = "Darwin" ]; then
            if [ -n "$apple_gpu_data" ]; then gpu_name="Apple M1/M2"; fi
        fi

        echo "$comma\"$gpu_index\": {\"PCIe\": \"$gpu_bus\", \"vendor\": \"$vendor\", \"name\": \"$gpu_name\", \"power\": null, \"temp\": $gpu_temp, \"load\": $gpu_load}"
        comma=","
        gpu_index=$((gpu_index+1))
    done

    echo "}"
}

# Start JSON Output
echo "{"

# Collect CPU Info
get_cpu_info
echo ","

# Collect GPU Info
merge_gpu_data

# End JSON Output
echo "}"
