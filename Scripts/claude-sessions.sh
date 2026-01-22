# ============================================================================
# Claude Session Management
# ============================================================================
# Enables multiple Claude instances to work in parallel with awareness of each other
#
# Compatible with: bash, zsh, sh (POSIX), Git Bash, WSL
#
# Source this file in your shell config:
#   source ~/git/claude-sessions/claude-sessions.sh

export CLAUDE_SESSION_DIR="${HOME}/.claude-sessions"
mkdir -p "${CLAUDE_SESSION_DIR}/messages" 2>/dev/null

# Generate a unique session ID
_claude_session_id() {
    echo "claude-$$-$(date +%s)"
}

# Register a Claude session
_claude_register() {
    _cs_session_id="$1"
    _cs_cwd="$2"
    _cs_task="$3"
    _cs_session_file="${CLAUDE_SESSION_DIR}/${_cs_session_id}.json"
    _cs_tmux_window=""

    if [ -n "$TMUX" ]; then
        _cs_tmux_window=$(tmux display-message -p '#I' 2>/dev/null || echo '')
    fi

    # Use printf for POSIX compatibility (no here-doc)
    printf '{\n    "id": "%s",\n    "pid": %s,\n    "cwd": "%s",\n    "task": "%s",\n    "started": "%s",\n    "tmux_window": "%s"\n}\n' \
        "$_cs_session_id" "$$" "$_cs_cwd" "$_cs_task" "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)" "$_cs_tmux_window" \
        > "$_cs_session_file"
}

# Deregister a Claude session
_claude_deregister() {
    _cs_session_id="$1"
    rm -f "${CLAUDE_SESSION_DIR}/${_cs_session_id}.json"
    rm -f "${CLAUDE_SESSION_DIR}/messages/${_cs_session_id}"
}

# Wrapped claude command with session tracking
# Uses claude-terminal if available, otherwise falls back to claude CLI
claude-tracked() {
    _cs_session_id=$(_claude_session_id)
    _cs_task="${*:-interactive}"

    _claude_register "$_cs_session_id" "$PWD" "$_cs_task"
    export CLAUDE_SESSION_ID="$_cs_session_id"

    _cs_exit_code=0
    if command -v claude-terminal >/dev/null 2>&1; then
        # Use claude-terminal for better UX
        command claude-terminal "$@"
        _cs_exit_code=$?
    else
        # Fall back to regular claude CLI
        command claude --dangerously-skip-permissions "$@"
        _cs_exit_code=$?
    fi

    _claude_deregister "$_cs_session_id"
    return $_cs_exit_code
}

# Default claude alias to always skip permissions
alias claude='command claude --dangerously-skip-permissions'

# List all active Claude sessions
claude-ls() {
    echo "Active Claude sessions:"
    echo "─────────────────────────────────────────────────────────────────────"
    _cs_found=0

    for _cs_f in "${CLAUDE_SESSION_DIR}"/*.json; do
        [ -e "$_cs_f" ] || continue
        _cs_data=$(cat "$_cs_f")
        _cs_pid=$(echo "$_cs_data" | jq -r '.pid')

        # Check if process is still running
        if kill -0 "$_cs_pid" 2>/dev/null; then
            _cs_found=1
            _cs_id=$(echo "$_cs_data" | jq -r '.id')
            _cs_cwd=$(echo "$_cs_data" | jq -r '.cwd')
            _cs_task=$(echo "$_cs_data" | jq -r '.task')
            _cs_started=$(echo "$_cs_data" | jq -r '.started')
            _cs_win=$(echo "$_cs_data" | jq -r '.tmux_window // ""')

            printf "%-20s [pid: %s] [win: %s]\n" "$_cs_id" "$_cs_pid" "$_cs_win"
            printf "  ├─ Dir:  %s\n" "$_cs_cwd"
            printf "  ├─ Task: %s\n" "$_cs_task"
            printf "  └─ Started: %s\n" "$_cs_started"
            echo ""
        else
            # Stale session, remove it
            rm -f "$_cs_f"
        fi
    done

    if [ "$_cs_found" -eq 0 ]; then
        echo "No active sessions"
    fi
}

# Spawn a new Claude session in a new tmux window
claude-spawn() {
    _cs_dir="${1:-$PWD}"
    _cs_task="${2:-}"
    _cs_window_name="${3:-claude}"

    # Ensure we're in tmux
    if [ -z "$TMUX" ]; then
        echo "Error: Not in a tmux session. Start one with: tmux new -s main"
        return 1
    fi

    # Create new window and run claude
    if [ -n "$_cs_task" ]; then
        tmux new-window -n "$_cs_window_name" "cd '$_cs_dir' && claude-tracked '$_cs_task'"
    else
        tmux new-window -n "$_cs_window_name" "cd '$_cs_dir' && claude-tracked"
    fi

    echo "Spawned new Claude session in window '$_cs_window_name'"
}

# Spawn Claude in a specific repo from ~/git
claude-repo() {
    _cs_repo="$1"
    _cs_task="${2:-}"

    if [ -z "$_cs_repo" ]; then
        echo "Usage: claude-repo <repo-name> [task]"
        echo "Available repos:"
        ls ~/git | sed 's/^/  /'
        return 1
    fi

    _cs_repo_path="${HOME}/git/${_cs_repo}"
    if [ ! -d "$_cs_repo_path" ]; then
        echo "Error: Repository not found: $_cs_repo_path"
        return 1
    fi

    claude-spawn "$_cs_repo_path" "$_cs_task" "$_cs_repo"
}

# Send a message to another Claude session
claude-send() {
    _cs_target="$1"
    _cs_message="$2"

    if [ -z "$_cs_target" ] || [ -z "$_cs_message" ]; then
        echo "Usage: claude-send <session-id> <message>"
        echo "Use 'claude-ls' to see active sessions"
        return 1
    fi

    _cs_msg_file="${CLAUDE_SESSION_DIR}/messages/${_cs_target}"
    _cs_timestamp=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
    echo "{\"from\": \"${CLAUDE_SESSION_ID:-shell}\", \"message\": \"$_cs_message\", \"time\": \"$_cs_timestamp\"}" >> "$_cs_msg_file"
    echo "Message sent to $_cs_target"
}

# Broadcast a message to all Claude sessions
claude-broadcast() {
    _cs_message="$1"

    if [ -z "$_cs_message" ]; then
        echo "Usage: claude-broadcast <message>"
        return 1
    fi

    for _cs_f in "${CLAUDE_SESSION_DIR}"/*.json; do
        [ -e "$_cs_f" ] || continue
        _cs_id=$(jq -r '.id' "$_cs_f")
        [ "$_cs_id" = "$CLAUDE_SESSION_ID" ] && continue  # Don't send to self
        claude-send "$_cs_id" "$_cs_message"
    done
    echo "Broadcast complete"
}

# Read messages for current session
claude-inbox() {
    _cs_inbox="${CLAUDE_SESSION_DIR}/messages/${CLAUDE_SESSION_ID:-$$}"
    if [ -f "$_cs_inbox" ]; then
        echo "Messages:"
        cat "$_cs_inbox"
        rm "$_cs_inbox"
    else
        echo "No messages"
    fi
}

# Clean up stale sessions
claude-cleanup() {
    _cs_cleaned=0
    for _cs_f in "${CLAUDE_SESSION_DIR}"/*.json; do
        [ -e "$_cs_f" ] || continue
        _cs_pid=$(jq -r '.pid' "$_cs_f" 2>/dev/null)
        if ! kill -0 "$_cs_pid" 2>/dev/null; then
            _cs_id=$(basename "$_cs_f" .json)
            rm -f "$_cs_f"
            rm -f "${CLAUDE_SESSION_DIR}/messages/${_cs_id}"
            echo "Removed stale session: $_cs_id"
            _cs_cleaned=$((_cs_cleaned + 1))
        fi
    done

    if [ "$_cs_cleaned" -eq 0 ]; then
        echo "No stale sessions found"
    else
        echo "Cleaned up $_cs_cleaned stale session(s)"
    fi
}

# Kill a specific Claude session
claude-kill() {
    _cs_target="$1"

    if [ -z "$_cs_target" ]; then
        echo "Usage: claude-kill <session-id>"
        echo "Use 'claude-ls' to see active sessions"
        return 1
    fi

    _cs_session_file="${CLAUDE_SESSION_DIR}/${_cs_target}.json"
    if [ ! -f "$_cs_session_file" ]; then
        echo "Session not found: $_cs_target"
        return 1
    fi

    _cs_pid=$(jq -r '.pid' "$_cs_session_file")

    # Kill the process
    if kill -0 "$_cs_pid" 2>/dev/null; then
        kill "$_cs_pid"
        echo "Killed session $_cs_target (pid: $_cs_pid)"
    fi

    # Cleanup files
    rm -f "$_cs_session_file"
    rm -f "${CLAUDE_SESSION_DIR}/messages/${_cs_target}"
}

# Kill all Claude sessions except current
claude-killall() {
    for _cs_f in "${CLAUDE_SESSION_DIR}"/*.json; do
        [ -e "$_cs_f" ] || continue
        _cs_id=$(jq -r '.id' "$_cs_f")
        [ "$_cs_id" = "$CLAUDE_SESSION_ID" ] && continue  # Don't kill self
        claude-kill "$_cs_id"
    done
}

# Quick tmux session starter for Claude work
claude-start() {
    if [ -n "$TMUX" ]; then
        echo "Already in tmux session"
        return 0
    fi

    # Check if session exists
    if tmux has-session -t claude 2>/dev/null; then
        tmux attach -t claude
    else
        tmux new-session -s claude
    fi
}

# Aliases for convenience
alias csls='claude-ls'
alias csp='claude-spawn'
alias crepo='claude-repo'
