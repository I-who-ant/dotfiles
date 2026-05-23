function command_not_found_handler {
    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
    printf "${green}zsh${reset}: command ${purple}NOT${reset} found: ${bright}'%s'${reset}\n" "$1"

    if command -v yay >/dev/null 2>&1; then
        printf "${bright}Searching packages that provide '${green}%s${bright}'...\n${reset}" "${1}"
        yay -F "/usr/bin/$1" 2>/dev/null || \
            printf "${bright}${green}[ %s ]${reset} ${purple}NOT${reset} found in the package file database.\n" "${1}"
    fi

    return 127
}

# Function to display a slow load warning
# warn when shell startup becomes abnormally slow
function _slow_load_warning {
    local lock_file="/tmp/.zsh_slow_load_warning.lock"
    local load_time=$SECONDS

    # Check if the lock file exists
    if [[ ! -f $lock_file ]]; then
        # Create the lock file
        touch $lock_file

        # Display the warning if load time exceeds the limit
        time_limit=3
        if ((load_time > time_limit)); then
            cat <<EOF
    ⚠️ Warning: Shell startup took more than ${time_limit} seconds. Consider optimizing your configuration.
        1. This might be due to slow plugins, slow initialization scripts.
        2. Duplicate plugins initialization.
            - keep oh-my-zsh loading in one place only.
            - avoid re-sourcing ~/.zshrc from hooks or deferred loaders.
        3. Check modules/*.zsh and functions/*.zsh for heavy startup work.

EOF
        fi
    fi
}

# Function to handle initialization errors
function handle_init_error {
    if [[ $? -ne 0 ]]; then
        echo "Error during initialization. Please check your configuration."
    fi
}


function no_such_file_or_directory_handler {
    local red='\e[1;31m' reset='\e[0m'
    printf "${red}zsh: no such file or directory: %s${reset}\n" "$1"
    return 127
}

# ------------------------------------------------------------

# # Warn if the shell is slow to load
# add-zsh-hook -Uz precmd _slow_load_warning
