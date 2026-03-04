param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"

Write-Host "HKD local quality checks started..."

if (-not $SkipPubGet) {
  flutter pub get
}

flutter analyze
flutter test

Write-Host "HKD local quality checks completed successfully."
