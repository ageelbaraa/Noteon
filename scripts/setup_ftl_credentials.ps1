# One-shot Firebase Test Lab setup for Noteon (Windows PowerShell)
# Prerequisites:
#   1) gcloud CLI installed
#   2) gh CLI logged in to ageelbaraa/Noteon
#   3) Browser login as the Google account that OWNS Firebase project noteon-app
#      (currently Firebase CLI is logged in as arhajjajwork@gmail.com)
#
# Run:
#   powershell -ExecutionPolicy Bypass -File scripts/setup_ftl_credentials.ps1

$ErrorActionPreference = "Stop"
$Project = "noteon-app"
$SaName = "noteon-ftl"
$SaEmail = "$SaName@$Project.iam.gserviceaccount.com"
$KeyPath = Join-Path $env:TEMP "noteon-ftl-key.json"
$Repo = "ageelbaraa/Noteon"

Write-Host "==> Authenticate as the noteon-app owner (not a personal alt account)"
gcloud auth login --update-adc
gcloud config set project $Project
gcloud auth list
gcloud projects describe $Project --format="value(projectId)" | Out-Null

Write-Host "==> Enable APIs"
gcloud services enable `
  testing.googleapis.com `
  toolresults.googleapis.com `
  storage-component.googleapis.com `
  cloudresourcemanager.googleapis.com `
  --project=$Project

Write-Host "==> Ensure service account $SaEmail"
$desc = & gcloud iam service-accounts describe $SaEmail --project=$Project 2>&1
if ($LASTEXITCODE -ne 0) {
  gcloud iam service-accounts create $SaName `
    --display-name="Noteon Firebase Test Lab CI" `
    --project=$Project
}

Write-Host "==> Bind least-privilege roles"
$roles = @(
  "roles/cloudtestservice.testAdmin",
  "roles/firebase.qualityAdmin",
  "roles/storage.objectAdmin",
  "roles/viewer"
)
foreach ($role in $roles) {
  gcloud projects add-iam-policy-binding $Project `
    --member="serviceAccount:$SaEmail" `
    --role=$role `
    --quiet | Out-Null
}

Write-Host "==> Create key and upload GitHub secret GCP_SA_KEY"
if (Test-Path $KeyPath) { Remove-Item $KeyPath -Force }
gcloud iam service-accounts keys create $KeyPath `
  --iam-account=$SaEmail `
  --project=$Project
Get-Content -Raw $KeyPath | gh secret set GCP_SA_KEY --repo $Repo
Remove-Item $KeyPath -Force

Write-Host "==> Optional: enable FTL on every main push"
gh variable set ENABLE_FIREBASE_TEST_LAB --repo $Repo --body "true"

Write-Host "==> Verify devices (informational)"
gcloud firebase test android models describe MediumPhone.arm --project=$Project 2>$null
gcloud firebase test android models describe SmallPhone.arm --project=$Project 2>$null
gcloud firebase test android models describe MediumTablet.arm --project=$Project 2>$null
gcloud firebase test android models describe oriole --project=$Project 2>$null

Write-Host ""
Write-Host "Done. Trigger FTL with:"
Write-Host "  gh workflow run ci.yml --repo $Repo -f run_firebase_test_lab=true -f ftl_physical=true"
Write-Host "  gh run watch --repo $Repo"
