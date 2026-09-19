# ใช้ NVIDIA CUDA 12.9 Runtime Base Image บน Ubuntu 24.04
FROM nvidia/cuda:12.9.1-runtime-ubuntu24.04

# ตั้งค่าให้ไม่ต้องใส่ User Input ตอนติดตั้งแพ็กเกจ
ENV DEBIAN_FRONTEND=noninteractive

# ฝังค่า DNS ลงไปในระบบตั้งแต่ขั้นตอนการ Build เผื่อสคริปต์ภายในเรียกใช้งาน
RUN echo "nameserver 1.1.1.1" > /etc/resolv.conf

# ปิดการตรวจสอบอายุและบังคับข้าม GPG Check ชั่วคราวเพื่อให้ Build ผ่าน
RUN echo "Acquire::Check-Valid-Time \"false\";" > /etc/apt/apt.conf.d/99disable-check-valid && \
    apt-get -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true update && \
    apt-get install -y --allow-unauthenticated \
    software-properties-common \
    sudo \
    nano \
    wget \
    curl \
    apt-transport-https \
    xz-utils \
    git \
    build-essential \
    dkms \
    pciutils \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# เปลี่ยน Working Directory ไปที่ /opt/RainbowMiner ตามโครงสร้างปกติ
WORKDIR /opt/RainbowMiner

# โคลนโปรเจกต์ RainbowMiner จาก GitHub มาไว้ที่ /opt/RainbowMiner
RUN git clone https://github.com/xiaolin1579/RainbowMiner.git .

# สร้างโครงสร้างโฟลเดอร์ Config ภายใต้ /opt/RainbowMiner
RUN mkdir -p /opt/RainbowMiner/Config

# คัดลอก config.default.txt ไปวางในตำแหน่งที่ถูกต้อง
COPY Config1/config.txt /opt/RainbowMiner/Config/config.default.txt

# รันไฟล์ติดตั้ง
RUN apt-get update && chmod +x *.sh && ./install.sh

# เปิดพอร์ตสำหรับ Web Interface
EXPOSE 4000

# กำหนดคำสั่งเริ่มต้น
CMD ["./start-tmux.sh"]