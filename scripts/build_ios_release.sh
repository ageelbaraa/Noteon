#!/usr/bin/env bash
# Noteon — iOS release IPA for Firebase App Distribution (macOS + Xcode required)
#
# Requires a valid Apple signing setup (development or ad hoc / distribution).
# Usage:
#   ./scripts/build_ios_release.sh
# Optional export method override:
#   EXPORT_METHOD=ad-hoc ./scripts/build_ios_release.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS release builds require macOS with Xcode." >&2
  exit 1
fi

EXPORT_METHOD="${EXPORT_METHOD:-ad-hoc}"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build ipa --release --export-method=$EXPORT_METHOD"
flutter build ipa --release --export-method="$EXPORT_METHOD"

echo ""
echo "Look for an IPA under:"
echo "  build/ios/ipa/"
echo ""
echo "Next: ./scripts/distribute_ios.sh"
