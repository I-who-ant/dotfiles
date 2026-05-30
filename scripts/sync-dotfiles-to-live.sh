#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
DELETE=false
LIST_ONLY=false
ALL=false
selected_modules=()

# Safe default: same conservative set as live -> repo.
default_modules=(
  rime
  zsh
  local-apps
)

usage() {
  cat <<'USAGE'
Usage: sync-dotfiles-to-live.sh [options] [module ...]

Sync modules from this repo back into live files under $HOME.
If no module is provided, sync only the safe default set:
  rime zsh local-apps

Use --all for every supported module, or pass module names explicitly.

Options:
  -n, --dry-run   Show what would change without writing.
      --delete    Delete live files when matching repo files/directories are missing.
      --list      Print all supported modules.
      --all       Sync all supported modules explicitly.
  -h, --help      Show this help.

Examples:
  sync-dotfiles-to-live.sh
  sync-dotfiles-to-live.sh -n
  sync-dotfiles-to-live.sh rime hypr
  sync-dotfiles-to-live.sh --all --dry-run
  sync-dotfiles-to-live.sh --list
USAGE
}

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
    --all)
      ALL=true
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
  "$SCRIPT_DIR/sync-module-to-live.sh" --list
  exit 0
fi

if $ALL && [ ${#selected_modules[@]} -gt 0 ]; then
  echo '--all cannot be combined with explicit module names.' >&2
  exit 2
fi

if $ALL; then
  mapfile -t selected_modules < <("$SCRIPT_DIR/sync-module-to-live.sh" --list)
elif [ ${#selected_modules[@]} -eq 0 ]; then
  selected_modules=( "${default_modules[@]}" )
fi

forwarded=()
$DRY_RUN && forwarded+=( --dry-run )
$DELETE && forwarded+=( --delete )

"$SCRIPT_DIR/sync-module-to-live.sh" "${forwarded[@]}" "${selected_modules[@]}"
