#!/usr/bin/env bash
# Noteon — Upload Android APK to Firebase App Distribution
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

load_env() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1091
  source "$file"
  set +a
}

load_env "$ROOT/distribution/apps.env"
load_env "$ROOT/distribution/apps.local.env"

APK_PATH="${1:-$ROOT/build/app/outputs/flutter-apk/app-release.apk}"
RELEASE_NOTES="${2:-Noteon Android release build}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-noteon-app}"

if [[ -z "${FIREBASE_ANDROID_APP_ID:-}" ]]; then
  echo "FIREBASE_ANDROID_APP_ID is not set. Check distribution/apps.env" >&2
  exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at $APK_PATH. Run ./scripts/build_android_release.sh first." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI not found. Install: npm install -g firebase-tools && firebase login" >&2
  exit 1
fi

ARGS=(
  appdistribution:distribute "$APK_PATH"
  --app "$FIREBASE_ANDROID_APP_ID"
  --project "$PROJECT_ID"
  --release-notes "$RELEASE_NOTES"
)

if [[ -n "${FIREBASE_TESTER_GROUPS:-}" ]]; then
  ARGS+=(--groups "$FIREBASE_TESTER_GROUPS")
fi

echo "==> firebase ${ARGS[*]}"
firebase "${ARGS[@]}"
echo "Android build submitted to Firebase App Distribution."
