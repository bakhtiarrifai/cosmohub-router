# CosmosHub launcher. Dot-sourced from the PowerShell profile; defines:
#   claude / codex          CosmosHub first (via the local router), subscription if CosmosHub can't serve
#   claude-sub / codex-sub  always the subscription
#   cosmohub-status         router health, models, recent routing log
#   cosmohub-model          actual/next models; -List, -Watch, or <slot> <model|auto>
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

# Runs the tool on the subscription. For Codex, model_provider=openai overrides a config.toml that
# points at the router (needed when the Codex VS Code extension should use CosmosHub too).
function Invoke-CosmoHubReal($Tool, [object[]]$ToolArgs) {
    if ($Tool -eq 'claude') { & $CosmoHubClaude @ToolArgs }
    else { & $CosmoHubNode $CosmoHubCodexJs -c model_provider=openai @ToolArgs }
}

function Invoke-CosmoHubCodex([object[]]$ToolArgs) {
    & $CosmoHubNode $CosmoHubCodexJs -p cosmohub @ToolArgs
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
            ANTHROPIC_DEFAULT_OPUS_MODEL   = 'claude-opus-5-5'
            ANTHROPIC_DEFAULT_SONNET_MODEL = 'claude-sonnet-5-5'
            ANTHROPIC_DEFAULT_HAIKU_MODEL  = 'claude-haiku-5-5'
        }
    } else {
        @{ COSMOHUB_ROUTER_TOKEN = $token }
    }
    $saved = @{}
    foreach ($n in $vars.Keys) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process'); [Environment]::SetEnvironmentVariable($n, $vars[$n], 'Process') }

    Write-Host "[cosmohub] Using CosmosHub API ($($h.models) models) via $CosmoHubUrl" -ForegroundColor Cyan
    try { Show-CosmoHubModels (Get-CosmoHubModels) } catch { Write-Warning $_.Exception.Message }
    Write-Host '[cosmohub] Live routing: cosmohub-model -Watch (in another terminal). Manual: cosmohub-model <slot> <model>' -ForegroundColor DarkCyan
    try {
        if ($Tool -eq 'claude') { Invoke-CosmoHubReal claude $ToolArgs }
        else { Invoke-CosmoHubCodex $ToolArgs }
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

function Get-CosmoHubModels {
    if (-not (Start-CosmoHubRouter)) { throw 'CosmosHub router could not start.' }
    $token = (Get-Content (Join-Path $CosmoHubState 'router-token') -Raw).Trim()
    Invoke-RestMethod "$CosmoHubUrl/router/models" -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 20
}

function Show-CosmoHubModels($Status) {
    $Status.slots.PSObject.Properties | ForEach-Object {
        $s = $_.Value
        [pscustomobject]@{
            Slot = $_.Name
            Mode = $s.mode
            'Next request' = $s.nextModel
            'Last used' = if ($s.lastRoute) { $s.lastRoute.model } else { '-' }
            'Last used at (UTC)' = if ($s.lastRoute) { $s.lastRoute.at } else { '-' }
        }
    } | Format-Table -AutoSize | Out-Host
    if ($Status.lastRoute) {
        $r = $Status.lastRoute
        Write-Host "[cosmohub] Last successful routing: $($r.requested) -> $($r.model) [$($r.mode)] at $($r.at)" -ForegroundColor Cyan
    } else {
        Write-Host '[cosmohub] No generation routed since this router started; Next request is a prediction, not a model already used.' -ForegroundColor DarkCyan
    }
}

function cosmohub-model {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][ValidateSet('opus', 'sonnet', 'haiku', 'codex')][string]$Slot,
        [Parameter(Position = 1)][string]$Model,
        [switch]$List,
        [switch]$Watch
    )
    if ($PSBoundParameters.ContainsKey('Model')) {
        if (-not $Slot -or [string]::IsNullOrWhiteSpace($Model)) { throw 'Use: cosmohub-model <opus|sonnet|haiku|codex> <model-id|auto>' }
        if ($List -or $Watch) { throw 'Use -List or -Watch separately from setting a model.' }
        if (-not (Start-CosmoHubRouter)) { throw 'CosmosHub router could not start.' }
        $token = (Get-Content (Join-Path $CosmoHubState 'router-token') -Raw).Trim()
        $chosen = if ($Model -eq 'auto') { $null } else { $Model }
        $body = @{ slot = $Slot; model = $chosen } | ConvertTo-Json -Compress
        $status = Invoke-RestMethod "$CosmoHubUrl/router/models" -Method Post -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $body -TimeoutSec 30
        Write-Host "[cosmohub] $Slot -> $Model. Applies to subsequent requests, including open sessions." -ForegroundColor Green
        Show-CosmoHubModels $status
        return
    }
    if ($Slot) { throw 'Supply a model ID or auto after the slot.' }
    $status = Get-CosmoHubModels
    if ($List) { $status.availableModels; return }
    Show-CosmoHubModels $status
    if ($Watch) {
        Write-Host '[cosmohub] Watching successful routing (all sessions). Ctrl+C to stop.' -ForegroundColor DarkCyan
        $previous = $status.lastRoute | ConvertTo-Json -Compress
        while ($true) {
            Start-Sleep -Seconds 1
            $status = Get-CosmoHubModels
            $current = $status.lastRoute | ConvertTo-Json -Compress
            if ($current -ne $previous) {
                Show-CosmoHubModels $status
                $previous = $current
            }
        }
    }
}

function cosmohub-status {
    $h = Get-CosmoHubHealth
    $h | Format-List usable, reason, models, exhaustedAt
    if ($h.ok) { Show-CosmoHubModels (Get-CosmoHubModels) }
    $log = Join-Path $CosmoHubState 'router.log'
    if (Test-Path $log) { Write-Host 'Recent routing:'; Get-Content $log -Tail 15 }
}
