# ============================================================================
# Claude Session Management for PowerShell
# ============================================================================
# Enables multiple Claude instances to work in parallel with awareness of each other
#
# Note: tmux is not available on Windows. Parallel sessions work best in WSL.
#
# Source this file in your PowerShell profile:
#   . "$env:USERPROFILE\git\claude-sessions\Scripts\claude-sessions.ps1"

$env:CLAUDE_SESSION_DIR = Join-Path $env:USERPROFILE ".claude-sessions"
$MessagesDir = Join-Path $env:CLAUDE_SESSION_DIR "messages"

if (-not (Test-Path $env:CLAUDE_SESSION_DIR)) {
    New-Item -ItemType Directory -Path $env:CLAUDE_SESSION_DIR -Force | Out-Null
}
if (-not (Test-Path $MessagesDir)) {
    New-Item -ItemType Directory -Path $MessagesDir -Force | Out-Null
}

# Generate a unique session ID
function Get-ClaudeSessionId {
    "claude-$PID-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
}

# Register a Claude session
function Register-ClaudeSession {
    param(
        [string]$SessionId,
        [string]$Cwd,
        [string]$Task
    )

    $SessionFile = Join-Path $env:CLAUDE_SESSION_DIR "$SessionId.json"
    $Session = @{
        id = $SessionId
        pid = $PID
        cwd = $Cwd
        task = $Task
        started = (Get-Date -Format "o")
        tmux_window = ""
    }
    $Session | ConvertTo-Json | Set-Content -Path $SessionFile
}

# Deregister a Claude session
function Unregister-ClaudeSession {
    param([string]$SessionId)

    $SessionFile = Join-Path $env:CLAUDE_SESSION_DIR "$SessionId.json"
    $MessageFile = Join-Path $env:CLAUDE_SESSION_DIR "messages\$SessionId"

    Remove-Item -Path $SessionFile -ErrorAction SilentlyContinue
    Remove-Item -Path $MessageFile -ErrorAction SilentlyContinue
}

# Wrapped claude command with session tracking
function Invoke-ClaudeTracked {
    param([Parameter(ValueFromRemainingArguments)]$Arguments)

    $SessionId = Get-ClaudeSessionId
    $Task = if ($Arguments) { $Arguments -join " " } else { "interactive" }

    Register-ClaudeSession -SessionId $SessionId -Cwd $PWD -Task $Task
    $env:CLAUDE_SESSION_ID = $SessionId

    try {
        if (Get-Command "claude-terminal" -ErrorAction SilentlyContinue) {
            & claude-terminal @Arguments
        } else {
            & claude --dangerously-skip-permissions @Arguments
        }
    } finally {
        Unregister-ClaudeSession -SessionId $SessionId
    }
}

# Alias for claude with skip permissions
function Invoke-Claude {
    param([Parameter(ValueFromRemainingArguments)]$Arguments)
    & claude --dangerously-skip-permissions @Arguments
}

# List all active Claude sessions
function Get-ClaudeSessions {
    Write-Host "Active Claude sessions:"
    Write-Host "─────────────────────────────────────────────────────────────────────"

    $Found = $false
    $SessionFiles = Get-ChildItem -Path $env:CLAUDE_SESSION_DIR -Filter "*.json" -ErrorAction SilentlyContinue

    foreach ($File in $SessionFiles) {
        try {
            $Data = Get-Content $File.FullName | ConvertFrom-Json
            $Process = Get-Process -Id $Data.pid -ErrorAction SilentlyContinue

            if ($Process) {
                $Found = $true
                Write-Host ("{0,-20} [pid: {1}]" -f $Data.id, $Data.pid)
                Write-Host "  ├─ Dir:  $($Data.cwd)"
                Write-Host "  ├─ Task: $($Data.task)"
                Write-Host "  └─ Started: $($Data.started)"
                Write-Host ""
            } else {
                # Stale session, remove it
                Remove-Item $File.FullName -Force
            }
        } catch {
            # Invalid JSON, remove it
            Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $Found) {
        Write-Host "No active sessions"
    }
}

# Send a message to another Claude session
function Send-ClaudeMessage {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Message
    )

    $MessageFile = Join-Path $env:CLAUDE_SESSION_DIR "messages\$Target"
    $Timestamp = Get-Date -Format "o"
    $From = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "shell" }

    $Msg = @{
        from = $From
        message = $Message
        time = $Timestamp
    } | ConvertTo-Json -Compress

    Add-Content -Path $MessageFile -Value $Msg
    Write-Host "Message sent to $Target"
}

# Broadcast a message to all Claude sessions
function Send-ClaudeBroadcast {
    param([Parameter(Mandatory)][string]$Message)

    $SessionFiles = Get-ChildItem -Path $env:CLAUDE_SESSION_DIR -Filter "*.json" -ErrorAction SilentlyContinue

    foreach ($File in $SessionFiles) {
        try {
            $Data = Get-Content $File.FullName | ConvertFrom-Json
            if ($Data.id -ne $env:CLAUDE_SESSION_ID) {
                Send-ClaudeMessage -Target $Data.id -Message $Message
            }
        } catch {}
    }
    Write-Host "Broadcast complete"
}

# Read messages for current session
function Get-ClaudeInbox {
    $Inbox = Join-Path $env:CLAUDE_SESSION_DIR "messages\$($env:CLAUDE_SESSION_ID ?? $PID)"

    if (Test-Path $Inbox) {
        Write-Host "Messages:"
        Get-Content $Inbox
        Remove-Item $Inbox
    } else {
        Write-Host "No messages"
    }
}

# Clean up stale sessions
function Clear-ClaudeSessions {
    $Cleaned = 0
    $SessionFiles = Get-ChildItem -Path $env:CLAUDE_SESSION_DIR -Filter "*.json" -ErrorAction SilentlyContinue

    foreach ($File in $SessionFiles) {
        try {
            $Data = Get-Content $File.FullName | ConvertFrom-Json
            $Process = Get-Process -Id $Data.pid -ErrorAction SilentlyContinue

            if (-not $Process) {
                $Id = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
                Remove-Item $File.FullName -Force
                $MessageFile = Join-Path $env:CLAUDE_SESSION_DIR "messages\$Id"
                Remove-Item $MessageFile -Force -ErrorAction SilentlyContinue
                Write-Host "Removed stale session: $Id"
                $Cleaned++
            }
        } catch {}
    }

    if ($Cleaned -eq 0) {
        Write-Host "No stale sessions found"
    } else {
        Write-Host "Cleaned up $Cleaned stale session(s)"
    }
}

# Kill a specific Claude session
function Stop-ClaudeSession {
    param([Parameter(Mandatory)][string]$Target)

    $SessionFile = Join-Path $env:CLAUDE_SESSION_DIR "$Target.json"

    if (-not (Test-Path $SessionFile)) {
        Write-Host "Session not found: $Target"
        return
    }

    try {
        $Data = Get-Content $SessionFile | ConvertFrom-Json
        Stop-Process -Id $Data.pid -Force -ErrorAction SilentlyContinue
        Write-Host "Killed session $Target (pid: $($Data.pid))"
    } catch {}

    Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue
    $MessageFile = Join-Path $env:CLAUDE_SESSION_DIR "messages\$Target"
    Remove-Item $MessageFile -Force -ErrorAction SilentlyContinue
}

# Start Claude (no tmux on Windows)
function Start-Claude {
    Write-Host "Starting Claude..."
    Write-Host "Note: tmux is not available on Windows. For parallel sessions, use WSL."
    Invoke-ClaudeTracked
}

# Aliases
Set-Alias -Name claude -Value Invoke-Claude
Set-Alias -Name claude-tracked -Value Invoke-ClaudeTracked
Set-Alias -Name claude-ls -Value Get-ClaudeSessions
Set-Alias -Name csls -Value Get-ClaudeSessions
Set-Alias -Name claude-send -Value Send-ClaudeMessage
Set-Alias -Name claude-broadcast -Value Send-ClaudeBroadcast
Set-Alias -Name claude-inbox -Value Get-ClaudeInbox
Set-Alias -Name claude-cleanup -Value Clear-ClaudeSessions
Set-Alias -Name claude-kill -Value Stop-ClaudeSession
Set-Alias -Name claude-start -Value Start-Claude
