#!/bin/bash

flameshot gui -p /tmp
screenshot_path=$(ls -t /tmp | grep -E "\.png$" | head -n 1)
image_path="/tmp/$screenshot_path"

result=$(wcocr /opt/wechat/wxocr /opt/wechat "$image_path" 2>/dev/null | perl -ne 'if(/\] r=[\d.]+ (.+)$/){print "\$1\n"}')
echo -n "$result" | xclip -selection clipboard

notify-send "OCR完成" "剪贴板写入成功" --icon=edit-paste
