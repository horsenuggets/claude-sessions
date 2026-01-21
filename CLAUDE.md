# Claude Session Management

This document describes how Claude Code instances can work in parallel and communicate with
each other using the session management system.

## Parallel Work

When a task would benefit from parallel execution, you can spawn additional Claude sessions.
The user must be in a tmux session for this to work.

### Spawning Sessions

To spawn a new Claude session working on a specific task:

```bash
claude-spawn <directory> "<task description>" <window-name>
```

Examples:
```bash
claude-spawn ~/git/my-app "implement the API endpoints" api
claude-spawn ~/git/my-app "write tests for the new feature" tests
claude-repo testable "fix the failing CI checks"
```

### When to Spawn Parallel Sessions

Consider spawning parallel sessions when:
> The user explicitly asks for parallel work
> A task has independent subtasks that can run concurrently
> You need to work on multiple repositories simultaneously
> Long-running tasks could benefit from parallelization

Tell the user to run the spawn command - you cannot run it directly from within Claude Code.

## Inter-Session Communication

Sessions can communicate with each other through a simple message system.

### Checking Other Sessions

To see what other Claude sessions are running:

```bash
claude-ls
```

This shows each session's ID, working directory, task description, and start time.

### Sending Messages

To send a message to another session:

```bash
claude-send <session-id> "<message>"
```

To broadcast to all sessions:

```bash
claude-broadcast "<message>"
```

### Reading Messages

To check for incoming messages:

```bash
claude-inbox
```

### Communication Patterns

Use messages to coordinate work:
> Notify when you finish a dependency another session needs
> Request information from a session working on related code
> Signal completion of your assigned task
> Warn about conflicts or issues discovered

Example coordination:
```bash
# Session working on types finishes
claude-broadcast "Types are updated, you can pull the latest changes"

# Session needing those types checks inbox and responds
claude-inbox
# Then continues with updated types
```

## Session Awareness

Each Claude session has access to:
> `$CLAUDE_SESSION_ID` - The current session's unique identifier
> `~/.claude-sessions/*.json` - Metadata files for all active sessions
> `~/.claude-sessions/messages/` - Message queue files

Session metadata includes:
```json
{
    "id": "claude-12345-1234567890",
    "pid": 12345,
    "cwd": "/Users/chris/git/my-app",
    "task": "implement the API endpoints",
    "started": "2024-01-15T10:30:00-08:00",
    "tmux_window": "2"
}
```

## Best Practices

1. **Use descriptive task names** when spawning - they appear in `claude-ls` output
2. **Check `claude-ls` first** before spawning to see if relevant work is already running
3. **Broadcast completion** when finishing a task that others might depend on
4. **Check inbox periodically** during long tasks to catch coordination messages
5. **Clean up** with `claude-cleanup` to remove stale session entries

## Limitations

> Claude cannot directly spawn new terminal windows - tell the user to run the command
> Messages are simple text, not structured data
> No automatic synchronization - coordination is manual via messages
> Sessions must poll for messages with `claude-inbox`
