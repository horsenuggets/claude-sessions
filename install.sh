#!/bin/bash
# Install claude-sessions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing claude-sessions..."

# Install tmux config
if [[ -f ~/.tmux.conf ]]; then
    echo "  ~/.tmux.conf already exists, skipping (you can manually copy tmux.conf)"
else
    cp "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
    echo "  Installed ~/.tmux.conf"
fi

# Create session directory
mkdir -p ~/.claude-sessions/messages
echo "  Created ~/.claude-sessions/"

# Check if already sourced in .zshrc
if grep -q "claude-sessions.zsh" ~/.zshrc 2>/dev/null; then
    echo "  Already sourced in ~/.zshrc"
else
    echo "" >> ~/.zshrc
    echo "# Claude session management" >> ~/.zshrc
    echo "source \"$SCRIPT_DIR/claude-sessions.zsh\"" >> ~/.zshrc
    echo "  Added source line to ~/.zshrc"
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
echo "Done! Restart your shell or run: source ~/.zshrc"
echo ""
echo "Quick start:"
echo "  claude-start    # Start a tmux session"
echo "  claude          # Run Claude Code"
echo "  claude-spawn    # Spawn parallel sessions"
echo "  cls             # List active sessions"
