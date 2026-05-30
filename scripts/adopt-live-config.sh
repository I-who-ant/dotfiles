#!/usr/bin/env bash
set -euo pipefail

DOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false
AS_DIR=false
selected_module=''
live_rel=''
repo_rel=''

usage() {
  cat <<'USAGE'
Usage: adopt-live-config.sh [options] <module> <live-relative-path> [repo-relative-path]

Copy an existing live config from $HOME into this repo so that future syncs can manage it.

Options:
  -n, --dry-run   Preview only.
  -d, --dir       Treat the source as a directory.
      --list      Print supported modules.
  -h, --help      Show this help.

Examples:
  adopt-live-config.sh zsh .config/zsh/modules/foo.zsh
  adopt-live-config.sh local-apps .local/share/applications/foo.desktop
  adopt-live-config.sh -d hypr .config/hypr/plugins
  adopt-live-config.sh browser-flags .config/chromium-flags.conf browser-flags/.config/chromium-flags.conf
USAGE
}

if [ $# -eq 0 ]; then
  usage >&2
  exit 2
fi

list_modules() {
  "$DOT_ROOT/scripts/sync-module-from-live.sh" --list
}

while (($#)); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      ;;
    -d|--dir)
      AS_DIR=true
      ;;
    --list)
      list_modules
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$selected_module" ]; then
        selected_module="$1"
      elif [ -z "$live_rel" ]; then
        live_rel="$1"
      elif [ -z "$repo_rel" ]; then
        repo_rel="$1"
      else
        echo "unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$selected_module" ] || [ -z "$live_rel" ]; then
  usage >&2
  exit 2
fi

if ! list_modules | grep -Fxq "$selected_module"; then
  echo "unsupported module: $selected_module" >&2
  exit 2
fi

if [ -z "$repo_rel" ]; then
  repo_rel="$live_rel"
fi

# Allow both styles:
#   repo-relative path   -> .config/foo/bar
#   full repo path       -> module/.config/foo/bar
case "$repo_rel" in
  "$selected_module"/*)
    repo_rel="${repo_rel#${selected_module}/}"
    ;;
esac

src="$HOME/$live_rel"
dst="$DOT_ROOT/$selected_module/$repo_rel"
dst_parent="$(dirname "$dst")"

if $AS_DIR; then
  [ -d "$src" ] || { echo "live directory not found: $src" >&2; exit 1; }
else
  [ -f "$src" ] || [ -L "$src" ] || { echo "live file not found: $src" >&2; exit 1; }
fi

if $DRY_RUN; then
  echo "[dry-run] module      : $selected_module"
  echo "[dry-run] live source : $src"
  echo "[dry-run] repo target : $dst"
else
  mkdir -p "$dst_parent"
  if $AS_DIR; then
    mkdir -p "$dst"
    rsync -av \
      --exclude=.git/ \
      --exclude=.DS_Store \
      --exclude=.directory \
      --exclude='*.swp' \
      --exclude='*.zwc' \
      --exclude='*~' \
      --exclude='*.log' \
      --exclude='*.bak' \
      --exclude='*.backup' \
      --exclude='*.broken' \
      --exclude='*.lock' \
      "$src/" "$dst/"
  else
    rsync -av "$src" "$dst"
  fi
fi

cat <<EOF2

[next]
1. inspect: git -C "$DOT_ROOT" diff -- "$selected_module"
2. stage once: git -C "$DOT_ROOT" add "$selected_module"
3. commit when ready
EOF2

case "$selected_module" in
  rime|browser-flags|pavucontrol|git|htop)
    cat <<'EOF2'

[important]
This module uses explicit sync rules.
If you want future live <-> repo sync to include this new path automatically,
you must also update:
- scripts/sync-module-from-live.sh
- scripts/sync-module-to-live.sh
EOF2
    ;;
  *)
    cat <<'EOF2'

[important]
This module uses tracked-file sync.
After you `git add` this path once, future live <-> repo sync will include it automatically.
EOF2
    ;;
esac
