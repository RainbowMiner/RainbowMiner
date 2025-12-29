#!/bin/sh

# Function to check if jq is available
has_jq() {
    type jq >/dev/null 2>&1
}

# Function to get CPU information (ARM-friendly)
get_cpu_info() {
    if has_jq; then
        cpu_temp=`sensors -j 2>/dev/null | jq '.. | objects | .temp1_input?' | awk '{sum+=$1; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    else
        cpu_temp=`sensors 2>/dev/null | awk '/temp1_input/ {sum+=$2; count+=1} END {if (count>0) print sum/count; else print "null"}'`
    fi
    cpu_load=`awk '{print $1}' /proc/stat | awk '{print (100 - $0)}'`

    echo "\"CPU\": {\"power\": null, \"temp\": ${cpu_temp:-null}, \"load\": ${cpu_load:-null}}"
}

# Function to get OpenCL GPU order (or fallback to dummy order)
get_opencl_gpus() {
    if type clinfo >/dev/null 2>&1; then
        clinfo -l | awk -F' ' '/Device /{print $2}' | awk '{print NR-1, $1}'
    else
        echo "0 dummy"
    fi
}

# Function to get Raspberry Pi GPU info
get_rpi_gpu_info() {
    if type vcgencmd >/dev/null 2>&1; then
        gpu_temp=`vcgencmd measure_temp | cut -d "=" -f2 | cut -d "'" -f1`
        gpu_load="null"
        echo "Broadcom VideoCore $gpu_temp $gpu_load"
    else
        echo ""
    fi
}

# Function to get ARM Mali GPU info (Odroid, Rockchip, etc.)
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

# Function to get NVIDIA Jetson GPU info
get_jetson_gpu_info() {
    if type tegrastats >/dev/null 2>&1; then
        jetson_load=`tegrastats --interval 100 | awk '/GR3D/ {print $2}' | sed 's/%//g'`
        jetson_temp=`cat /sys/devices/virtual/thermal/thermal_zone0/temp | awk '{print $1/1000}'`
        echo "NVIDIA Jetson $jetson_temp $jetson_load"
    else
        echo ""
    fi
}

# Function to get Apple M1/M2 GPU info
get_apple_gpu_info() {
    if type ioreg >/dev/null 2>&1; then
        apple_load=`ioreg -r -c AGXAccelerator | grep "GPU Usage" | awk '{print $3}'`
        apple_temp="null"  # Apple does not expose GPU temp via standard means
        echo "Apple M1/M2 $apple_temp $apple_load"
    else
        echo ""
    fi
}

# Merge all GPU data based on OpenCL sorting
merge_gpu_data() {
    opencl_order=`get_opencl_gpus`
    rpi_gpu_data=`get_rpi_gpu_info`
    mali_gpu_data=`get_mali_gpu_info`
    jetson_gpu_data=`get_jetson_gpu_info`
    apple_gpu_data=`get_apple_gpu_info`

    echo "\"GPU\": {"
    comma=""
    gpu_index=0

    echo "$opencl_order" | while read opencl_idx gpu_bus; do
        gpu_name="Unknown"
        gpu_temp="null"
        gpu_load="null"

        if [ -n "$rpi_gpu_data" ]; then
            gpu_name=`echo "$rpi_gpu_data" | awk '{print $1 " " $2}'`
            gpu_temp=`echo "$rpi_gpu_data" | awk '{print $3}'`
            gpu_load=`echo "$rpi_gpu_data" | awk '{print $4}'`
        fi

        if [ -n "$mali_gpu_data" ]; then
            gpu_name=`echo "$mali_gpu_data" | awk '{print $1 " " $2}'`
            gpu_temp=`echo "$mali_gpu_data" | awk '{print $3}'`
            gpu_load=`echo "$mali_gpu_data" | awk '{print $4}'`
        fi

        if [ -n "$jetson_gpu_data" ]; then
            gpu_name=`echo "$jetson_gpu_data" | awk '{print $1 " " $2}'`
            gpu_temp=`echo "$jetson_gpu_data" | awk '{print $3}'`
            gpu_load=`echo "$jetson_gpu_data" | awk '{print $4}'`
        fi

        if [ -n "$apple_gpu_data" ]; then
            gpu_name=`echo "$apple_gpu_data" | awk '{print $1 " " $2}'`
            gpu_temp=`echo "$apple_gpu_data" | awk '{print $3}'`
            gpu_load=`echo "$apple_gpu_data" | awk '{print $4}'`
        fi

        echo "$comma\"$gpu_index\": {\"PCIe\": \"$gpu_bus\", \"vendor\": \"ARM\", \"name\": \"$gpu_name\", \"power\": null, \"temp\": $gpu_temp, \"load\": $gpu_load}"
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
