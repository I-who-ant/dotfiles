#!/bin/sh
LOG="$HOME/.emacs-stderr.log"
[ -f "$LOG" ] && mv -f "$LOG" "$LOG.prev"
{
  echo "=== emacs start: $(date -Iseconds) pid=$$ args=$* ==="
} >"$LOG"
exec emacs "$@" >>"$LOG" 2>&1
