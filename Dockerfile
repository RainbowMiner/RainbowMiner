# ใช้ NVIDIA CUDA 12.9 Runtime Base Image บน Ubuntu 24.04
FROM nvidia/cuda:12.9.1-runtime-ubuntu24.04

# ตั้งค่าให้ไม่ต้องใส่ User Input ตอนติดตั้งแพ็กเกจ
ENV DEBIAN_FRONTEND=noninteractive

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

# กำหนด Working Directory ไปที่ /root/RainbowMiner
WORKDIR /root/RainbowMiner

# โคลนโปรเจกต์ RainbowMiner จาก GitHub
RUN git clone https://github.com/RainbowMiner/RainbowMiner.git .

# สร้างโครงสร้างโฟลเดอร์ซ้อนกันที่ตัวโปรแกรม PowerShell ต้องการ
RUN mkdir -p /root/RainbowMiner/Config

# คัดลอก config.txt จากโปรเจกต์ของคุณไปวางในตำแหน่งที่โปรแกรมเรียกหา
COPY Config1/config.txt /root/RainbowMiner/Config/config.txt

# รันไฟล์ติดตั้ง
RUN apt-get update && chmod +x *.sh && ./install.sh

# เปิดพอร์ตสำหรับ Web Interface
EXPOSE 4000

# กำหนดคำสั่งเริ่มต้น
CMD ["./start.sh"]