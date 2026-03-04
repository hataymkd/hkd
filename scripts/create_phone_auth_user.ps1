param(
  [Parameter(Mandatory = $true)]
  [string]$Phone,
  [Parameter(Mandatory = $true)]
  [string]$Password,
  [string]$FullName = "",
  [string]$SupabaseUrl = "https://mhhochzmidrouurzhrxy.supabase.co",
  [string]$ServiceRoleKey = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  $ServiceRoleKey = [Environment]::GetEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY")
}
if ([string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  throw "SUPABASE_SERVICE_ROLE_KEY is required."
}

function Normalize-Phone {
  param([string]$Value)
  $clean = ($Value -replace "\s+", "").Trim()
  if ($clean.StartsWith("+")) {
    return $clean
  }
  if ($clean.StartsWith("0") -and $clean.Length -eq 11) {
    return "+90" + $clean.Substring(1)
  }
  return $clean
}

$normalizedPhone = Normalize-Phone -Value $Phone
if ($normalizedPhone -notmatch "^\+[1-9][0-9]{7,14}$") {
  throw "Phone must be E.164 format (example: +905309567362)."
}

if ($Password.Length -lt 8) {
  throw "Password must be at least 8 characters."
}

$headers = @{
  apikey = $ServiceRoleKey
  Authorization = "Bearer $ServiceRoleKey"
  "Content-Type" = "application/json"
}

$body = @{
  phone = $normalizedPhone
  password = $Password
  phone_confirm = $true
}
if (-not [string]::IsNullOrWhiteSpace($FullName)) {
  $body.user_metadata = @{
    full_name = $FullName.Trim()
    source = "manual_bootstrap"
  }
}

$json = $body | ConvertTo-Json -Depth 6
$payload = $null
try {
  $payload = Invoke-RestMethod `
    -Method Post `
    -Uri "$SupabaseUrl/auth/v1/admin/users" `
    -Headers $headers `
    -Body $json
} catch {
  $statusCode = $null
  $responseText = ""
  if ($_.Exception.Response -ne $null) {
    try {
      $statusCode = [int]$_.Exception.Response.StatusCode
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $responseText = $reader.ReadToEnd()
      $reader.Dispose()
    } catch {
      $responseText = $_.Exception.Message
    }
  } else {
    $responseText = $_.Exception.Message
  }
  throw "Create user failed ($statusCode): $responseText"
}

if ($null -eq $payload -or $null -eq $payload.id) {
  throw "Unexpected response while creating user."
}

Write-Host "Auth user created."
Write-Host "User ID: $($payload.id)"
Write-Host "Phone: $normalizedPhone"
