#!/usr/bin/env bash

if hash ss 2>/dev/null; then
        (ss -twan | awk '{print $5}' | grep ':[0-9]' | cut -d ":" -f 2 | sort -n | uniq) 2>/dev/null
    else
        (netstat -twan | awk '{print $4}' | grep ':[0-9]' | cut -d ":" -f 2 | sort -n | uniq) 2>/dev/null
fi
