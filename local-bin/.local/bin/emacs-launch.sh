#!/bin/sh
# rofi / 桌面入口启动 emacs 的统一脚本：
#   1. 确保 systemd 管理的 daemon 在跑（已 active 就秒返回）
#   2. 让 emacsclient 连这个 daemon，开一个新 frame
# 这样永远不会出现 "emacsclient 自己 fork 一个野 daemon" 的情况。

systemctl --user start emacs.service
exec /usr/bin/emacsclient --alternate-editor=false --create-frame "$@"
