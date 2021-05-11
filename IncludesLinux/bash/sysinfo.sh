#!/usr/bin/env bash

awk 'BEGIN {
        printf "{\n"
        while(getline  < "/proc/loadavg") {
                printf "  \"CpuLoad\": %.2f,\n", $(NF-3)
        }

        if ((getline _ < "/opt/rainbowminer/bin/cpuinfo") >= 0) {
                printf "  \"Cpus\": [\n"
                i = 0
                while ("/opt/rainbowminer/bin/cpuinfo"| getline) {
                        if ( $0 ~ /CPU:/) {
                                if (i>0) {printf ",\n"}
                                printf "    {\n"
                                printf "      \"Clock\": %.1f,\n", $2
                                printf "      \"Temperature\": %.1f,\n", $3
                                printf "      \"Method\": \"cpuinfo\"\n"
                                printf "    }"
                                i++
                        }
                }
                if (i>0) {printf "\n"}
                printf "  ],\n"
        }

        while("free -m"| getline) {
                if( $0 ~ /Mem:/) {
                printf "  \"Memory\": {\n"
                printf "    \"TotalGB\": %.1f,\n", $2/1024
                printf "    \"UsedGB\": %.1f,\n", $3/1024
                printf "    \"UsedPercent\": %.2f\n", $3*100/$2
                printf "  },\n"
                }
        }

        printf "  \"Disks\": [\n"
        i = 0
        while("df -lPm " | getline) {
                if ( $NF == "/" ) {
                        if (i>0) {printf ",\n"}
                        printf "    {\n"
                        printf "      \"Drive\": \"%s\",\n", $1
                        printf "      \"Name\": \"\",\n"
                        printf "      \"TotalGB\": %.1f,\n", $2/1024
                        printf "      \"UsedGB\": %.1f,\n", $3/1024
                        printf "      \"UsedPercent\": %.2f\n", $3*100/$2
                        printf "    }"
                        i++
                }
        }
        if (i>0) {printf "\n"}
        printf "  ]\n}\n"

}'
