# Cloud testing for Noteon (GitHub Actions + Firebase Test Lab)
#
# This document is the source of truth for humans and AI agents operating the
# remote test pipeline. Application behavior / note schema are intentionally
# unchanged by this infrastructure.

## Status overview

| Layer | Status |
|-------|--------|
| GitHub Actions (analyze + unit/widget + host integration + APK build) | **Operational** (run 35338173375) |
| Firebase Test Lab job | **Blocked**: GitHub secret `GCP_SA_KEY` missing; gcloud must use the Google account that owns `noteon-app` |
| Real-device UX judgment (feel of scroll/IME) | Not automatable — still a human step |

Firebase project already linked via `android/app/google-services.json`:
- **project_id:** `noteon-app`
- **applicationId:** `com.noteon.app`

### Fastest unblock (Windows)

1. In a browser, sign in as the Google account that owns Firebase project **noteon-app**  
   (Firebase CLI on this machine is logged in as `arhajjajwork@gmail.com` — use that account in the gcloud browser prompt, not a different personal Gmail).
2. Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_ftl_credentials.ps1
```

3. Then:

```powershell
gh workflow run ci.yml -f run_firebase_test_lab=true -f ftl_physical=true
gh run watch
```

The script enables APIs, creates `noteon-ftl@noteon-app.iam.gserviceaccount.com`, binds least-privilege roles, and sets GitHub secret `GCP_SA_KEY`.

## Required GitHub Secrets / Variables

Configure under: **GitHub → Noteon → Settings → Secrets and variables → Actions**

### Secrets

| Name | Required for | Description |
|------|--------------|-------------|
| `GCP_SA_KEY` | Firebase Test Lab | Full JSON of a Google Cloud **service account** key with Test Lab access on `noteon-app`. Never commit this file. |

### Optional Variables

| Name | Default | Description |
|------|---------|-------------|
| `ENABLE_FIREBASE_TEST_LAB` | unset | Set to `true` to allow the FTL job on `push` to `main` (in addition to manual `workflow_dispatch`). |
| `FIREBASE_PROJECT_ID` | `noteon-app` | Override only if the Firebase project id changes. |

### Create the service account (one-time)

```bash
# Authenticate locally first
gcloud auth login
gcloud config set project noteon-app

# Enable APIs
gcloud services enable testing.googleapis.com toolresults.googleapis.com \
  cloudresourcemanager.googleapis.com storage-component.googleapis.com \
  --project=noteon-app

# Service account
gcloud iam service-accounts create noteon-ftl \
  --display-name="Noteon Firebase Test Lab CI" \
  --project=noteon-app

SA=noteon-ftl@$(gcloud config get-value project).iam.gserviceaccount.com

# Roles (minimal practical set for FTL + result objects)
gcloud projects add-iam-policy-binding noteon-app \
  --member="serviceAccount:${SA}" \
  --role="roles/cloudtestservice.testAdmin"
gcloud projects add-iam-policy-binding noteon-app \
  --member="serviceAccount:${SA}" \
  --role="roles/firebase.qualityAdmin"
gcloud projects add-iam-policy-binding noteon-app \
  --member="serviceAccount:${SA}" \
  --role="roles/storage.objectAdmin"
gcloud projects add-iam-policy-binding noteon-app \
  --member="serviceAccount:${SA}" \
  --role="roles/viewer"

# Key → paste entire JSON into GitHub secret GCP_SA_KEY
gcloud iam service-accounts keys create ./noteon-ftl-key.json \
  --iam-account="${SA}" \
  --project=noteon-app
```

Then delete the local key file after uploading to GitHub Secrets.

## Workflows

| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | Analyze, host tests, integration (host), Android APKs, optional FTL, AI-readable summary |
| `firebase/testlab/android-devices.txt` | Editable device matrix |
| `tool/ci/summarize_ci.dart` | Builds human + machine-readable reports from test/FTL outputs |

## How to run

### Automatic

- Every push / PR: analyze + `flutter test` + host `integration_test` + debug APK build.
- FTL runs on `workflow_dispatch`, or on `push` to `main` when `ENABLE_FIREBASE_TEST_LAB=true` **and** `GCP_SA_KEY` is set.

### Manual trigger

```bash
gh workflow run ci.yml
# Optional inputs are documented in the workflow file.
gh run watch
```

### Local (laptop)

```bash
flutter analyze
flutter test --machine > build/ci/host_tests.json
dart run tool/ci/summarize_ci.dart --host-json build/ci/host_tests.json --out build/ci

# Host integration (no phone required; uses flutter-tester)
flutter test integration_test/app_smoke_test.dart -d flutter-tester
flutter test integration_test/note_editor_browse_test.dart -d flutter-tester

# On a connected Android device / emulator
flutter test integration_test -d <deviceId>
```

### Firebase Test Lab only (after APKs exist)

```bash
# Built by CI, or locally:
flutter build apk --debug
pushd android && ./gradlew app:assembleDebug app:assembleAndroidTest && popd

gcloud firebase test android run \
  --project=noteon-app \
  --type instrumentation \
  --app build/app/outputs/flutter-apk/app-debug.apk \
  --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --timeout 15m \
  --results-bucket=gs://noteon-app-ftl-results \
  --results-dir=manual-$(date +%Y%m%d-%H%M%S) \
  --device model=MediumPhone.arm,version=33,locale=en,orientation=portrait
```

Create the results bucket once if missing:

```bash
gsutil mb -p noteon-app -l us-central1 gs://noteon-app-ftl-results || true
```

## Viewing results

1. **GitHub Actions** → run → job logs.
2. **Artifacts** on the run: `ci-summary`, `test-logs`, `android-apks`, `ftl-results` (when FTL ran).
3. Open `ci-summary/CI_REPORT.md` and `ci-summary/ci_report.json`.
4. Firebase console: https://console.firebase.google.com/project/noteon-app/testlab/histories

## Device matrix (initial)

See `firebase/testlab/android-devices.txt`:

- MediumPhone.arm API 33 — virtual, common modern phone
- SmallPhone.arm API 33 — virtual, small screen
- MediumTablet.arm API 33 — virtual, larger screen (Pixel6.arm is not in the FTL catalog)
- oriole API 32 — physical Pixel 6 (when physical quota allows)

If a model is unavailable in your region/quota, remove or replace that line; CI skips unknown models only when FTL returns a clear catalog error (see workflow logs).

## What stays human

- Subjective scroll/IME “feel”
- Visual density comfort at 16px
- Long real notes with many drawings under production data
- Flaky device-only timing issues that need judgment

## AI agent failure triage

`ci_report.json` includes per-failure fields:

- `testName`, `device`, `error`, `stack`, `logExcerpt`
- `classification`: `application_bug` | `test_bug` | `environment` | `flaky` | `infrastructure` | `unknown`
- `confidence`: `low` | `medium` | `high`
- `artifactHints`: paths to logs/screenshots/videos when present

Agents should read `CI_REPORT.md` first, then `ci_report.json`, then download matching artifacts.
