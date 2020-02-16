#!/usr/bin/env bash

ps -u $(id -u) -o pid= |
  xargs -I{} cat /proc/{}/environ 2>/dev/null |
  tr '\0' '\n' |
  grep -m1 '^XAUTHORITY='