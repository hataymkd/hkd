$ErrorActionPreference = "Stop"

$rootPath = Join-Path $PSScriptRoot ".."
$rootPath = [System.IO.Path]::GetFullPath($rootPath)

$issues = New-Object System.Collections.Generic.List[string]

$versionPath = Join-Path $rootPath "public\version.json"
$indexPath = Join-Path $rootPath "public\index.html"
$gradlePropsPath = Join-Path $rootPath "android\gradle.properties"
$keyPropsPath = Join-Path $rootPath "android\key.properties"

if (-not (Test-Path $versionPath)) {
  $issues.Add("Missing file: public/version.json")
} else {
  $versionJson = Get-Content -Path $versionPath -Raw | ConvertFrom-Json
  if ($versionJson.apk_url -eq "REPLACE_WITH_APK_URL" -or [string]::IsNullOrWhiteSpace($versionJson.apk_url)) {
    $issues.Add("public/version.json -> apk_url is not configured.")
  }
  if ([string]::IsNullOrWhiteSpace($versionJson.latest_version)) {
    $issues.Add("public/version.json -> latest_version is empty.")
  }
  if ([string]::IsNullOrWhiteSpace($versionJson.min_supported_version)) {
    $issues.Add("public/version.json -> min_supported_version is empty.")
  }
}

if (-not (Test-Path $indexPath)) {
  $issues.Add("Missing file: public/index.html")
} else {
  $indexHtml = Get-Content -Path $indexPath -Raw
  if ($indexHtml.Contains("REPLACE_WITH_APK_URL")) {
    $issues.Add("public/index.html -> APK link placeholder is not replaced.")
  }
}

if (-not (Test-Path $gradlePropsPath)) {
  $issues.Add("Missing file: android/gradle.properties")
} else {
  $gradleProps = Get-Content -Path $gradlePropsPath -Raw
  $hostMatch = [System.Text.RegularExpressions.Regex]::Match(
    $gradleProps,
    'HKD_APP_LINK_HOST=([^\r\n]+)'
  )
  if (-not $hostMatch.Success) {
    $issues.Add("android/gradle.properties -> HKD_APP_LINK_HOST is missing.")
  } else {
    $appLinkHost = $hostMatch.Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($appLinkHost) -or $appLinkHost -eq "example.pages.dev") {
      $issues.Add("android/gradle.properties -> HKD_APP_LINK_HOST is not configured.")
    }
  }
}

if (-not (Test-Path $keyPropsPath)) {
  $issues.Add("android/key.properties is missing (release signing not configured).")
}

if ($issues.Count -gt 0) {
  Write-Host "Release readiness check FAILED:"
  foreach ($item in $issues) {
    Write-Host "- $item"
  }
  exit 1
}

Write-Host "Release readiness check PASSED."
