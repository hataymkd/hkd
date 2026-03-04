param(
  [Parameter(Mandatory = $true)]
  [string]$AppLinkHost
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($AppLinkHost)) {
  throw "AppLinkHost cannot be empty."
}

$gradlePropsPath = Join-Path $PSScriptRoot "..\android\gradle.properties"
$gradlePropsPath = [System.IO.Path]::GetFullPath($gradlePropsPath)

if (-not (Test-Path $gradlePropsPath)) {
  throw "gradle.properties not found: $gradlePropsPath"
}

$lines = Get-Content -Path $gradlePropsPath
$updated = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^HKD_APP_LINK_HOST=') {
    $lines[$i] = "HKD_APP_LINK_HOST=$AppLinkHost"
    $updated = $true
    break
  }
}

if (-not $updated) {
  $lines += "HKD_APP_LINK_HOST=$AppLinkHost"
}

Set-Content -Path $gradlePropsPath -Value $lines -Encoding UTF8
Write-Host "HKD_APP_LINK_HOST updated to: $AppLinkHost"
