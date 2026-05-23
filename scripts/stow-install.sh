#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

packages=(
  emacs
  emacs-local
  zsh
  rofi
  hypr
  waybar
  fastfetch
  kitty
  fcitx5
  gtk-3.0
  gtk-4.0
  autostart
  wlogout
  mako
  btop
  mpv
  flameshot
  browser-flags
  pavucontrol
  xsettingsd
  xdg-desktop-portal
  git
  cava
  htop
  atuin
  ripgrep-all
  glow
  niri
  systemd-user
  kvantum
  foot
  qt6ct
  nwg-look
  local-bin
  local-apps
)

for pkg in "${packages[@]}"; do
  stow -v -d "$root" -t "$HOME" "$pkg"
done

cat <<'EOF'

Third-party dependencies not vendored by this repo:
  - oh-my-zsh
  - powerlevel10k (typically under ~/.oh-my-zsh/custom/themes/powerlevel10k)

This repo manages your zsh entrypoints and modules, but not the whole
oh-my-zsh source tree.
EOF
