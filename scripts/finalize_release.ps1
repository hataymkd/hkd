param(
  [Parameter(Mandatory = $true)]
  [string]$AppLinkHost,
  [Parameter(Mandatory = $true)]
  [string]$ApkUrl,
  [Parameter(Mandatory = $true)]
  [string]$LatestVersion,
  [string]$MinSupportedVersion = $LatestVersion,
  [string[]]$ReleaseNotes = @("Surum guncellemesi"),
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,
  [Parameter(Mandatory = $true)]
  [string]$UpdateManifestUrl
)

$ErrorActionPreference = "Stop"

powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "set_android_app_link_host.ps1") -AppLinkHost $AppLinkHost

powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "publish_public_release.ps1") `
  -ApkUrl $ApkUrl `
  -LatestVersion $LatestVersion `
  -MinSupportedVersion $MinSupportedVersion `
  -ReleaseNotes $ReleaseNotes

powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "release_readiness_check.ps1")

powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_release_apk.ps1") `
  -SupabaseUrl $SupabaseUrl `
  -SupabaseAnonKey $SupabaseAnonKey `
  -UpdateManifestUrl $UpdateManifestUrl `
  -AppLinkHost $AppLinkHost `
  -SkipReadinessCheck

Write-Host "HKD release finalization completed."
