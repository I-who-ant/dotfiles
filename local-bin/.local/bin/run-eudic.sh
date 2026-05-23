#!/bin/bash

# 智能 Eudic 启动脚本
#
# 检查传入的第一个参数 ($1) 是否以 "eudic-ting://" 开头
if [[ "$1" == eudic-ting://* ]]; then
    # --- 情况 A: 是URL协议调用 ---
    # 记录日志，方便调试
    echo "URL scheme detected: $1" > /tmp/eudic_script.log
    
    # 从 URL 中提取 article_id
    # sed 命令会删除 "article_id=" 之前的所有内容
    ARTICLE_ID=$(echo "$1" | sed "s/.*article_id=//")
    
    # 拼接成一个标准的网页URL
    TARGET_URL="https://dict.eudic.net/webting/videoplay?id=${ARTICLE_ID}"
    
    echo "Extracted ID: ${ARTICLE_ID}" >> /tmp/eudic_script.log
    echo "Opening in browser: ${TARGET_URL}" >> /tmp/eudic_script.log
    
    # 使用 xdg-open 调用默认浏览器打开这个网页
    # 在后台运行 (&) 并且把输出重定向到/dev/null，避免阻塞
    xdg-open "${TARGET_URL}" >/dev/null 2>&1 &

else
    # --- 情况 B: 是普通启动 (从菜单点击图标) ---
    # 清理可能导致崩溃的环境变量
    # 这是我们之前发现的、解决启动崩溃的关键步骤
    unset XDG_CURRENT_DESKTOP
    unset XDG_SESSION_TYPE
    
    # 设置必要的环境变量，确保程序在你的环境下正常运行
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export QT_IM_MODULE=fcitx
    export QT_QPA_PLATFORM="xcb"
    
    # 启动主程序，并将所有传入的参数 ($@) 传递给它
    # 这使得从文件管理器打开词典文件等功能依然可用
    /lib/eusoft-eudic/eudic "$@"
fi
