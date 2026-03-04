param(
  [string]$SourceDir = ".\build\web",
  [string]$TargetDir = ".\public\web"
)

$ErrorActionPreference = "Stop"

$resolvedSource = [System.IO.Path]::GetFullPath((Join-Path $PWD $SourceDir))
$resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $PWD $TargetDir))

if (-not (Test-Path $resolvedSource)) {
  throw "Web build source directory not found: $resolvedSource"
}

if (Test-Path $resolvedTarget) {
  Remove-Item -Path $resolvedTarget -Recurse -Force
}

New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
Copy-Item -Path (Join-Path $resolvedSource "*") -Destination $resolvedTarget -Recurse -Force

Write-Host "Web bundle published to: $resolvedTarget"
