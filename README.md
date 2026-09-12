# Noteon

**Private notes. On your device.**

Noteon is a modern, offline-first notes app for Android and iOS. Your notes, images, and sketches stay on the device — no accounts, no cloud sync, no analytics SDKs in the app.

## Overview

Noteon focuses on calm writing and practical organization: rich text, folders and tags, search, local media, and optional per-note password protection. The UI supports English and Arabic with full LTR/RTL layout, plus light and dark themes.

## Features

- **Offline-first** — Isar Community local database; media on the filesystem
- **Rich text** — Flutter Quill editor (bold, italic, lists, undo/redo)
- **Images & sketches** — gallery/camera import and freehand sketches stored locally
- **Folders & tags** — nest folders, tag notes, filter from the organize drawer
- **Search** — find notes by title and unlocked content
- **Per-note lock** — PBKDF2 + AES-GCM; locked bodies are not searchable in plaintext
- **English + Arabic** — first-class RTL/LTR
- **Light / dark / system** themes
- **No cloud accounts** — nothing syncs unless you add that yourself later

## Screenshots

_Screenshots coming soon._ Add device captures under `docs/screenshots/` and link them here.

## Technology stack

| Area | Choice |
|------|--------|
| Framework | Flutter / Dart |
| State | Riverpod |
| Database | Isar Community 3.x |
| Editor | flutter_quill |
| Crypto | cryptography (+ flutter bindings) |
| Fonts | Plus Jakarta Sans |
| Brand primary | `#0D9488` |

## Architecture

Feature-first layout under `lib/`:

```
lib/
  app.dart                 # MaterialApp, theme, locale
  main.dart                # DB bootstrap
  core/                    # theme, l10n, database, crypto, providers
  features/
    notes/                 # list, editor, lock, media embeds
    folders/
    tags/
    settings/
    home/                  # shell + startup error UI
  shared/widgets/          # design-system widgets
```

Data stays local: Isar for metadata/content, app documents directory for images/sketches. Locked notes encrypt content and related media for the session unlock model described in the code.

## Supported platforms

- **Android**
- **iOS**

(Desktop targets may exist in the Flutter template but are not a product focus.)

## Requirements

- Flutter SDK (see `environment.sdk` in `pubspec.yaml`)
- Android Studio / Xcode for device builds
- For App Distribution only: Node.js + [Firebase CLI](https://firebase.google.com/docs/cli)

## Getting started

```bash
flutter pub get
flutter run
```

Generate localizations if needed (also runs via `flutter pub get` when `generate: true`):

```bash
flutter gen-l10n
```

## Testing & analysis

```bash
flutter analyze
flutter test -j 1
```

## Release builds

### Android APK

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1
```

```bash
# macOS / Linux
./scripts/build_android_release.sh
```

Optional App Bundle:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_android_aab.ps1
```

Signing: if `android/key.properties` exists (see `android/key.properties.example`), release builds use that keystore; otherwise debug signing is used for internal testing. **Never commit** keystores or `key.properties`.

### iOS IPA (macOS + Xcode)

```bash
./scripts/build_ios_release.sh
# EXPORT_METHOD=development ./scripts/build_ios_release.sh
```

## Firebase App Distribution (testers only)

Firebase is used **only** to distribute test APKs/IPAs via the Firebase CLI. The Noteon app does **not** include Firebase Auth, Firestore, Analytics, Crashlytics, or other Firebase runtime SDKs.

Public client config (`google-services.json`, `GoogleService-Info.plist`, `distribution/apps.env`) identifies the Firebase Android/iOS apps for CLI distribution. Restrict those API keys in Google Cloud Console (Android package / iOS bundle).

**Never commit** service-account JSON or `distribution/apps.local.env`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/distribute_android.ps1
```

```bash
./scripts/distribute_android.sh
./scripts/distribute_ios.sh
```

Set `FIREBASE_TESTER_GROUPS` in `distribution/apps.env` or a gitignored `apps.local.env` to notify tester groups.

## Privacy & security

- Notes and media remain on-device by design
- Per-note locks use password-derived keys; there is **no password recovery**
- No analytics or crash-reporting SDK in the app binary path described above
- Treat signing keys, CI service accounts, and App Distribution credentials as secrets

## License

[MIT](LICENSE) © Baraa Ageel

## Contributing

Issues and pull requests are welcome.

1. Fork and create a feature branch from `main`
2. Keep changes focused; do not commit secrets or local databases
3. Run `flutter analyze` and `flutter test -j 1` before opening a PR
4. Describe UX or platform impact clearly (EN/AR, light/dark, Android/iOS)

## Project status

**v1.0.0** — feature-complete offline notes app with organization, media, locking, bilingual UI, and a polished Material 3 experience. Active development may continue for polish and platform packaging.
