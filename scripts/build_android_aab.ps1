# Noteon — Android release App Bundle (Play-style artifact)
# Usage: powershell -ExecutionPolicy Bypass -File scripts/build_android_aab.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> flutter build appbundle --release"
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$aab = Join-Path (Get-Location) "build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "Android App Bundle ready:"
Write-Host "  $aab"
Write-Host ""
Write-Host "App Distribution typically uses APK for testers; AAB is for Play Console."
