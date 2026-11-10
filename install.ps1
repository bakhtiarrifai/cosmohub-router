# CosmosHub router: one-time setup for Windows. Run from a normal (non-admin) PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# What it does (each step is skipped when already done):
#   1. asks for your CosmosHub API key if COSMOSHUB_API_KEY is not set yet (stored as a user env var)
#   2. allows local scripts for your user (Set-ExecutionPolicy CurrentUser RemoteSigned)
#   3. loads cosmohub.ps1 from your PowerShell profile (claude / codex / claude-sub / codex-sub / cosmohub-status)
#   4. copies the Codex profile to ~/.codex/cosmohub.config.toml
#   5. builds bin\claude-hub.exe (wrapper for the Claude Code VS Code extension)
#   6. starts the router at logon (Startup folder) and now, and stores its local token as COSMOHUB_ROUTER_TOKEN
#   7. adds %USERPROFILE%\.local\bin (where the Claude Code installer puts claude.exe) to your user PATH
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$node = Join-Path $env:ProgramFiles 'nodejs\node.exe'
function Step($msg) { Write-Host "-> $msg" -ForegroundColor Cyan }

if (-not (Test-Path $node)) { throw "Node.js not found at $node. Install Node.js 22+ first (https://nodejs.org)." }

# 1. API key
if (-not [Environment]::GetEnvironmentVariable('COSMOSHUB_API_KEY', 'User')) {
    Step 'CosmosHub API key'
    $k = Read-Host 'CosmosHub API key (sk-cos-...)'
    if (-not $k) { throw 'No key entered.' }
    [Environment]::SetEnvironmentVariable('COSMOSHUB_API_KEY', $k, 'User')
    Remove-Variable k
}
$env:COSMOSHUB_API_KEY = [Environment]::GetEnvironmentVariable('COSMOSHUB_API_KEY', 'User')

# 2. Execution policy
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Undefined', 'Restricted', 'AllSigned')) {
    Step 'Allowing local scripts for your user (RemoteSigned)'
    # When this script runs with -ExecutionPolicy Bypass, PowerShell applies the change but still raises
    # "overridden by a policy defined at a more specific scope". That is expected, so don't stop on it.
    try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop }
    catch { if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') { throw } }
}

# 3. PowerShell profile
$line = ". '$root\cosmohub.ps1'"
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
if (-not (Test-Path $PROFILE) -or -not (Select-String -Path $PROFILE -SimpleMatch $line -Quiet)) {
    Step "Adding the launcher to $PROFILE"
    Add-Content -Path $PROFILE -Value "`r`n# CosmosHub launcher (claude/codex use CosmosHub first)`r`n$line"
}

# 4. Codex profile
$codexDir = Join-Path $HOME '.codex'
New-Item -ItemType Directory -Force $codexDir | Out-Null
Copy-Item (Join-Path $root 'codex\cosmohub.config.toml') $codexDir -Force
Step 'Codex profile installed (~/.codex/cosmohub.config.toml)'

# 5. Wrapper for the Claude Code VS Code extension
& (Join-Path $root 'wrapper\build.ps1')

# 6. Router at logon + now
$startup = [Environment]::GetFolderPath('Startup')
$vbs = Join-Path $startup 'cosmohub-router.vbs'
Set-Content -Path $vbs -Encoding ASCII -Value @"
' Starts the CosmosHub router hidden at logon (installed by cosmohub-router\install.ps1).
CreateObject("WScript.Shell").Run """$node"" ""$root\router.js""", 0, False
"@
Step "Router starts at logon ($vbs)"

$up = $false
try { Invoke-RestMethod 'http://127.0.0.1:4141/health' -TimeoutSec 2 | Out-Null; $up = $true } catch {}
if (-not $up) {
    Start-Process -FilePath $node -ArgumentList "`"$root\router.js`"" -WindowStyle Hidden
    for ($i = 0; $i -lt 40 -and -not $up; $i++) {
        Start-Sleep -Milliseconds 250
        try { Invoke-RestMethod 'http://127.0.0.1:4141/health' -TimeoutSec 2 | Out-Null; $up = $true } catch {}
    }
}
if (-not $up) { throw 'The router did not start. Run: node router.js   to see the error.' }
$token = (Get-Content (Join-Path $HOME '.cosmohub\router-token') -Raw).Trim()
[Environment]::SetEnvironmentVariable('COSMOHUB_ROUTER_TOKEN', $token, 'User')
Step 'Router running; COSMOHUB_ROUTER_TOKEN stored for Codex'

# 7. Claude Code on PATH. The official installer puts claude.exe in ~\.local\bin but does not always add it to
# PATH, which gives "The term 'claude' is not recognized" in a fresh PowerShell (e.g. claude-sub, or no profile).
$claudeBin = Join-Path $HOME '.local\bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $claudeBin) {
    Step "Adding $claudeBin to your user PATH"
    [Environment]::SetEnvironmentVariable('Path', ("$userPath".TrimEnd(';') + ";$claudeBin").TrimStart(';'), 'User')
}
if (-not (Test-Path (Join-Path $claudeBin 'claude.exe'))) {
    Write-Host "Claude Code not found in $claudeBin. Install it with: irm https://claude.ai/install.ps1 | iex" -ForegroundColor Yellow
}

$h = Invoke-RestMethod 'http://127.0.0.1:4141/health?live=1' -TimeoutSec 45
Write-Host ''
Write-Host "Done. CosmosHub usable: $($h.usable) ($($h.models) models)" -ForegroundColor Green
Write-Host 'Open a NEW terminal, then use: claude, codex, claude-sub, codex-sub, cosmohub-status'
Write-Host 'VS Code extensions: see README section 8.'
