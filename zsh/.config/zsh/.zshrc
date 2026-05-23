# Native zsh interactive entrypoint.

typeset -gi _zsh_has_tty=0
if [[ -t 0 && -t 1 ]]; then
    _zsh_has_tty=1
fi

typeset -ga plugins=(
    git
    sudo
)

typeset -ga _omz_paths=(
    "$HOME/.oh-my-zsh"
    "/usr/share/oh-my-zsh"
    "/usr/local/share/oh-my-zsh"
)

typeset -ga _user_zsh_modules=(
    environment.zsh
    toolchains.zsh
    aliases-and-functions.zsh
    conda.zsh
    atuin.zsh
    syntax-highlighting.zsh
    startup.zsh
)

for _omz_path in "${_omz_paths[@]}"; do
    if [[ -d "$_omz_path" ]]; then
        export ZSH="$_omz_path"
        break
    fi
done

export ZSH_THEME="powerlevel10k/powerlevel10k"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"

if (( _zsh_has_tty )) && [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

if (( _zsh_has_tty )) && [[ -r "$HOME/.p10k.zsh" ]]; then
    source "$HOME/.p10k.zsh"
elif (( _zsh_has_tty )) && [[ -r "$ZDOTDIR/.p10k.zsh" ]]; then
    source "$ZDOTDIR/.p10k.zsh"
fi

if (( _zsh_has_tty )) && [[ -r "$ZDOTDIR/completions/fzf.zsh" ]]; then
    source "$ZDOTDIR/completions/fzf.zsh"
fi

if (( _zsh_has_tty )) && [[ -r "$ZDOTDIR/conf.d/binds.zsh" ]]; then
    source "$ZDOTDIR/conf.d/binds.zsh"
fi

if (( _zsh_has_tty )); then
    for _user_zsh_function in "$ZDOTDIR"/functions/*.zsh; do
        [[ -r "$_user_zsh_function" ]] && source "$_user_zsh_function"
    done
fi

for _user_zsh_module in "${_user_zsh_modules[@]}"; do
    if [[ "$_user_zsh_module" == "startup.zsh" ]] && (( ! _zsh_has_tty )); then
        continue
    fi
    if [[ -r "$ZDOTDIR/modules/$_user_zsh_module" ]]; then
        source "$ZDOTDIR/modules/$_user_zsh_module"
    fi
done

unset _omz_path
unset _omz_paths
unset _user_zsh_function
unset _zsh_has_tty
unset _user_zsh_module
unset _user_zsh_modules
