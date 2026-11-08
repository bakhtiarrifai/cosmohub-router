# CosmosHub launcher. Dot-sourced from the PowerShell profile; defines:
#   claude / codex          CosmosHub first (via the local router), subscription if CosmosHub can't serve
#   claude-sub / codex-sub  always the subscription
#   cosmohub-status         router health, models, recent routing log
# If CosmosHub's balance runs out mid-session, exit the tool and it resumes on the subscription
# (claude --continue / codex resume --last).

$global:CosmoHubDir   = $PSScriptRoot
$global:CosmoHubUrl   = 'http://127.0.0.1:4141'
$global:CosmoHubState = Join-Path $HOME '.cosmohub'
$global:CosmoHubNode  = 'C:\Program Files\nodejs\node.exe'
$global:CosmoHubClaude = Join-Path $HOME '.local\bin\claude.exe'
$global:CosmoHubCodexJs = Join-Path $env:APPDATA 'npm\node_modules\@openai\codex\bin\codex.js'

function Start-CosmoHubRouter {
    try { Invoke-RestMethod "$CosmoHubUrl/health" -TimeoutSec 2 | Out-Null; return $true } catch {}
    if (-not $env:COSMOSHUB_API_KEY) {
        $k = [Environment]::GetEnvironmentVariable('COSMOSHUB_API_KEY', 'User')
        if (-not $k) { return $false }
        $env:COSMOSHUB_API_KEY = $k
    }
    Start-Process -FilePath $CosmoHubNode -ArgumentList "`"$CosmoHubDir\router.js`"" -WindowStyle Hidden
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        try { Invoke-RestMethod "$CosmoHubUrl/health" -TimeoutSec 2 | Out-Null; return $true } catch {}
    }
    return $false
}

function Get-CosmoHubHealth {
    if (-not (Start-CosmoHubRouter)) { return [pscustomobject]@{ usable = $false; reason = 'router could not start (is COSMOSHUB_API_KEY set?)' } }
    try { return Invoke-RestMethod "$CosmoHubUrl/health?live=1" -TimeoutSec 45 }
    catch { return [pscustomobject]@{ usable = $false; reason = "router health check failed: $($_.Exception.Message)" } }
}

function Invoke-CosmoHubReal($Tool, [object[]]$ToolArgs) {
    if ($Tool -eq 'claude') { & $CosmoHubClaude @ToolArgs }
    else { & $CosmoHubNode $CosmoHubCodexJs @ToolArgs }
}

function Invoke-CosmoHubTool($Tool, [object[]]$ToolArgs) {
    $h = Get-CosmoHubHealth
    if (-not $h.usable) {
        Write-Host "[cosmohub] CosmosHub not usable: $($h.reason). Using your subscription." -ForegroundColor Yellow
        Invoke-CosmoHubReal $Tool $ToolArgs
        return
    }

    $token = (Get-Content (Join-Path $CosmoHubState 'router-token') -Raw).Trim()
    $start = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $vars = if ($Tool -eq 'claude') {
        @{
            ANTHROPIC_BASE_URL           = $CosmoHubUrl
            ANTHROPIC_AUTH_TOKEN         = $token
            ANTHROPIC_API_KEY            = $null
            ANTHROPIC_DEFAULT_OPUS_MODEL   = 'hub-opus'
            ANTHROPIC_DEFAULT_SONNET_MODEL = 'hub-sonnet'
            ANTHROPIC_DEFAULT_HAIKU_MODEL  = 'hub-haiku'
        }
    } else {
        @{ COSMOHUB_ROUTER_TOKEN = $token }
    }
    $saved = @{}
    foreach ($n in $vars.Keys) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process'); [Environment]::SetEnvironmentVariable($n, $vars[$n], 'Process') }

    Write-Host "[cosmohub] Using CosmosHub API ($($h.models) models) via $CosmoHubUrl" -ForegroundColor Cyan
    try {
        if ($Tool -eq 'claude') { Invoke-CosmoHubReal claude $ToolArgs }
        else { Invoke-CosmoHubReal codex (@('-p', 'cosmohub') + $ToolArgs) }
    } finally {
        foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') }
    }

    # Did CosmosHub run out during this session? Then pick the conversation up on the subscription.
    $exFile = Join-Path $CosmoHubState 'exhausted.json'
    if (Test-Path $exFile) {
        $ex = Get-Content $exFile -Raw | ConvertFrom-Json
        if ($ex.at -ge $start) {
            Write-Host "[cosmohub] CosmosHub refused requests ($($ex.status)): balance likely empty. Resuming on your subscription..." -ForegroundColor Yellow
            if ($Tool -eq 'claude') { Invoke-CosmoHubReal claude @('--continue') }
            else { Invoke-CosmoHubReal codex @('resume', '--last') }
        }
    }
}

function claude { Invoke-CosmoHubTool claude $args }
function codex  { Invoke-CosmoHubTool codex $args }
function claude-sub { Invoke-CosmoHubReal claude $args }
function codex-sub  { Invoke-CosmoHubReal codex $args }

function cosmohub-status {
    $h = Get-CosmoHubHealth
    $h | Format-List usable, reason, models, exhaustedAt
    $log = Join-Path $CosmoHubState 'router.log'
    if (Test-Path $log) { Write-Host 'Recent routing:'; Get-Content $log -Tail 15 }
}
