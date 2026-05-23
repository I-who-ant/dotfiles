#!/bin/sh

HYPRLAND_DEVICE="$1"

if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

export STATUS_FILE="$XDG_RUNTIME_DIR/touchpad.status"

enable_touchpad() {
    printf "true" >"$STATUS_FILE"
    notify-send -u normal "触摸板已启用" "Touchpad Enabled"
    hyprctl keyword "device[$HYPRLAND_DEVICE]:enabled" true
    hyprctl keyword "device[syna2ba6:00-06cb:cefe-mouse]:enabled" true
}

disable_touchpad() {
    printf "false" >"$STATUS_FILE"
    notify-send -u normal "触摸板已禁用" "Touchpad Disabled"
    hyprctl keyword "device[$HYPRLAND_DEVICE]:enabled" false
    hyprctl keyword "device[syna2ba6:00-06cb:cefe-mouse]:enabled" false
}

if ! [ -f "$STATUS_FILE" ]; then
    enable_touchpad
else
    if [ "$(cat "$STATUS_FILE")" = "true" ]; then
        disable_touchpad
    elif [ "$(cat "$STATUS_FILE")" = "false" ]; then
        enable_touchpad
    fi
fi
