#!/usr/bin/env bash

arch=$(lscpu | grep Architecture | awk {'print $2'});
osname=$(. /etc/os-release && echo $NAME)

if [[ "${arch}" == "aarch64" && "${osname}" == "Ubuntu" ]]; then
    wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
fi 
