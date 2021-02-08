#!/usr/bin/env bash

(ps -u $(id -u) -o pid= | xargs -I{} cat /proc/{}/environ | tr '\0' '\n' | grep -m1 '^XAUTHORITY=') 2>/dev/null