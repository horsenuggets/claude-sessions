# Install claude-sessions for PowerShell
# Note: tmux is not natively available on Windows, but works in WSL

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

Write-Host "Installing claude-sessions..."

# Create session directory
$SessionDir = Join-Path $env:USERPROFILE ".claude-sessions"
$MessagesDir = Join-Path $SessionDir "messages"
if (-not (Test-Path $SessionDir)) {
    New-Item -ItemType Directory -Path $SessionDir -Force | Out-Null
    New-Item -ItemType Directory -Path $MessagesDir -Force | Out-Null
    Write-Host "  Created $SessionDir"
} else {
    Write-Host "  $SessionDir already exists"
}

# Check for PowerShell profile
$ProfileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Check if already sourced in profile
$SourceLine = ". `"$ScriptDir\claude-sessions.ps1`""
if (Test-Path $PROFILE) {
    $ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($ProfileContent -match "claude-sessions\.ps1") {
        Write-Host "  Already sourced in PowerShell profile"
    } else {
        Add-Content -Path $PROFILE -Value "`n# Claude session management"
        Add-Content -Path $PROFILE -Value $SourceLine
        Write-Host "  Added source line to $PROFILE"
    }
} else {
    "# Claude session management" | Out-File -FilePath $PROFILE
    $SourceLine | Add-Content -Path $PROFILE
    Write-Host "  Created $PROFILE with source line"
}

# Check dependencies
Write-Host ""
if (-not (Get-Command "jq" -ErrorAction SilentlyContinue)) {
    Write-Host "  Warning: jq is not installed. Install it with:"
    Write-Host "    winget install jqlang.jq"
    Write-Host "    # or: choco install jq"
}

Write-Host ""
Write-Host "Done! Restart PowerShell to apply changes."
Write-Host ""
Write-Host "Quick start:"
Write-Host "  claude-start    # Start Claude (tmux not available on Windows)"
Write-Host "  claude          # Run Claude Code"
Write-Host "  csls            # List active sessions"
Write-Host ""
Write-Host "Note: Parallel sessions with tmux require WSL on Windows."
