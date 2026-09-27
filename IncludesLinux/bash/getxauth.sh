#!/usr/bin/env bash

xa=$( (ps -u $(id -u) -o pid= | xargs -I{} cat /proc/{}/environ | tr '\0' '\n' | grep -m1 '^XAUTHORITY=') 2>/dev/null )

if [ -z "$xa" ]; then
    # no desktop session of this user (ssh, root, gdm login screen): use the
    # cookie file the running X server has been started with
    xf=$(ps -eo args= 2>/dev/null | grep -m1 -E '(^|/)Xorg( |$).* -auth ' | sed -E 's/.* -auth ([^ ]+).*/\1/')
    [ -n "$xf" ] && xa="XAUTHORITY=$xf"
fi

[ -n "$xa" ] && echo "$xa"