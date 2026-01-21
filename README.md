# claude-sessions

Run multiple Claude Code instances in parallel with session awareness and inter-session communication.

## Installation

```bash
git clone https://github.com/horsenuggets/claude-sessions.git ~/git/claude-sessions
cd ~/git/claude-sessions
./install.sh
```

### Dependencies

- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [jq](https://jqlang.github.io/jq/) - JSON processor

```bash
brew install tmux jq
```

## Quick Start

```bash
claude-start          # Start a tmux session
claude                # Run Claude Code (defaults to --dangerously-skip-permissions)
```

## Commands

### Spawning Sessions

| Command | Description |
|---------|-------------|
| `claude-spawn [dir] [task] [name]` | Spawn Claude in new tmux window |
| `claude-repo <repo> [task]` | Spawn Claude in ~/git/repo |
| `csp` | Alias for claude-spawn |
| `crepo` | Alias for claude-repo |

```bash
claude-spawn ~/projects/app "fix the login bug" app
claude-repo testable "add new test helpers"
crepo my-api "implement rate limiting"
```

### Monitoring

| Command | Description |
|---------|-------------|
| `claude-ls` or `cls` | List all active sessions |
| `claude-cleanup` | Remove dead/stale sessions |

### Communication

| Command | Description |
|---------|-------------|
| `claude-send <id> <message>` | Send message to a session |
| `claude-broadcast <message>` | Send to all sessions |
| `claude-inbox` | Read incoming messages |

### Killing Sessions

| Command | Description |
|---------|-------------|
| `claude-kill <id>` | Kill specific session |
| `claude-killall` | Kill all except current |

## tmux Shortcuts

Prefix key: `Ctrl+a` (hold Ctrl, press a, release, then press the next key)

### Windows

| Shortcut | Action |
|----------|--------|
| `Shift+Left` | Previous window |
| `Shift+Right` | Next window |
| `Ctrl+a c` | Create new window |
| `Ctrl+a ,` | Rename current window |
| `Ctrl+a w` | List all windows |
| `Ctrl+a 1-9` | Jump to window by number |
| `Ctrl+a X` | Kill current window |

### Panes

| Shortcut | Action |
|----------|--------|
| `Ctrl+a \|` | Split vertically |
| `Ctrl+a -` | Split horizontally |
| `Alt+Arrow` | Move between panes |
| `Ctrl+a x` | Kill current pane |
| `Ctrl+a z` | Zoom pane (fullscreen toggle) |
| Mouse drag | Resize pane borders |

### Sessions

| Shortcut | Action |
|----------|--------|
| `Ctrl+a d` | Detach (keeps running) |
| `Ctrl+a s` | Switch between sessions |
| `Ctrl+a $` | Rename session |

### Scrolling

| Shortcut | Action |
|----------|--------|
| Mouse scroll | Scroll up/down |
| `Ctrl+a [` | Enter scroll mode |
| `q` | Exit scroll mode |

## Workflows

### Work on multiple repos

```bash
crepo frontend "build the new dashboard"
crepo backend "add API endpoints"
crepo shared "update type definitions"
# Shift+Left/Right to switch between them
```

### Detach and return later

```bash
Ctrl+a d              # Detach from tmux
# Close terminal, go get coffee
tmux attach           # Everything still running
```

### Check what's running

```bash
cls                   # See all Claude sessions
Ctrl+a w              # See all tmux windows
```

## Files

| Path | Description |
|------|-------------|
| `~/.tmux.conf` | tmux configuration |
| `~/.claude-sessions/*.json` | Active session metadata |
| `~/.claude-sessions/messages/` | Inter-session messages |
