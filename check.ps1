# Checks that the CosmosHub setup is working, e.g. after a restart. Run in a new PowerShell window:
#   C:\Projects\cosmohub-router\check.ps1
$root = $PSScriptRoot
$fail = 0
function Row($ok, $what, $detail) {
    if ($ok) { Write-Host ("  [OK]   {0,-34} {1}" -f $what, $detail) -ForegroundColor Green }
    else { Write-Host ("  [FAIL] {0,-34} {1}" -f $what, $detail) -ForegroundColor Red; $script:fail++ }
}

Write-Host "`nCosmosHub setup check`n"

Row ([bool][Environment]::GetEnvironmentVariable('COSMOSHUB_API_KEY', 'User')) 'API key (COSMOSHUB_API_KEY)' 'stored as user env var'
Row ([bool][Environment]::GetEnvironmentVariable('COSMOHUB_ROUTER_TOKEN', 'User')) 'Router token (COSMOHUB_ROUTER_TOKEN)' 'for Codex'

$vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'cosmohub-router.vbs'
Row (Test-Path $vbs) 'Router autostart' $vbs

$proc = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*router.js*' } | Select-Object -First 1
$since = ''
if ($proc) { $since = 'running since ' + $proc.CreationDate.ToString('HH:mm') + ' (PID ' + $proc.ProcessId + ')' }
Row ([bool]$proc) 'Router process' $since

$h = $null
try { $h = Invoke-RestMethod 'http://127.0.0.1:4141/health?live=1' -TimeoutSec 45 } catch {}
if ($h) { Row ([bool]$h.usable) 'CosmosHub reachable' "$($h.reason), $($h.models) models" }
else { Row $false 'CosmosHub reachable' 'router did not answer on 127.0.0.1:4141' }

$prof = (Test-Path $PROFILE) -and (Select-String -Path $PROFILE -SimpleMatch 'cosmohub.ps1' -Quiet)
Row $prof 'PowerShell launcher in profile' $PROFILE
Row ([bool](Get-Command claude-sub -ErrorAction SilentlyContinue)) 'claude/codex launcher loaded' 'in this PowerShell window'

Row (Test-Path (Join-Path $HOME '.codex\cosmohub.config.toml')) 'Codex profile' '~/.codex/cosmohub.config.toml'
Row (Test-Path (Join-Path $root 'bin\claude-hub.exe')) 'VS Code wrapper (claude-hub.exe)' (Join-Path $root 'bin')

$wlog = Join-Path $HOME '.cosmohub\wrapper.log'
if (Test-Path $wlog) { Write-Host "`n  Last VS Code Claude launch: $((Get-Content $wlog -Tail 1))" }

Write-Host ''
if ($fail -eq 0) { Write-Host 'All good.' -ForegroundColor Green }
else { Write-Host "$fail check(s) failed. Re-run install.ps1, or see README section 6 and 8." -ForegroundColor Yellow }
