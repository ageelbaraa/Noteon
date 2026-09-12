#!/usr/bin/env bash
# Noteon — Upload iOS IPA to Firebase App Distribution (macOS)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS distribution uploads are typically run on macOS after building an IPA." >&2
  exit 1
fi

load_env() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

load_env "$ROOT/distribution/apps.env"
load_env "$ROOT/distribution/apps.local.env"

IPA_PATH="${1:-}"
RELEASE_NOTES="${2:-Noteon iOS release build}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-noteon-app}"

if [[ -z "${FIREBASE_IOS_APP_ID:-}" ]]; then
  echo "FIREBASE_IOS_APP_ID is not set. Check distribution/apps.env" >&2
  exit 1
fi

if [[ -z "$IPA_PATH" ]]; then
  IPA_PATH="$(find "$ROOT/build/ios/ipa" -name '*.ipa' 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
  echo "IPA not found. Run ./scripts/build_ios_release.sh first, or pass an IPA path." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI not found. Install: npm install -g firebase-tools && firebase login" >&2
  exit 1
fi

ARGS=(
  appdistribution:distribute "$IPA_PATH"
  --app "$FIREBASE_IOS_APP_ID"
  --project "$PROJECT_ID"
  --release-notes "$RELEASE_NOTES"
)

if [[ -n "${FIREBASE_TESTER_GROUPS:-}" ]]; then
  ARGS+=(--groups "$FIREBASE_TESTER_GROUPS")
fi

echo "==> firebase ${ARGS[*]}"
firebase "${ARGS[@]}"
echo "iOS build submitted to Firebase App Distribution."
