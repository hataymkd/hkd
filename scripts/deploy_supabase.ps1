param(
  [string]$ProjectRef = "mhhochzmidrouurzhrxy",
  [string]$DbPassword = "",
  [switch]$SkipLink,
  [switch]$SkipDbPush
)

$ErrorActionPreference = "Stop"

function Invoke-SupabaseCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$CommandArgs,
    [Parameter(Mandatory = $true)]
    [string]$Step
  )

  & npx --yes supabase @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase step failed: $Step"
  }
}

Write-Host "HKD Supabase deploy started for project: $ProjectRef"

if (-not $SkipLink) {
  $linkArgs = @("link", "--project-ref", $ProjectRef)
  if (-not [string]::IsNullOrWhiteSpace($DbPassword)) {
    $linkArgs += @("--password", $DbPassword)
  }
  Invoke-SupabaseCommand -CommandArgs $linkArgs -Step "link project"
}

if (-not $SkipDbPush) {
  $dbPushArgs = @("db", "push", "--linked")
  if (-not [string]::IsNullOrWhiteSpace($DbPassword)) {
    $dbPushArgs += @("--password", $DbPassword)
  }
  Invoke-SupabaseCommand -CommandArgs $dbPushArgs -Step "db push"
}

Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "create_invite", "--project-ref", $ProjectRef) `
  -Step "deploy function create_invite"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "accept_invite", "--project-ref", $ProjectRef) `
  -Step "deploy function accept_invite"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "approve_membership", "--project-ref", $ProjectRef) `
  -Step "deploy function approve_membership"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "admin_approve_user", "--project-ref", $ProjectRef) `
  -Step "deploy function admin_approve_user"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "create_payment_checkout", "--project-ref", $ProjectRef) `
  -Step "deploy function create_payment_checkout"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "confirm_payment", "--project-ref", $ProjectRef) `
  -Step "deploy function confirm_payment"
Invoke-SupabaseCommand `
  -CommandArgs @("functions", "deploy", "send_notification", "--project-ref", $ProjectRef) `
  -Step "deploy function send_notification"

Write-Host "HKD Supabase deploy completed."
