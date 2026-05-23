#!/bin/bash
# Snipaste Wayland 多屏幕修复脚本

export QT_QPA_PLATFORM=xcb
export DISPLAY=:1

# 杀死已有进程
killall -9 Snipaste 2>/dev/null

# 等待进程完全退出
sleep 1

# 启动 Snipaste
/home/seeback/Applications/Snipaste-2.10.8-x86_64_3ca951f53f201755abe0e9e6990b20b9.AppImage &

echo "Snipaste 已启动（XWayland 兼容模式）"
