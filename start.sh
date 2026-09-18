#!/usr/bin/env bash

cd "$(dirname "$0")"

# ---------------------------------------------------------
# ส่วนตรวจสอบและเตรียมไฟล์ Config / คัดลอกไฟล์ต้นแบบ
# ---------------------------------------------------------
CONFIG_DIR="./Config"
CONFIG_FILE="$CONFIG_DIR/config.txt"
DEFAULT_CONFIG="$CONFIG_DIR/config.default.txt" # กำหนดตำแหน่งไฟล์ต้นแบบของคุณที่นี่

if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo "สร้างโฟลเดอร์ Config เรียบร้อยแล้ว"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    # ตรวจสอบว่ามีไฟล์ต้นแบบเตรียมไว้ในอิมเมจหรือไม่
    if [ -f "$DEFAULT_CONFIG" ]; then
        cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
        echo "ไม่พบ config.txt ทำการคัดลอกไฟล์จาก config.default.txt มาใช้งานแล้ว"
    else
        # หากไม่มีไฟล์ต้นแบบ ให้สร้างไฟล์เปล่าสำรองไว้ก่อน
        touch "$CONFIG_FILE"
        echo "ไม่พบไฟล์ต้นแบบ สร้างไฟล์ config.txt เปล่าสำหรับเริ่มต้นระบบ"
    fi
fi

# เปิดสิทธิ์ให้ไฟล์คอนฟิกสามารถอ่านและเขียนได้ (ป้องกันปัญหา Web UI บันทึกไม่ได้)
chmod 666 "$CONFIG_FILE" 2>/dev/null || true
# ---------------------------------------------------------

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_WORKGROUP_SIZE=256
export CUDA_DEVICE_ORDER=PCI_BUS_ID

if command -v screen >/dev/null 2>&1 && ! test -d "/opt/rainbowminer/lib"
then
        screen_dir="$HOME/.screen"
        if ! test -d "$screen_dir"
        then
                mkdir "$screen_dir"
                chmod 700 "$screen_dir"
        fi
        export SCREENDIR="$screen_dir"
fi

command="& {./RainbowMiner.ps1 -configfile ./Config/config.txt $@; exit \$lastexitcode}"

while true; do

  pwsh -ExecutionPolicy bypass -Command ${command}

  if [ "$?" != "99" ]; then
    break
  fi

done