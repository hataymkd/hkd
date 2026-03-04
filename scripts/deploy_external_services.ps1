param(
  [Parameter(Mandatory = $true)]
  [string]$PagesProjectName,
  [Parameter(Mandatory = $true)]
  [string]$AppLinkHost,
  [Parameter(Mandatory = $true)]
  [string]$RepoOwner,
  [Parameter(Mandatory = $true)]
  [string]$RepoName,
  [Parameter(Mandatory = $true)]
  [string]$ReleaseTag,
  [Parameter(Mandatory = $true)]
  [string]$LatestVersion,
  [string]$MinSupportedVersion = $LatestVersion,
  [string[]]$ReleaseNotes = @("Surum guncellemesi"),
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,
  [string]$UpdateManifestUrl = "",
  [string]$GithubToken = "",
  [string]$CloudflareApiToken = "",
  [string]$CloudflareAccountId = "",
  [switch]$SkipBuild,
  [switch]$SkipWebBuild
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "secrets_load.ps1") | Out-Null

if ([string]::IsNullOrWhiteSpace($UpdateManifestUrl)) {
  $UpdateManifestUrl = "https://$PagesProjectName.pages.dev/version.json"
}

$scriptsPath = $PSScriptRoot

& (Join-Path $scriptsPath "set_android_app_link_host.ps1") -AppLinkHost $AppLinkHost

if (-not $SkipBuild) {
  & (Join-Path $scriptsPath "build_release_apk.ps1") `
    -SupabaseUrl $SupabaseUrl `
    -SupabaseAnonKey $SupabaseAnonKey `
    -UpdateManifestUrl $UpdateManifestUrl `
    -AppLinkHost $AppLinkHost `
    -SkipReadinessCheck
}

if (-not $SkipWebBuild) {
  & (Join-Path $scriptsPath "build_release_web.ps1") `
    -SupabaseUrl $SupabaseUrl `
    -SupabaseAnonKey $SupabaseAnonKey `
    -UpdateManifestUrl $UpdateManifestUrl

  & (Join-Path $scriptsPath "publish_web_bundle.ps1")
}

$publishArgs = @{
  RepoOwner = $RepoOwner
  RepoName = $RepoName
  Tag = $ReleaseTag
  ReleaseName = $ReleaseTag
  ReleaseBody = "HKD release $LatestVersion"
  Quiet = $true
}
if (-not [string]::IsNullOrWhiteSpace($GithubToken)) {
  $publishArgs.GithubToken = $GithubToken
} elseif (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $publishArgs.GithubToken = $env:GITHUB_TOKEN
}

$apkUrl = & (Join-Path $scriptsPath "publish_github_release.ps1") @publishArgs
$apkUrl = ($apkUrl | Select-Object -Last 1).ToString().Trim()
if ([string]::IsNullOrWhiteSpace($apkUrl)) {
  throw "Could not resolve GitHub APK URL."
}

& (Join-Path $scriptsPath "publish_public_release.ps1") `
  -ApkUrl $apkUrl `
  -LatestVersion $LatestVersion `
  -MinSupportedVersion $MinSupportedVersion `
  -ReleaseNotes $ReleaseNotes

$cloudflareArgs = @{
  ProjectName = $PagesProjectName
  Directory = "public"
}
if (-not [string]::IsNullOrWhiteSpace($CloudflareApiToken)) {
  $cloudflareArgs.CloudflareApiToken = $CloudflareApiToken
} elseif (-not [string]::IsNullOrWhiteSpace($env:CLOUDFLARE_API_TOKEN)) {
  $cloudflareArgs.CloudflareApiToken = $env:CLOUDFLARE_API_TOKEN
}
if (-not [string]::IsNullOrWhiteSpace($CloudflareAccountId)) {
  $cloudflareArgs.CloudflareAccountId = $CloudflareAccountId
} elseif (-not [string]::IsNullOrWhiteSpace($env:CLOUDFLARE_ACCOUNT_ID)) {
  $cloudflareArgs.CloudflareAccountId = $env:CLOUDFLARE_ACCOUNT_ID
}

& (Join-Path $scriptsPath "deploy_cloudflare_pages.ps1") @cloudflareArgs

& (Join-Path $scriptsPath "release_readiness_check.ps1")

Write-Host "External deployment completed."
Write-Host "Pages URL: https://$PagesProjectName.pages.dev"
Write-Host "Version URL: https://$PagesProjectName.pages.dev/version.json"
Write-Host "APK URL: $apkUrl"
