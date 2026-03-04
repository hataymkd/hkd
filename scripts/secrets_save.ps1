param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    "GITHUB_TOKEN",
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_ACCOUNT_ID",
    "PUSH_WEBHOOK_AUTH",
    "FCM_SERVICE_ACCOUNT_JSON",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_ACCESS_TOKEN"
  )]
  [string]$Name,
  [string]$Value = ""
)

$ErrorActionPreference = "Stop"

$secretsDir = Join-Path $PSScriptRoot "..\.secrets"
$secretsDir = [System.IO.Path]::GetFullPath($secretsDir)
if (-not (Test-Path $secretsDir)) {
  New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($Value)) {
  $secureInput = Read-Host "Enter value for $Name" -AsSecureString
} else {
  $secureInput = ConvertTo-SecureString $Value -AsPlainText -Force
}

$encrypted = $secureInput | ConvertFrom-SecureString
$targetPath = Join-Path $secretsDir "$Name.sec"
Set-Content -Path $targetPath -Value $encrypted -Encoding UTF8

Write-Host "Saved encrypted secret: $Name -> $targetPath"
