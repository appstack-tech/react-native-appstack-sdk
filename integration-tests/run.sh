#!/bin/bash
set -euo pipefail

# Integration test: verify the SDK autolinks and compiles in a fresh Expo app.
#
# Scaffolds a throwaway Expo app for the given SDK version, installs the packed
# SDK tarball, runs `expo prebuild` and builds the Android project. Catches
# autolinking/toolchain regressions (e.g. PackageList.java generation changes)
# before they hit consumers.
#
# Usage: ./integration-tests/run.sh <expo-sdk-version> [--quick]
#   <expo-sdk-version>  Expo SDK major version, e.g. 54, 55, 56
#   --quick             Stop after the PackageList.java assertion (no full
#                       Android compile). Useful for fast local iteration.

SDK_VERSION="${1:?Usage: $0 <expo-sdk-version> [--quick]}"
QUICK_MODE=false
[[ "${2:-}" == "--quick" ]] && QUICK_MODE=true

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-e2e.XXXXXX")}"
APP_NAME="e2e-sdk${SDK_VERSION}"
APP_DIR="${WORK_DIR}/${APP_NAME}"

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

log "Expo SDK ${SDK_VERSION} integration test (workdir: ${WORK_DIR})"

# 1. Pack the SDK (prepack hook builds lib/ via bob)
cd "$ROOT_DIR"
if [[ ! -d node_modules ]]; then
  log "Installing SDK dependencies..."
  npm ci
fi
log "Packing SDK tarball..."
rm -f "${WORK_DIR}"/react-native-appstack-sdk-*.tgz
npm pack --pack-destination "$WORK_DIR" > /dev/null
TARBALL="$(ls "${WORK_DIR}"/react-native-appstack-sdk-*.tgz)"
log "Packed: $(basename "$TARBALL")"

# 2. Scaffold a fresh Expo app for the target SDK version
cd "$WORK_DIR"
if [[ -d "$APP_DIR" ]]; then
  log "Reusing existing app at ${APP_DIR} (delete it for a clean run)"
else
  log "Scaffolding Expo app (template blank@sdk-${SDK_VERSION})..."
  npx --yes create-expo-app@latest "$APP_NAME" --template "blank@sdk-${SDK_VERSION}" --no-install
  cd "$APP_DIR"
  npm install --no-audit --no-fund
fi
cd "$APP_DIR"

# 3. Install the packed SDK and set an Android package for prebuild
log "Installing SDK tarball into the app..."
npm install --no-audit --no-fund "$TARBALL"
node -e "
  const fs = require('fs');
  const j = JSON.parse(fs.readFileSync('app.json', 'utf8'));
  j.expo.android = { ...(j.expo.android || {}), package: 'com.appstack.e2e' };
  fs.writeFileSync('app.json', JSON.stringify(j, null, 2));
"

# 4. Prebuild the Android project
log "Running expo prebuild (android)..."
rm -rf android
CI=1 npx expo prebuild --platform android --no-install

# 5. Generate PackageList.java and assert our package is linked correctly
cd android
log "Generating autolinking PackageList..."
./gradlew --no-daemon :app:generateAutolinkingPackageList

PKG_LIST="app/build/generated/autolinking/src/main/java/com/facebook/react/PackageList.java"
[[ -f "$PKG_LIST" ]] || fail "PackageList.java was not generated at ${PKG_LIST}"

grep -q "AppstackReactNativePackage" "$PKG_LIST" \
  || fail "AppstackReactNativePackage missing from PackageList.java — SDK was not autolinked"
if grep -q "com\.appstack\.reactnative\.com\.appstack" "$PKG_LIST"; then
  grep -n "AppstackReactNativePackage" "$PKG_LIST" >&2
  fail "Duplicated package prefix in PackageList.java (packageInstance must stay unqualified in react-native.config.js)"
fi
log "PackageList.java looks correct:"
grep -n "AppstackReactNativePackage" "$PKG_LIST" | sed 's/^/    /'

if [[ "$QUICK_MODE" == true ]]; then
  log "✅ Quick mode: skipping full Android build"
  exit 0
fi

# 6. Full Android compile (debug — same Java compile path that release uses)
log "Building Android app (assembleDebug)..."
./gradlew --no-daemon :app:assembleDebug

log "✅ Expo SDK ${SDK_VERSION} integration test passed"
