if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    command fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
fi

if [[ $- == *i* ]] && command -v chuck_cow >/dev/null 2>&1; then
    echo "Chuck Norris of the day:"
    chuck_cow
fi
