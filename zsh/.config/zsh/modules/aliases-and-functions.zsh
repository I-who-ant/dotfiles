alias rm='/usr/bin/safe-rm'
alias mc='my_cli'
alias cccc='claude --dangerously-skip-permissions'
alias cx='codex'
alias c='clear'
alias kill-edge='pkill -f "/opt/microsoft/msedge/msedge"; pkill -f "msedge_crashpad_handler"'

unalias algo 2>/dev/null

function algo() {
    local cli="${ALGO_CLI:-/home/seeback/learingProject/seeback/algorithm-cli/apps/algo/algo}"
    if [[ ! -x "$cli" ]]; then
        echo "algo: not found: $cli" >&2
        return 1
    fi
    command "$cli" "$@"
}



function ps-edge() {
    local pattern='msedge|microsoft-edge|Microsoft Edge|edge_crashpad|msteams|onedrive|microsoft'
    local pids

    pids=("${(@f)$(pgrep -f "$pattern" 2>/dev/null)}")
    if (( ${#pids[@]} == 0 )); then
        echo "No Microsoft-related processes found."
        return 1
    fi

    ps -o pid=,ppid=,etime=,comm=,args= -p "${(j:,:)pids}" \
        | awk '
            {
                pid=$1
                ppid=$2
                etime=$3
                comm=$4

                role="-"
                if (match($0, /--type=[^ ]+/)) {
                    role=substr($0, RSTART+7, RLENGTH-7)
                } else if (index($0, "msedge_crashpad_handler")) {
                    role="crashpad"
                } else if (index($0, "msedge")) {
                    role="browser"
                }

                extra=""
                if (match($0, /--utility-sub-type=[^ ]+/)) {
                    extra=substr($0, RSTART+20, RLENGTH-20)
                } else if (match($0, /--renderer-sub-type=[^ ]+/)) {
                    extra=substr($0, RSTART+20, RLENGTH-20)
                } else if (match($0, /--extension-process/)) {
                    extra="extension"
                }

                printf "%-7s %-7s %-10s %-12s %-18s %s\n", pid, ppid, etime, comm, role, extra
            }
        ' \
        | {
            printf "%-7s %-7s %-10s %-12s %-18s %s\n" "PID" "PPID" "ETIME" "PROC" "ROLE" "EXTRA"
            cat
        }
}

function yay() {
    /usr/bin/yay --sudoflags "-A" "$@"
}

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
