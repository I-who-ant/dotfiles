#!/usr/bin/env zsh

# Native zsh environment layer.
# Keep this file light: environment only, no plugin or prompt loading.

export PATH="$HOME/.local/bin:$PATH"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-$XDG_DATA_HOME:/usr/local/share:/usr/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export LESSHISTFILE="${LESSHISTFILE:-/tmp/less-hist}"
export PARALLEL_HOME="${XDG_CONFIG_HOME}/parallel"
export SCREENRC="${XDG_CONFIG_HOME}/screen/screenrc"
export TERMINFO="${XDG_DATA_HOME}/terminfo"
export TERMINFO_DIRS="${XDG_DATA_HOME}/terminfo:/usr/share/terminfo"
export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
export PYTHON_HISTORY="${XDG_STATE_HOME}/python_history"
export HISTFILE="${HISTFILE:-$ZDOTDIR/.zsh_history}"
export HYPRLAND_CONFIG="${XDG_CONFIG_HOME}/hypr/hyprland.conf"
