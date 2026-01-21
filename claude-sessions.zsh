# ============================================================================
# Claude Session Management
# ============================================================================
# Enables multiple Claude instances to work in parallel with awareness of each other
#
# Source this file in your .zshrc:
#   source ~/git/claude-sessions/claude-sessions.zsh

export CLAUDE_SESSION_DIR="$HOME/.claude-sessions"
mkdir -p "$CLAUDE_SESSION_DIR/messages" 2>/dev/null

# Generate a unique session ID
_claude_session_id() {
    echo "claude-$$-$(date +%s)"
}

# Register a Claude session
_claude_register() {
    local session_id="$1"
    local cwd="$2"
    local task="$3"
    local session_file="$CLAUDE_SESSION_DIR/$session_id.json"

    cat > "$session_file" << EOF
{
    "id": "$session_id",
    "pid": $$,
    "cwd": "$cwd",
    "task": "$task",
    "started": "$(date -Iseconds)",
    "tmux_window": "$(tmux display-message -p '#I' 2>/dev/null || echo '')"
}
EOF
}

# Deregister a Claude session
_claude_deregister() {
    local session_id="$1"
    rm -f "$CLAUDE_SESSION_DIR/$session_id.json"
    rm -f "$CLAUDE_SESSION_DIR/messages/$session_id"
}

# Wrapped claude command with session tracking
claude-tracked() {
    local session_id=$(_claude_session_id)
    local task="${*:-interactive}"

    _claude_register "$session_id" "$PWD" "$task"
    export CLAUDE_SESSION_ID="$session_id"

    # Run claude with dangerously-skip-permissions, then cleanup
    command claude --dangerously-skip-permissions "$@"
    local exit_code=$?

    _claude_deregister "$session_id"
    return $exit_code
}

# Default claude alias to always skip permissions
alias claude='command claude --dangerously-skip-permissions'

# List all active Claude sessions
claude-ls() {
    echo "Active Claude sessions:"
    echo "─────────────────────────────────────────────────────────────────────"
    local found=0
    setopt local_options nullglob
    for f in "$CLAUDE_SESSION_DIR"/*.json; do
        local data=$(cat "$f")
        local pid=$(echo "$data" | jq -r '.pid')

        # Check if process is still running
        if kill -0 "$pid" 2>/dev/null; then
            found=1
            local id=$(echo "$data" | jq -r '.id')
            local cwd=$(echo "$data" | jq -r '.cwd')
            local task=$(echo "$data" | jq -r '.task')
            local started=$(echo "$data" | jq -r '.started')
            local win=$(echo "$data" | jq -r '.tmux_window // ""')

            printf "%-20s [pid: %s] [win: %s]\n" "$id" "$pid" "$win"
            printf "  ├─ Dir:  %s\n" "$cwd"
            printf "  ├─ Task: %s\n" "$task"
            printf "  └─ Started: %s\n" "$started"
            echo ""
        else
            # Stale session, remove it
            rm -f "$f"
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No active sessions"
    fi
}

# Spawn a new Claude session in a new tmux window
claude-spawn() {
    local dir="${1:-$PWD}"
    local task="${2:-}"
    local window_name="${3:-claude}"

    # Ensure we're in tmux
    if [[ -z "$TMUX" ]]; then
        echo "Error: Not in a tmux session. Start one with: tmux new -s main"
        return 1
    fi

    # Create new window and run claude
    if [[ -n "$task" ]]; then
        tmux new-window -n "$window_name" "cd '$dir' && claude-tracked '$task'"
    else
        tmux new-window -n "$window_name" "cd '$dir' && claude-tracked"
    fi

    echo "Spawned new Claude session in window '$window_name'"
}

# Spawn Claude in a specific repo from ~/git
claude-repo() {
    local repo="$1"
    local task="${2:-}"

    if [[ -z "$repo" ]]; then
        echo "Usage: claude-repo <repo-name> [task]"
        echo "Available repos:"
        ls ~/git | sed 's/^/  /'
        return 1
    fi

    local repo_path="$HOME/git/$repo"
    if [[ ! -d "$repo_path" ]]; then
        echo "Error: Repository not found: $repo_path"
        return 1
    fi

    claude-spawn "$repo_path" "$task" "$repo"
}

# Send a message to another Claude session
claude-send() {
    local target="$1"
    local message="$2"

    if [[ -z "$target" || -z "$message" ]]; then
        echo "Usage: claude-send <session-id> <message>"
        echo "Use 'claude-ls' to see active sessions"
        return 1
    fi

    local msg_file="$CLAUDE_SESSION_DIR/messages/$target"
    echo "{\"from\": \"${CLAUDE_SESSION_ID:-shell}\", \"message\": \"$message\", \"time\": \"$(date -Iseconds)\"}" >> "$msg_file"
    echo "Message sent to $target"
}

# Broadcast a message to all Claude sessions
claude-broadcast() {
    local message="$1"

    if [[ -z "$message" ]]; then
        echo "Usage: claude-broadcast <message>"
        return 1
    fi

    setopt local_options nullglob
    for f in "$CLAUDE_SESSION_DIR"/*.json; do
        local id=$(jq -r '.id' "$f")
        [[ "$id" == "$CLAUDE_SESSION_ID" ]] && continue  # Don't send to self
        claude-send "$id" "$message"
    done
    echo "Broadcast complete"
}

# Read messages for current session
claude-inbox() {
    local inbox="$CLAUDE_SESSION_DIR/messages/${CLAUDE_SESSION_ID:-$$}"
    if [[ -f "$inbox" ]]; then
        echo "Messages:"
        cat "$inbox"
        rm "$inbox"
    else
        echo "No messages"
    fi
}

# Clean up stale sessions
claude-cleanup() {
    local cleaned=0
    setopt local_options nullglob
    for f in "$CLAUDE_SESSION_DIR"/*.json; do
        local pid=$(jq -r '.pid' "$f" 2>/dev/null)
        if ! kill -0 "$pid" 2>/dev/null; then
            local id=$(basename "$f" .json)
            rm -f "$f"
            rm -f "$CLAUDE_SESSION_DIR/messages/$id"
            echo "Removed stale session: $id"
            ((cleaned++))
        fi
    done

    if [[ $cleaned -eq 0 ]]; then
        echo "No stale sessions found"
    else
        echo "Cleaned up $cleaned stale session(s)"
    fi
}

# Kill a specific Claude session
claude-kill() {
    local target="$1"

    if [[ -z "$target" ]]; then
        echo "Usage: claude-kill <session-id>"
        echo "Use 'claude-ls' to see active sessions"
        return 1
    fi

    local session_file="$CLAUDE_SESSION_DIR/$target.json"
    if [[ ! -f "$session_file" ]]; then
        echo "Session not found: $target"
        return 1
    fi

    local pid=$(jq -r '.pid' "$session_file")
    local win=$(jq -r '.tmux_window // ""' "$session_file")

    # Kill the process
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Killed session $target (pid: $pid)"
    fi

    # Cleanup files
    rm -f "$session_file"
    rm -f "$CLAUDE_SESSION_DIR/messages/$target"
}

# Kill all Claude sessions except current
claude-killall() {
    setopt local_options nullglob
    for f in "$CLAUDE_SESSION_DIR"/*.json; do
        local id=$(jq -r '.id' "$f")
        [[ "$id" == "$CLAUDE_SESSION_ID" ]] && continue  # Don't kill self
        claude-kill "$id"
    done
}

# Quick tmux session starter for Claude work
claude-start() {
    if [[ -n "$TMUX" ]]; then
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
alias cls='claude-ls'
alias csp='claude-spawn'
alias crepo='claude-repo'
