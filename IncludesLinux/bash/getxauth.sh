#!/usr/bin/env bash

xa=$( (ps -u $(id -u) -o pid= | xargs -I{} cat /proc/{}/environ | tr '\0' '\n' | grep -m1 '^XAUTHORITY=') 2>/dev/null )

if [ -z "$xa" ]; then
    # no desktop session (ssh, root, login screen): use the X server's -auth cookie;
    # match the binary name, the Xorg path differs by distro
    xf=$(ps -eo args= 2>/dev/null | grep -m1 -E '(^|/)(Xorg|X)( |$).* -auth ' | sed -E 's/.* -auth ([^ ]+).*/\1/')
    [ -n "$xf" ] && xa="XAUTHORITY=$xf"
fi

[ -n "$xa" ] && echo "$xa"