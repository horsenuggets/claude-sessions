#!/bin/bash
# Install claude-sessions
# Compatible with: bash, zsh, sh (POSIX), Git Bash, WSL

set -e

# Get the repo root (parent of Scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing claude-sessions..."

# Install tmux config
if [ -f ~/.tmux.conf ]; then
    echo "  ~/.tmux.conf already exists, skipping (you can manually copy tmux.conf)"
else
    cp "$REPO_DIR/tmux.conf" ~/.tmux.conf
    echo "  Installed ~/.tmux.conf"
fi

# Create session directory
mkdir -p ~/.claude-sessions/messages
echo "  Created ~/.claude-sessions/"

# Detect shell config file
SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [ -f ~/.zshrc ]; then
    SHELL_RC=~/.zshrc
elif [ -n "$BASH_VERSION" ] || [ -f ~/.bashrc ]; then
    SHELL_RC=~/.bashrc
elif [ -f ~/.profile ]; then
    SHELL_RC=~/.profile
fi

# Add source line to shell config
if [ -n "$SHELL_RC" ]; then
    if grep -q "claude-sessions" "$SHELL_RC" 2>/dev/null; then
        echo "  Already sourced in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "# Claude session management" >> "$SHELL_RC"
        echo "source \"$SCRIPT_DIR/claude-sessions.sh\"" >> "$SHELL_RC"
        echo "  Added source line to $SHELL_RC"
    fi
else
    echo "  Could not detect shell config file. Manually add:"
    echo "    source \"$SCRIPT_DIR/claude-sessions.sh\""
fi

# Check dependencies
if ! command -v tmux &>/dev/null; then
    echo ""
    echo "  Warning: tmux is not installed. Install it with:"
    echo "    brew install tmux"
fi

if ! command -v jq &>/dev/null; then
    echo ""
    echo "  Warning: jq is not installed. Install it with:"
    echo "    brew install jq"
fi

echo ""
if [ -n "$SHELL_RC" ]; then
    echo "Done! Restart your shell or run: source $SHELL_RC"
else
    echo "Done! Restart your shell to apply changes."
fi
echo ""
echo "Quick start:"
echo "  claude-start    # Start a tmux session"
echo "  claude          # Run Claude Code"
echo "  claude-spawn    # Spawn parallel sessions"
echo "  csls            # List active sessions"
