param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectName,
  [string]$Directory = "public",
  [string]$CloudflareApiToken = "",
  [string]$CloudflareAccountId = "",
  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CloudflareApiToken)) {
  $CloudflareApiToken = [Environment]::GetEnvironmentVariable("CLOUDFLARE_API_TOKEN")
}
if ([string]::IsNullOrWhiteSpace($CloudflareAccountId)) {
  $CloudflareAccountId = [Environment]::GetEnvironmentVariable("CLOUDFLARE_ACCOUNT_ID")
}

if ([string]::IsNullOrWhiteSpace($CloudflareApiToken)) {
  throw "Cloudflare API token is required. Pass -CloudflareApiToken or set CLOUDFLARE_API_TOKEN."
}
if ([string]::IsNullOrWhiteSpace($CloudflareAccountId)) {
  throw "Cloudflare Account ID is required. Pass -CloudflareAccountId or set CLOUDFLARE_ACCOUNT_ID."
}

$resolvedDir = [System.IO.Path]::GetFullPath((Join-Path $PWD $Directory))
if (-not (Test-Path $resolvedDir)) {
  throw "Directory not found: $resolvedDir"
}

$env:CLOUDFLARE_API_TOKEN = $CloudflareApiToken
$env:CLOUDFLARE_ACCOUNT_ID = $CloudflareAccountId

npx --yes wrangler pages deploy $resolvedDir --project-name $ProjectName --branch $Branch

Write-Host "Cloudflare Pages URL:"
Write-Host "https://$ProjectName.pages.dev"
