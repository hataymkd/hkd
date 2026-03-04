param(
  [string]$CloudflareApiToken = "",
  [string]$CloudflareAccountId = "",
  [string]$WorkerName = "hkd-push-webhook",
  [string]$ScriptPath = "cloudflare/workers/hkd-push-webhook/worker.mjs",
  [string]$PushWebhookAuth = "",
  [string]$FcmServiceAccountJson = "",
  [string]$CompatibilityDate = "2026-03-03"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$secretsLoader = Join-Path $PSScriptRoot "secrets_load.ps1"
if (Test-Path $secretsLoader) {
  & $secretsLoader -Names @(
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_ACCOUNT_ID",
    "PUSH_WEBHOOK_AUTH",
    "FCM_SERVICE_ACCOUNT_JSON"
  ) | Out-Null
}

if ([string]::IsNullOrWhiteSpace($CloudflareApiToken)) {
  $CloudflareApiToken = [Environment]::GetEnvironmentVariable("CLOUDFLARE_API_TOKEN")
}
if ([string]::IsNullOrWhiteSpace($CloudflareAccountId)) {
  $CloudflareAccountId = [Environment]::GetEnvironmentVariable("CLOUDFLARE_ACCOUNT_ID")
}
if ([string]::IsNullOrWhiteSpace($PushWebhookAuth)) {
  $PushWebhookAuth = [Environment]::GetEnvironmentVariable("PUSH_WEBHOOK_AUTH")
}
if ([string]::IsNullOrWhiteSpace($FcmServiceAccountJson)) {
  $FcmServiceAccountJson = [Environment]::GetEnvironmentVariable("FCM_SERVICE_ACCOUNT_JSON")
}

if ([string]::IsNullOrWhiteSpace($CloudflareApiToken)) {
  throw "CLOUDFLARE_API_TOKEN is required."
}
if ([string]::IsNullOrWhiteSpace($CloudflareAccountId)) {
  throw "CLOUDFLARE_ACCOUNT_ID is required."
}
if ([string]::IsNullOrWhiteSpace($PushWebhookAuth)) {
  throw "PUSH_WEBHOOK_AUTH is required."
}

$resolvedScriptPath = [System.IO.Path]::GetFullPath((Join-Path $PWD $ScriptPath))
if (-not (Test-Path $resolvedScriptPath)) {
  throw "Worker script not found: $resolvedScriptPath"
}

$scriptContent = Get-Content -Path $resolvedScriptPath -Raw
$metadata = @{
  main_module = "worker.mjs"
  compatibility_date = $CompatibilityDate
  bindings = @(
    @{
      type = "plain_text"
      name = "PUSH_WEBHOOK_AUTH"
      text = $PushWebhookAuth
    }
  )
} | ConvertTo-Json -Depth 20 -Compress

$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Authorization =
  New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $CloudflareApiToken)

$multipart = New-Object System.Net.Http.MultipartFormDataContent
$metadataContent = New-Object System.Net.Http.StringContent(
  $metadata,
  [System.Text.Encoding]::UTF8,
  "application/json"
)
$multipart.Add($metadataContent, "metadata")

$scriptPart = New-Object System.Net.Http.StringContent(
  $scriptContent,
  [System.Text.Encoding]::UTF8,
  "application/javascript+module"
)
$multipart.Add($scriptPart, "worker.mjs", "worker.mjs")

$deployUrl =
  "https://api.cloudflare.com/client/v4/accounts/$CloudflareAccountId/workers/scripts/$WorkerName"
$deployResponse = $client.PutAsync($deployUrl, $multipart).Result
$deployRaw = $deployResponse.Content.ReadAsStringAsync().Result
if (-not $deployResponse.IsSuccessStatusCode) {
  throw "Worker deploy failed: $($deployResponse.StatusCode)`n$deployRaw"
}

Write-Host "Worker deployed: $WorkerName"

if (-not [string]::IsNullOrWhiteSpace($FcmServiceAccountJson)) {
  $secretUrl =
    "https://api.cloudflare.com/client/v4/accounts/$CloudflareAccountId/workers/scripts/$WorkerName/secrets"
  $secretPayload = @{
    name = "FCM_SERVICE_ACCOUNT_JSON"
    text = $FcmServiceAccountJson
    type = "secret_text"
  } | ConvertTo-Json -Depth 5

  $secretRequest = New-Object System.Net.Http.StringContent(
    $secretPayload,
    [System.Text.Encoding]::UTF8,
    "application/json"
  )
  $secretResponse = $client.PutAsync($secretUrl, $secretRequest).Result
  $secretRaw = $secretResponse.Content.ReadAsStringAsync().Result
  if (-not $secretResponse.IsSuccessStatusCode) {
    throw "FCM secret update failed: $($secretResponse.StatusCode)`n$secretRaw"
  }
  Write-Host "FCM_SERVICE_ACCOUNT_JSON secret updated."
} else {
  Write-Host "FCM_SERVICE_ACCOUNT_JSON empty. Worker auth is active, provider dispatch will stay disabled."
}

$healthHeaders = @{
  Authorization = "Bearer $PushWebhookAuth"
  "Content-Type" = "application/json"
}
$healthBody = @{
  token = "health-check-token"
  title = "health"
  body = "health"
  category = "general"
} | ConvertTo-Json

try {
  $healthResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "https://$WorkerName.hataymkd.workers.dev/" `
    -Headers $healthHeaders `
    -Body $healthBody `
    -ErrorAction Stop
  Write-Host "Worker auth check OK."
  $healthResponse | ConvertTo-Json -Depth 5 | Write-Host
} catch {
  Write-Warning "Worker health check failed. Manual check may be required."
}

$client.Dispose()
