# Cloud testing for Noteon (GitHub Actions + optional FTL)

## Status overview

| Layer | Status | Cost |
|-------|--------|------|
| GitHub Actions host CI (analyze / unit / widget / flutter-tester) | **Operational** | **$0** (public repo) |
| **Android emulator integration (default remote Android path)** | **Operational path** | **$0** — no card |
| Firebase Test Lab | **Optional / unavailable** — project billing disabled | Would require Blaze — **not enabled** |

Firebase project `noteon-app` remains linked for App Distribution only. **No billing was enabled.**

## Free alternatives compared

| Option | Cost | Credit card | Flutter integration | Real Android device | Automated | AI-readable |
|--------|------|-------------|---------------------|---------------------|-----------|-------------|
| **GitHub Actions + Android emulator** (chosen) | **$0** (public repo unlimited Actions) | **No** | **Yes** | Emulator only | **Yes** | **Yes** |
| GitHub Actions host `flutter-tester` only | $0 | No | Partial (no Android runtime) | No | Yes | Yes |
| Firebase Test Lab | Blocked without Blaze | Yes (billing) | Yes | Virtual + physical | Yes | Yes |
| BrowserStack / Sauce Labs free trials | Trial / limited | Usually yes | Yes | Yes | Yes | Varies |
| Other “free trial” device clouds | Trial | Usually yes | Yes | Yes | Yes | Varies |

**Selected:** GitHub-hosted Android emulator via `reactivecircus/android-emulator-runner`.

**Why:** Permanently free for this **public** repository, no card, runs the existing `integration_test/` suite on a real Android API image, uploads logs/screenshots, and feeds `ci_report.json` for AI agents. It does **not** replace physical-device UX judgment.

**Limits:** Uses GitHub Actions minutes (unlimited for public repos; private repos have a free monthly quota). Emulator ≠ OEM hardware / IME “feel”.

## Architecture (current)

```
Flutter Noteon
    → GitHub Actions
         ├── flutter analyze
         ├── flutter test (host)
         ├── integration_test on flutter-tester (host)
         ├── Android APK build
         ├── Android emulator integration  ← FREE default remote Android path
         └── Firebase Test Lab (optional, billing required — left intact, off)
              → Artifacts: CI_REPORT.md / ci_report.json / screenshots / logcat
```

## Firebase Test Lab (optional — do not enable billing for this)

FTL remains configured under `.github/workflows/ci.yml` and `firebase/testlab/`, but:

- Runs **only** on `workflow_dispatch` with `run_firebase_test_lab=true`.
- Requires Blaze billing on `noteon-app` (currently disabled).
- **Do not upgrade billing** unless you later choose to accept charges.

Credentials already prepared (`GCP_SA_KEY`) can stay; they are unused while FTL is off.

## How to run (free path)

### Automatic

Every push / PR runs analyze, host tests, APK build, and the **Android emulator** job.

### Manual

```bash
gh workflow run ci.yml -f run_android_emulator=true -f run_firebase_test_lab=false
gh run watch
```

### Local (no cloud cost)

```bash
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart -d flutter-tester
flutter test integration_test/note_editor_browse_test.dart -d flutter-tester
# With a local emulator/device:
flutter test integration_test -d <deviceId>
```

## Artifacts

| Artifact | Contents |
|----------|----------|
| `ci-summary` | `CI_REPORT.md`, `ci_report.json` |
| `test-logs` | Host analyze + machine JSON |
| `android-emulator-results` | Emulator NDJSON, stderr, screenshot, logcat |
| `android-apks` | Debug + androidTest APKs |
| `ftl-results` | Only if FTL was explicitly requested and ran |

## Emulator vs physical UX

| Automated emulator validation | Physical-device UX validation |
|-------------------------------|------------------------------|
| Pass/fail of scroll/caret/embed scenarios | Subjective scroll/IME “feel” |
| CI regression gate | Density comfort on real panels |
| Logs + screenshot | Multi-OEM quirks |

## Cost safety

- No Firebase Blaze upgrade.
- No GCP billing link.
- No paid third-party device cloud activated.
- Default CI uses only GitHub Actions (free for this public repo).
