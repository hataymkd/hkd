param(
  [Parameter(Mandatory = $true)]
  [string]$ApkUrl,
  [Parameter(Mandatory = $true)]
  [string]$LatestVersion,
  [string]$MinSupportedVersion = $LatestVersion,
  [string[]]$ReleaseNotes = @("Ilk surum"),
  [string]$PublishedAtUtc = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApkUrl)) {
  throw "ApkUrl cannot be empty."
}

if ([string]::IsNullOrWhiteSpace($LatestVersion)) {
  throw "LatestVersion cannot be empty."
}

$rootPath = Join-Path $PSScriptRoot ".."
$rootPath = [System.IO.Path]::GetFullPath($rootPath)
$versionPath = Join-Path $rootPath "public\version.json"
$indexPath = Join-Path $rootPath "public\index.html"

if (-not (Test-Path $versionPath)) {
  throw "version.json not found: $versionPath"
}
if (-not (Test-Path $indexPath)) {
  throw "index.html not found: $indexPath"
}

if ([string]::IsNullOrWhiteSpace($PublishedAtUtc)) {
  $PublishedAtUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$cleanNotes = @()
foreach ($note in $ReleaseNotes) {
  if (-not [string]::IsNullOrWhiteSpace($note)) {
    $cleanNotes += $note.Trim()
  }
}
if ($cleanNotes.Count -eq 0) {
  $cleanNotes = @("Surum guncellemesi")
}

function Get-GithubReleasePageUrl {
  param([string]$Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return ""
  }

  $pattern = '^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/[^/]+$'
  $match = [System.Text.RegularExpressions.Regex]::Match($Url.Trim(), $pattern)
  if (-not $match.Success) {
    return ""
  }

  $owner = $match.Groups[1].Value
  $repo = $match.Groups[2].Value
  $tag = $match.Groups[3].Value
  return "https://github.com/$owner/$repo/releases/tag/$tag"
}

function Get-GithubLatestAssetUrl {
  param([string]$Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return ""
  }

  $pattern = '^https://github\.com/([^/]+)/([^/]+)/releases/download/[^/]+/([^/]+)$'
  $match = [System.Text.RegularExpressions.Regex]::Match($Url.Trim(), $pattern)
  if (-not $match.Success) {
    return ""
  }

  $owner = $match.Groups[1].Value
  $repo = $match.Groups[2].Value
  $asset = $match.Groups[3].Value
  return "https://github.com/$owner/$repo/releases/latest/download/$asset"
}

$releasePageUrl = Get-GithubReleasePageUrl -Url $ApkUrl
$latestAssetUrl = Get-GithubLatestAssetUrl -Url $ApkUrl
$fallbackUrls = @()
if (-not [string]::IsNullOrWhiteSpace($latestAssetUrl)) {
  $fallbackUrls += $latestAssetUrl
}

$payload = [ordered]@{
  latest_version = $LatestVersion.Trim()
  min_supported_version = $MinSupportedVersion.Trim()
  apk_url = $ApkUrl.Trim()
  apk_fallback_urls = $fallbackUrls
  release_page_url = if ([string]::IsNullOrWhiteSpace($releasePageUrl)) { $null } else { $releasePageUrl }
  release_notes = $cleanNotes
  published_at = $PublishedAtUtc.Trim()
}

$json = $payload | ConvertTo-Json -Depth 4
Set-Content -Path $versionPath -Value $json -Encoding UTF8

$html = Get-Content -Path $indexPath -Raw
$pattern = '(<a class="download"\s+href=")([^"]+)(")'
$html = [System.Text.RegularExpressions.Regex]::Replace(
  $html,
  $pattern,
  {
    param($m)
    return "$($m.Groups[1].Value)$($ApkUrl.Trim())$($m.Groups[3].Value)"
  },
  1
)

$fallbackPattern = '(<a class="fallback-link"\s+href=")([^"]+)(")'
$fallbackTarget = if ([string]::IsNullOrWhiteSpace($releasePageUrl)) {
  $ApkUrl.Trim()
} else {
  $releasePageUrl
}
$html = [System.Text.RegularExpressions.Regex]::Replace(
  $html,
  $fallbackPattern,
  {
    param($m)
    return "$($m.Groups[1].Value)$fallbackTarget$($m.Groups[3].Value)"
  },
  1
)

$html = $html.Replace("REPLACE_WITH_APK_URL", $ApkUrl.Trim())
Set-Content -Path $indexPath -Value $html -Encoding UTF8

Write-Host "public/version.json and public/index.html updated successfully."
