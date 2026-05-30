#!/usr/bin/env bash
set -euo pipefail

items=(
  'emacs:/home/seeback/.emacs'
  'emacs-local:/home/seeback/.emacs.local'
  'zsh:/home/seeback/.config/zsh/.zshrc'
  'rofi:/home/seeback/.config/rofi'
  'hypr:/home/seeback/.config/hypr'
  'waybar:/home/seeback/.config/waybar'
  'fastfetch:/home/seeback/.config/fastfetch'
  'kitty:/home/seeback/.config/kitty/kitty.conf'
  'fcitx5:/home/seeback/.config/fcitx5/config'
  'rime:/home/seeback/.local/share/fcitx5/rime/rime_ice.custom.yaml'
  'gtk-3.0:/home/seeback/.config/gtk-3.0'
  'gtk-4.0:/home/seeback/.config/gtk-4.0'
  'autostart:/home/seeback/.config/autostart'
  'wlogout:/home/seeback/.config/wlogout'
  'mako:/home/seeback/.config/mako'
  'btop:/home/seeback/.config/btop'
  'mpv:/home/seeback/.config/mpv'
  'flameshot:/home/seeback/.config/flameshot'
  'browser-flags:/home/seeback/.config/chromium-flags.conf'
  'pavucontrol:/home/seeback/.config/pavucontrol.ini'
  'xsettingsd:/home/seeback/.config/xsettingsd'
  'xdg-desktop-portal:/home/seeback/.config/xdg-desktop-portal'
  'git:/home/seeback/.config/git/ignore'
  'cava:/home/seeback/.config/cava'
  'htop:/home/seeback/.config/htop/htoprc'
  'atuin:/home/seeback/.config/atuin'
  'ripgrep-all:/home/seeback/.config/ripgrep-all'
  'glow:/home/seeback/.config/glow'
  'niri:/home/seeback/.config/niri'
  'systemd-user:/home/seeback/.config/systemd/user'
  'kvantum:/home/seeback/.config/Kvantum'
  'foot:/home/seeback/.config/foot'
  'qt6ct:/home/seeback/.config/qt6ct'
  'nwg-look:/home/seeback/.config/nwg-look'
  'local-bin:/home/seeback/.local/bin'
  'local-apps:/home/seeback/.local/share/applications'
)

printf '%-18s %-8s %s\n' 'PACKAGE' 'STATE' 'PATH'
for item in "${items[@]}"; do
  pkg=${item%%:*}
  path=${item#*:}
  if [ -L "$path" ]; then
    state='symlink'
  elif [ -e "$path" ]; then
    state='real'
  else
    state='missing'
  fi
  printf '%-18s %-8s %s\n' "$pkg" "$state" "$path"
done
