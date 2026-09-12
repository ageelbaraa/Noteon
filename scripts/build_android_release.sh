#!/usr/bin/env bash
# Noteon — Android release APK for Firebase App Distribution
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build apk --release"
flutter build apk --release

echo ""
echo "Android release APK ready:"
echo "  build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Next: ./scripts/distribute_android.sh"
