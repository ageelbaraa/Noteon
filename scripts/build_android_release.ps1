# Noteon — Android release APK for Firebase App Distribution
# Usage: powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> flutter build apk --release"
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "Android release APK ready:"
Write-Host "  $apk"
Write-Host ""
Write-Host "Next: scripts\distribute_android.ps1"
