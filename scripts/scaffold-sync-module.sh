#!/usr/bin/env bash
set -euo pipefail

DOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_NAME=''
LIVE_REL=''
IS_DIR=true
DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage: scaffold-sync-module.sh [options] <module-name> <live-relative-path>

Scaffold a new module for this dotfiles repo.
This creates the repo directory and module wrapper scripts, then prints the
remaining manual steps needed to wire the module into the main sync scripts.

Options:
  -n, --dry-run   Preview only.
  -f, --file      Treat the live path as a single file target.
  -d, --dir       Treat the live path as a directory target (default).
  -h, --help      Show this help.

Examples:
  scaffold-sync-module.sh foo .config/foo
  scaffold-sync-module.sh -f starship .config/starship.toml
USAGE
}

while (($#)); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      ;;
    -f|--file)
      IS_DIR=false
      ;;
    -d|--dir)
      IS_DIR=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$MODULE_NAME" ]; then
        MODULE_NAME="$1"
      elif [ -z "$LIVE_REL" ]; then
        LIVE_REL="$1"
      else
        echo "unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$MODULE_NAME" ] || [ -z "$LIVE_REL" ]; then
  usage >&2
  exit 2
fi

case "$MODULE_NAME" in
  *[!a-zA-Z0-9._-]*|'')
    echo "invalid module name: $MODULE_NAME" >&2
    exit 2
    ;;
esac

FROM_WRAPPER="$DOT_ROOT/scripts/sync-${MODULE_NAME}-from-live.sh"
TO_WRAPPER="$DOT_ROOT/scripts/sync-${MODULE_NAME}-to-live.sh"
MODULE_ROOT="$DOT_ROOT/$MODULE_NAME"
REPO_TARGET="$MODULE_ROOT/$LIVE_REL"

if $DRY_RUN; then
  echo "[dry-run] module     : $MODULE_NAME"
  echo "[dry-run] live path  : $LIVE_REL"
  echo "[dry-run] repo root  : $MODULE_ROOT"
  echo "[dry-run] repo path  : $REPO_TARGET"
  echo "[dry-run] wrappers   :"
  echo "  - $FROM_WRAPPER"
  echo "  - $TO_WRAPPER"
else
  if $IS_DIR; then
    mkdir -p "$REPO_TARGET"
  else
    mkdir -p "$(dirname "$REPO_TARGET")"
    : > "$REPO_TARGET"
  fi

  cat > "$FROM_WRAPPER" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
"\$SCRIPT_DIR/sync-module-from-live.sh" "$MODULE_NAME" "\$@"
WRAP

  cat > "$TO_WRAPPER" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
"\$SCRIPT_DIR/sync-module-to-live.sh" "$MODULE_NAME" "\$@"
WRAP

  chmod +x "$FROM_WRAPPER" "$TO_WRAPPER"
fi

cat <<EOF2

[next steps]
1. put the live config into the repo path:
   $REPO_TARGET

2. wire the new module into both files:
   - scripts/sync-module-from-live.sh
   - scripts/sync-module-to-live.sh

3. add '$MODULE_NAME' to each script's all_modules array.

4. in sync-module-from-live.sh add a case branch like:
   $MODULE_NAME)
     sync_tracked_module '$MODULE_NAME'
     ;;

5. in sync-module-to-live.sh add a case branch like:
   $MODULE_NAME)
     copy_tracked_module '$MODULE_NAME'
     ;;

6. test both directions:
   ./scripts/sync-${MODULE_NAME}-from-live.sh --dry-run
   ./scripts/sync-${MODULE_NAME}-to-live.sh --dry-run

7. then git add / git commit.
EOF2

if $IS_DIR; then
  cat <<EOF2

[tip]
For a directory module, you can usually import the current live config with:
  rsync -av "\$HOME/$LIVE_REL/" "$REPO_TARGET/"
EOF2
else
  cat <<EOF2

[tip]
For a file module, you can usually import the current live config with:
  cp "\$HOME/$LIVE_REL" "$REPO_TARGET"
EOF2
fi
