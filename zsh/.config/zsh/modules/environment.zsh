export CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1


export EDITOR=code
export ALGO_CLI="${ALGO_CLI:-/home/seeback/learingProject/seeback/algorithm-cli/apps/algo/algo}"
export PATH="$PATH:/opt/android-sdk/platform-tools"
export PATH="$HOME/.local/bin:$PATH"
export SUDO_ASKPASS="$HOME/.local/bin/sudo-askpass-kde"

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
