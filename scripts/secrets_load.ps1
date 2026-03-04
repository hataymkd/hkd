param(
  [string[]]$Names = @(
    "GITHUB_TOKEN",
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_ACCOUNT_ID",
    "PUSH_WEBHOOK_AUTH",
    "FCM_SERVICE_ACCOUNT_JSON",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_ACCESS_TOKEN"
  )
)

$ErrorActionPreference = "Stop"

function Read-SecretValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  $encrypted = (Get-Content -Path $FilePath -Raw).Trim()
  if ([string]::IsNullOrWhiteSpace($encrypted)) {
    return $null
  }

  $secure = ConvertTo-SecureString $encrypted
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

$secretsDir = Join-Path $PSScriptRoot "..\.secrets"
$secretsDir = [System.IO.Path]::GetFullPath($secretsDir)

foreach ($name in $Names) {
  $path = Join-Path $secretsDir "$name.sec"
  $value = Read-SecretValue -FilePath $path
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    Set-Item -Path "Env:$name" -Value $value
    Write-Host "$name loaded from encrypted store."
  }
}
