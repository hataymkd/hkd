param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,
  [Parameter(Mandatory = $true)]
  [string]$UpdateManifestUrl,
  [string]$AppLinkHost = "",
  [switch]$SkipReadinessCheck
)

$ErrorActionPreference = "Stop"

$rootPath = Join-Path $PSScriptRoot ".."
$rootPath = [System.IO.Path]::GetFullPath($rootPath)

if (-not [string]::IsNullOrWhiteSpace($AppLinkHost)) {
  powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "set_android_app_link_host.ps1") -AppLinkHost $AppLinkHost
}

if (-not $SkipReadinessCheck) {
  powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "release_readiness_check.ps1")
}

Write-Host "HKD Android release build started..."

flutter build apk --release `
  --dart-define=APP_ENV=prod `
  --dart-define=SUPABASE_URL=$SupabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey `
  --dart-define=HKD_UPDATE_MANIFEST_URL=$UpdateManifestUrl

Write-Host "HKD Android release build completed."
