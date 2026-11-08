# Builds bin\claude-hub.exe with the C# compiler that ships with Windows (.NET Framework 4.x).
$ErrorActionPreference = 'Stop'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "C# compiler not found at $csc" }
$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Force $bin | Out-Null
& $csc /nologo /optimize+ /target:exe "/out:$bin\claude-hub.exe" (Join-Path $PSScriptRoot 'ClaudeHub.cs')
if ($LASTEXITCODE -ne 0) { throw "build failed" }
Write-Host "Built $bin\claude-hub.exe"
