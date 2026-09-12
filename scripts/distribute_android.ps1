# Noteon — Upload Android APK to Firebase App Distribution
# Usage: powershell -ExecutionPolicy Bypass -File scripts/distribute_android.ps1
# Optional: -ApkPath path\to\app-release.apk -ReleaseNotes "notes"

param(
  [string]$ApkPath = "",
  [string]$ReleaseNotes = "Noteon Android release build"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Import-EnvFile([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line.Split("=", 2)
    if ($parts.Length -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"')
    Set-Item -Path "Env:$name" -Value $value
  }
}

Import-EnvFile (Join-Path $root "distribution\apps.env")
Import-EnvFile (Join-Path $root "distribution\apps.local.env")

if (-not $env:FIREBASE_ANDROID_APP_ID) {
  Write-Error "FIREBASE_ANDROID_APP_ID is not set. Check distribution/apps.env"
}

if ($ApkPath -eq "") {
  $ApkPath = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
}

if (-not (Test-Path $ApkPath)) {
  Write-Error "APK not found at $ApkPath. Run scripts/build_android_release.ps1 first."
}

$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebase) {
  Write-Error "Firebase CLI not found. Install: npm install -g firebase-tools && firebase login"
}

$project = $env:FIREBASE_PROJECT_ID
if (-not $project) { $project = "noteon-app" }

$args = @(
  "appdistribution:distribute", $ApkPath,
  "--app", $env:FIREBASE_ANDROID_APP_ID,
  "--project", $project,
  "--release-notes", $ReleaseNotes
)

if ($env:FIREBASE_TESTER_GROUPS) {
  $args += @("--groups", $env:FIREBASE_TESTER_GROUPS)
}

Write-Host "==> firebase $($args -join ' ')"
& firebase @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Android build submitted to Firebase App Distribution."
