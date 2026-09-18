#!/usr/bin/env bash
# Runs Flutter integration tests on a booted Android emulator (CI).
# Invoked as a single command so android-emulator-runner does not split loops.
set -uo pipefail

mkdir -p build/ci
: > build/ci/emulator_tests.ndjson
: > build/ci/emulator_tests.stderr
code=0

shopt -s nullglob
tests=(integration_test/*_test.dart)
if [ ${#tests[@]} -eq 0 ]; then
  echo "No integration_test/*_test.dart files found" | tee -a build/ci/emulator_tests.stderr
  echo "EMU_EXIT=1" | tee build/ci/emulator_exit.txt
  exit 1
fi

for f in "${tests[@]}"; do
  # Soft geometry probes — run locally; skip on emulator to save minutes.
  if [[ "$f" == *investigation* ]]; then
    echo "=== skip $f (investigation-only) ===" | tee -a build/ci/emulator_tests.stderr
    continue
  fi
  echo "=== $f ===" | tee -a build/ci/emulator_tests.stderr
  set +e
  flutter test "$f" -d emulator-5554 --machine \
    2>>build/ci/emulator_tests.stderr | tee -a build/ci/emulator_tests.ndjson
  c=${PIPESTATUS[0]}
  set -e
  if [ "$c" -ne 0 ]; then
    code=$c
  fi
done

adb exec-out screencap -p > build/ci/emulator_screenshot.png || true
adb logcat -d > build/ci/emulator_logcat.txt || true
echo "EMU_EXIT=$code" | tee build/ci/emulator_exit.txt
exit "$code"
