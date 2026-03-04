param(
  [Parameter(Mandatory = $true)]
  [string]$RepoOwner,
  [Parameter(Mandatory = $true)]
  [string]$RepoName,
  [Parameter(Mandatory = $true)]
  [string]$Tag,
  [string]$ReleaseName = "",
  [string]$ReleaseBody = "",
  [string]$ApkPath = ".\build\app\outputs\flutter-apk\app-release.apk",
  [string]$GithubToken = "",
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GithubToken)) {
  $GithubToken = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN")
}
if ([string]::IsNullOrWhiteSpace($GithubToken)) {
  throw "GitHub token is required. Pass -GithubToken or set GITHUB_TOKEN."
}

$resolvedApkPath = [System.IO.Path]::GetFullPath((Join-Path $PWD $ApkPath))
if (-not (Test-Path $resolvedApkPath)) {
  throw "APK file not found: $resolvedApkPath"
}

if ([string]::IsNullOrWhiteSpace($ReleaseName)) {
  $ReleaseName = $Tag
}

$headers = @{
  Authorization = "Bearer $GithubToken"
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}

$repoApi = "https://api.github.com/repos/$RepoOwner/$RepoName"
$release = $null

try {
  $release = Invoke-RestMethod -Method Get -Uri "$repoApi/releases/tags/$Tag" -Headers $headers
} catch {
  $createPayload = @{
    tag_name = $Tag
    name = $ReleaseName
    body = $ReleaseBody
    draft = $false
    prerelease = $false
  } | ConvertTo-Json -Depth 5

  $release = Invoke-RestMethod -Method Post -Uri "$repoApi/releases" -Headers $headers -ContentType "application/json" -Body $createPayload
}

if ($null -eq $release -or [string]::IsNullOrWhiteSpace($release.upload_url)) {
  throw "GitHub release could not be created or resolved."
}

$assetName = [System.IO.Path]::GetFileName($resolvedApkPath)
$escapedAssetName = [System.Uri]::EscapeDataString($assetName)
$uploadUrlTemplate = [string]$release.upload_url
$uploadUrlBase = ""

if (-not [string]::IsNullOrWhiteSpace($uploadUrlTemplate)) {
  $uploadUrlBase = ($uploadUrlTemplate -replace "\{\?name,label\}$", "").Trim()
}

if ([string]::IsNullOrWhiteSpace($uploadUrlBase) -and $release.id) {
  $uploadUrlBase = "https://uploads.github.com/repos/$RepoOwner/$RepoName/releases/$($release.id)/assets"
}

$uriProbe = $null
if ([string]::IsNullOrWhiteSpace($uploadUrlBase) -or -not [System.Uri]::TryCreate($uploadUrlBase, [System.UriKind]::Absolute, [ref]$uriProbe)) {
  throw "Invalid GitHub upload URL template: $uploadUrlTemplate"
}

$uploadUrl = "${uploadUrlBase}?name=$escapedAssetName"

$existingAsset = $null
try {
  if ($release.assets) {
    $existingAsset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
  }
} catch {
}

if ($null -ne $existingAsset -and $existingAsset.id) {
  try {
    Invoke-RestMethod -Method Delete -Uri "$repoApi/releases/assets/$($existingAsset.id)" -Headers $headers | Out-Null
  } catch {
  }
}

$uploadHeaders = @{
  Authorization = "Bearer $GithubToken"
  Accept = "application/vnd.github+json"
  "Content-Type" = "application/vnd.android.package-archive"
  "X-GitHub-Api-Version" = "2022-11-28"
}

$asset = Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $uploadHeaders -InFile $resolvedApkPath
if ($null -eq $asset -or [string]::IsNullOrWhiteSpace($asset.browser_download_url)) {
  throw "APK upload failed."
}

if ($Quiet) {
  Write-Output $asset.browser_download_url
} else {
  Write-Host "GitHub release APK URL:"
  Write-Host $asset.browser_download_url
}
