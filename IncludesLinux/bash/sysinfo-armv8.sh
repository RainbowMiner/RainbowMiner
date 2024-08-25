#!/usr/bin/env bash

LC_ALL=C awk 'BEGIN {
        printf "{\n"
        load = 0
        if ( (getline < file) > 0 ) {
                close(file)
                while(getline < file) {
                        load = $(NF-3)
                }
        }
        else if (("uptime" | getline cmd_output) > 0) {
                if (index(cmd_output, "load average:") > 0) {
                        split(cmd_output, a, "load average: ")
                        split(a[2], loads, ", ")
                        load = loads[3]
                }
        }

        printf "  \"CpuLoad\": %.2f,\n", load

        if ((getline _ < "/opt/rainbowminer/bin/cpuinfo-armv8") >= 0) {
                printf "  \"Cpus\": [\n"
                i = 0
                while ("/opt/rainbowminer/bin/cpuinfo-armv8"| getline) {
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

        printf "  \"Disks\": null\n}\n"
}'
