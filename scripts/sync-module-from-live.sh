#!/usr/bin/env bash
set -euo pipefail

DOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=false
DELETE=false
LIST_ONLY=false
selected_modules=()
pathspecs=()
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
  qt6ct
  nwg-look
  local-bin
  local-apps
)

usage() {
  cat <<'USAGE'
Usage: sync-module-from-live.sh [options] <module> [module ...]

Sync one or more dotfiles modules from live files under $HOME back into this repo.

Options:
  -n, --dry-run   Show what would change without writing.
      --delete    Delete repo copies when matching live files/directories are missing.
      --list      Print all supported modules.
  -h, --help      Show this help.

Examples:
  sync-module-from-live.sh rime
  sync-module-from-live.sh -n hypr zsh
  sync-module-from-live.sh --list
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

  # Hard-coded secret assignments are blocked, but public plumbing such as
  # OBS_PASSWORD_FILE=..., ${OBS_PASSWORD:-}, or source private.env is allowed.
  # Keep this conservative: it is a guardrail, not a full secret scanner.
  grep -nE \
    '(^|[[:space:]]|export[[:space:]]+)(env_key|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|[A-Z0-9_]*(TOKEN|SECRET|PASSWORD))[[:space:]]*=[[:space:]]*["'"'']?[^"'"''${[:space:]]' \
    "$path" >/dev/null 2>&1 && return 0
  grep -nE '/tmp/\.mount_[^/]+/' "$path" >/dev/null 2>&1 && return 0
  return 1
}

normalize_repo_file() {
  local repo_rel="$1"
  local dst="$DOT_ROOT/$repo_rel"

  case "$repo_rel" in
    zsh/.config/zsh/modules/environment.zsh)
      ensure_zsh_private_env_loader "$dst"
      ;;
  esac
}

ensure_zsh_private_env_loader() {
  local file="$1"
  [ -f "$file" ] || return 0

  local marker_start='# >>> private env loader >>>'
  local marker_end='# <<< private env loader <<<'
  local tmp
  tmp="$(mktemp)"

  awk -v start="$marker_start" -v end="$marker_end" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip       { print }
  ' "$file" > "$tmp"

  cat >> "$tmp" <<'EOF'

# >>> private env loader >>>
typeset -ga _zsh_private_env_files=(
    "/home/seeback/learingProject/seeback/some-keys/zsh.env"
    "$HOME/.config/zsh/private.env"
)

for _zsh_private_env_file in "${_zsh_private_env_files[@]}"; do
    if [[ -r "$_zsh_private_env_file" ]]; then
        # shellcheck disable=SC1090
        source "$_zsh_private_env_file"
    fi
done

unset _zsh_private_env_file
unset _zsh_private_env_files
# <<< private env loader <<<
EOF

  mv "$tmp" "$file"
}

sync_file() {
  local live_rel="$1"
  local repo_rel="$2"
  local live="$HOME/$live_rel"
  local dst="$DOT_ROOT/$repo_rel"
  local args=( "${common_rsync_args[@]}" )
  $DRY_RUN && args+=( --dry-run )

  mkdir -p "$(dirname "$dst")"

  if [ -f "$live" ] || [ -L "$live" ]; then
    if is_sensitive_file "$live"; then
      echo "blocked sensitive file: $live" >&2
      blocked_sensitive+=( "$repo_rel <= $live_rel" )
      return
    fi
    rsync "${args[@]}" "$live" "$dst"
    if ! $DRY_RUN; then
      normalize_repo_file "$repo_rel"
    fi
    return
  fi

  echo "warning: missing live file: $live" >&2
  if $DELETE && [ -e "$dst" ]; then
    if $DRY_RUN; then
      echo "would delete file: $dst"
    else
      rm -f "$dst"
      echo "deleted file: $dst"
    fi
  fi
}

sync_tracked_module() {
  local module="$1"
  local repo_rel
  while IFS= read -r -d '' repo_rel; do
    case "$repo_rel" in
      */README.md|*/TUNING.md|*/REGRESSION.md) continue ;;
    esac
    sync_file "${repo_rel#*/}" "$repo_rel"
  done < <(git -C "$DOT_ROOT" ls-files -z -- "$module")
}

sync_tree() {
  local live_rel="$1"
  local repo_rel="$2"
  local live="$HOME/$live_rel"
  local dst="$DOT_ROOT/$repo_rel"
  local args=( "${common_rsync_args[@]}" )
  $DRY_RUN && args+=( --dry-run )
  $DELETE && args+=( --delete )

  mkdir -p "$dst"

  if [ -d "$live" ]; then
    rsync "${args[@]}" "$live/" "$dst/"
    return
  fi

  echo "warning: missing live directory: $live" >&2
  if $DELETE && [ -e "$dst" ]; then
    if $DRY_RUN; then
      echo "would delete tree: $dst"
    else
      rm -rf "$dst"
      echo "deleted tree: $dst"
    fi
  fi
}

sync_rime() {
  local base_live='.local/share/fcitx5/rime'
  local base_repo='rime/.local/share/fcitx5/rime'
  local file
  for file in \
    default.custom.yaml \
    rime_ice.custom.yaml \
    tech_phrase.txt \
    mytech.dict.yaml \
    rime_ice_seeback.dict.yaml; do
    sync_file "$base_live/$file" "$base_repo/$file"
  done
}

run_module() {
  local module="$1"
  printf '==> sync %s\n' "$module"
  pathspecs+=( "$module" )
  case "$module" in
    emacs)
      sync_tracked_module 'emacs'
      ;;
    emacs-local)
      sync_tracked_module 'emacs-local'
      ;;
    zsh)
      sync_tracked_module 'zsh'
      ;;
    rofi)
      sync_tracked_module 'rofi'
      ;;
    hypr)
      sync_tracked_module 'hypr'
      ;;
    waybar)
      sync_tracked_module 'waybar'
      ;;
    fastfetch)
      sync_tracked_module 'fastfetch'
      ;;
    kitty)
      sync_tracked_module 'kitty'
      ;;
    fcitx5)
      sync_tracked_module 'fcitx5'
      ;;
    rime)
      sync_rime
      ;;
    gtk-3.0)
      sync_tracked_module 'gtk-3.0'
      ;;
    gtk-4.0)
      sync_tracked_module 'gtk-4.0'
      ;;
    autostart)
      sync_tracked_module 'autostart'
      ;;
    wlogout)
      sync_tracked_module 'wlogout'
      ;;
    mako)
      sync_tracked_module 'mako'
      ;;
    btop)
      sync_tracked_module 'btop'
      ;;
    mpv)
      sync_tracked_module 'mpv'
      ;;
    flameshot)
      sync_tracked_module 'flameshot'
      ;;
    browser-flags)
      sync_file '.config/chrome-flags.conf' 'browser-flags/.config/chrome-flags.conf'
      sync_file '.config/chromium-flags.conf' 'browser-flags/.config/chromium-flags.conf'
      sync_file '.config/electron-flags.conf' 'browser-flags/.config/electron-flags.conf'
      sync_file '.config/microsoft-edge-flags.conf' 'browser-flags/.config/microsoft-edge-flags.conf'
      ;;
    pavucontrol)
      sync_file '.config/pavucontrol.ini' 'pavucontrol/.config/pavucontrol.ini'
      ;;
    xsettingsd)
      sync_tracked_module 'xsettingsd'
      ;;
    xdg-desktop-portal)
      sync_tracked_module 'xdg-desktop-portal'
      ;;
    git)
      sync_file '.config/git/ignore' 'git/.config/git/ignore'
      ;;
    cava)
      sync_tracked_module 'cava'
      ;;
    htop)
      sync_file '.config/htop/htoprc' 'htop/.config/htop/htoprc'
      ;;
    atuin)
      sync_tracked_module 'atuin'
      ;;
    ripgrep-all)
      sync_tracked_module 'ripgrep-all'
      ;;
    glow)
      sync_tracked_module 'glow'
      ;;
    niri)
      sync_tracked_module 'niri'
      ;;
    systemd-user)
      sync_tracked_module 'systemd-user'
      ;;
    kvantum)
      sync_tracked_module 'kvantum'
      ;;
    foot)
      sync_tracked_module 'foot'
      ;;
    qt6ct)
      sync_tracked_module 'qt6ct'
      ;;
    nwg-look)
      sync_tracked_module 'nwg-look'
      ;;
    local-bin)
      sync_tracked_module 'local-bin'
      ;;
    local-apps)
      sync_tracked_module 'local-apps'
      ;;
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
  echo '[dry-run] repository status after planned sync:'
else
  echo '[done] repository status after sync:'
fi

if [ ${#blocked_sensitive[@]} -gt 0 ]; then
  echo
  echo '[blocked] sensitive-looking files were skipped:'
  printf '  - %s\n' "${blocked_sensitive[@]}"
fi

git -C "$DOT_ROOT" status --short -- "${pathspecs[@]}"

echo
if $DRY_RUN; then
  echo '[dry-run] diff preview:'
else
  echo '[diff] selected modules:'
fi

git -C "$DOT_ROOT" diff -- "${pathspecs[@]}"
