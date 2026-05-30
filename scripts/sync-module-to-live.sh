#!/usr/bin/env bash
set -euo pipefail

DOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=false
DELETE=false
LIST_ONLY=false
selected_modules=()
blocked_sensitive=()

all_modules=(
  emacs
  emacs-local
  zsh
  rofi
  hypr
  waybar
  fastfetch
  kitty
  fcitx5
  rime
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
  ghostty
  qt6ct
  nwg-look
  local-bin
  local-apps
)

usage() {
  cat <<'USAGE'
Usage: sync-module-to-live.sh [options] <module> [module ...]

Sync one or more dotfiles modules from this repo back into live files under $HOME.

Options:
  -n, --dry-run   Show what would change without writing.
      --delete    Delete live files when matching repo files are missing.
      --list      Print all supported modules.
  -h, --help      Show this help.

Examples:
  sync-module-to-live.sh rime
  sync-module-to-live.sh -n hypr zsh
  sync-module-to-live.sh --list
USAGE
}

common_rsync_args=(
  -av
  --exclude=.git/
  --exclude=.DS_Store
  --exclude=.directory
  --exclude=.zcompdump*
  --exclude=.zsh_history
  --exclude='*.swp'
  --exclude='*.zwc'
  --exclude='*~'
  --exclude='*.log'
  --exclude='*.bak'
  --exclude='*.backup'
  --exclude='*.broken'
  --exclude='*.lock'
)

while (($#)); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      ;;
    --delete)
      DELETE=true
      ;;
    --list)
      LIST_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      selected_modules+=( "$1" )
      ;;
  esac
  shift
done

if $LIST_ONLY; then
  printf '%s\n' "${all_modules[@]}"
  exit 0
fi

if [ ${#selected_modules[@]} -eq 0 ]; then
  printf 'No module specified. Use --list to see supported modules.\n\n' >&2
  usage >&2
  exit 2
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo 'rsync is required but not found in PATH.' >&2
  exit 127
fi

has_module() {
  local target="$1"
  local item
  for item in "${all_modules[@]}"; do
    if [ "$item" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

is_sensitive_file() {
  local path="$1"
  [ -f "$path" ] || return 1
  grep -Iq . "$path" 2>/dev/null || return 1

  grep -nE \
    '(^|[[:space:]]|export[[:space:]]+)(env_key|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|[A-Z0-9_]*(TOKEN|SECRET|PASSWORD))[[:space:]]*=[[:space:]]*["'"'']?[^"'"''${[:space:]]' \
    "$path" >/dev/null 2>&1 && return 0
  grep -nE '/tmp/\.mount_[^/]+/' "$path" >/dev/null 2>&1 && return 0
  return 1
}

copy_repo_file() {
  local repo_rel="$1"
  local live_rel="$2"
  local src="$DOT_ROOT/$repo_rel"
  local dst="$HOME/$live_rel"
  local parent
  parent="$(dirname "$dst")"
  local args=( "${common_rsync_args[@]}" )
  $DRY_RUN && args+=( --dry-run )

  if [ -f "$src" ] || [ -L "$src" ]; then
    if is_sensitive_file "$src"; then
      echo "blocked sensitive file: $src" >&2
      blocked_sensitive+=( "$live_rel <= $repo_rel" )
      return
    fi
    if [ ! -d "$parent" ]; then
      if $DRY_RUN; then
        echo "would create directory: $parent"
        echo "would copy file: $src -> $dst"
        return
      fi
      mkdir -p "$parent"
    fi
    rsync "${args[@]}" "$src" "$dst"
    return
  fi

  echo "warning: missing repo file: $src" >&2
  if $DELETE && [ -e "$dst" ]; then
    if $DRY_RUN; then
      echo "would delete file: $dst"
    else
      rm -f "$dst"
      echo "deleted file: $dst"
    fi
  fi
}

copy_tracked_module() {
  local module="$1"
  local repo_rel
  while IFS= read -r -d '' repo_rel; do
    case "$repo_rel" in
      */README.md|*/TUNING.md|*/REGRESSION.md) continue ;;
    esac
    copy_repo_file "$repo_rel" "${repo_rel#*/}"
  done < <(git -C "$DOT_ROOT" ls-files -z -- "$module")
}

copy_rime() {
  local base_live='.local/share/fcitx5/rime'
  local base_repo='rime/.local/share/fcitx5/rime'
  local file
  for file in \
    default.custom.yaml \
    rime_ice.custom.yaml \
    tech_phrase.txt \
    mytech.dict.yaml \
    rime_ice_seeback.dict.yaml; do
    copy_repo_file "$base_repo/$file" "$base_live/$file"
  done
}

run_module() {
  local module="$1"
  printf '==> sync %s\n' "$module"
  case "$module" in
    emacs) copy_tracked_module 'emacs' ;;
    emacs-local) copy_tracked_module 'emacs-local' ;;
    zsh) copy_tracked_module 'zsh' ;;
    rofi) copy_tracked_module 'rofi' ;;
    hypr) copy_tracked_module 'hypr' ;;
    waybar) copy_tracked_module 'waybar' ;;
    fastfetch) copy_tracked_module 'fastfetch' ;;
    kitty) copy_tracked_module 'kitty' ;;
    fcitx5) copy_tracked_module 'fcitx5' ;;
    rime) copy_rime ;;
    gtk-3.0) copy_tracked_module 'gtk-3.0' ;;
    gtk-4.0) copy_tracked_module 'gtk-4.0' ;;
    autostart) copy_tracked_module 'autostart' ;;
    wlogout) copy_tracked_module 'wlogout' ;;
    mako) copy_tracked_module 'mako' ;;
    btop) copy_tracked_module 'btop' ;;
    mpv) copy_tracked_module 'mpv' ;;
    flameshot) copy_tracked_module 'flameshot' ;;
    browser-flags)
      copy_repo_file 'browser-flags/.config/chrome-flags.conf' '.config/chrome-flags.conf'
      copy_repo_file 'browser-flags/.config/chromium-flags.conf' '.config/chromium-flags.conf'
      copy_repo_file 'browser-flags/.config/electron-flags.conf' '.config/electron-flags.conf'
      copy_repo_file 'browser-flags/.config/microsoft-edge-flags.conf' '.config/microsoft-edge-flags.conf'
      ;;
    pavucontrol) copy_repo_file 'pavucontrol/.config/pavucontrol.ini' '.config/pavucontrol.ini' ;;
    xsettingsd) copy_tracked_module 'xsettingsd' ;;
    xdg-desktop-portal) copy_tracked_module 'xdg-desktop-portal' ;;
    git) copy_repo_file 'git/.config/git/ignore' '.config/git/ignore' ;;
    cava) copy_tracked_module 'cava' ;;
    htop) copy_repo_file 'htop/.config/htop/htoprc' '.config/htop/htoprc' ;;
    atuin) copy_tracked_module 'atuin' ;;
    ripgrep-all) copy_tracked_module 'ripgrep-all' ;;
    glow) copy_tracked_module 'glow' ;;
    niri) copy_tracked_module 'niri' ;;
    systemd-user) copy_tracked_module 'systemd-user' ;;
    kvantum) copy_tracked_module 'kvantum' ;;
    foot) copy_tracked_module 'foot' ;;
    ghostty) copy_tracked_module 'ghostty' ;;
    qt6ct) copy_tracked_module 'qt6ct' ;;
    nwg-look) copy_tracked_module 'nwg-look' ;;
    local-bin) copy_tracked_module 'local-bin' ;;
    local-apps) copy_tracked_module 'local-apps' ;;
    *)
      printf 'Unsupported module: %s\n' "$module" >&2
      return 2
      ;;
  esac
}

for module in "${selected_modules[@]}"; do
  if ! has_module "$module"; then
    printf 'Unsupported module: %s\n' "$module" >&2
    exit 2
  fi
  run_module "$module"
  echo
done

if $DRY_RUN; then
  echo '[dry-run] planned repo -> live sync complete.'
else
  echo '[done] repo -> live sync complete.'
fi

if [ ${#blocked_sensitive[@]} -gt 0 ]; then
  echo
  echo '[blocked] sensitive-looking files were skipped:'
  printf '  - %s\n' "${blocked_sensitive[@]}"
fi
