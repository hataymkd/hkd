param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,
  [Parameter(Mandatory = $true)]
  [string]$UpdateManifestUrl,
  [string]$BaseHref = "/web/"
)

$ErrorActionPreference = "Stop"

Write-Host "HKD Flutter web release build started..."

flutter build web --release `
  --base-href $BaseHref `
  --dart-define=APP_ENV=prod `
  --dart-define=SUPABASE_URL=$SupabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey `
  --dart-define=HKD_UPDATE_MANIFEST_URL=$UpdateManifestUrl

Write-Host "HKD Flutter web release build completed."
