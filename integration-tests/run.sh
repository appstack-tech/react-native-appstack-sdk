#!/bin/bash
set -euo pipefail

# Integration test: verify the SDK autolinks and compiles in a fresh Expo app.
#
# Scaffolds a throwaway Expo app for the given SDK version, installs the packed
# SDK tarball, runs `expo prebuild` and builds the native project. Catches
# autolinking/toolchain regressions (e.g. PackageList.java generation changes,
# podspec header path issues) before they hit consumers.
#
# Usage: ./integration-tests/run.sh <expo-sdk-version> [options]
#   <expo-sdk-version>    Expo SDK major version, e.g. 54, 55, 56
#   --platform <p>        android (default) or ios
#   --quick               Stop after the autolinking assertion (no full native
#                         build). Useful for fast local iteration.
#   --static-frameworks   iOS only: build with `useFrameworks: "static"` via
#                         expo-build-properties (exercises different header
#                         search paths, common in apps using Firebase etc.)

SDK_VERSION="${1:?Usage: $0 <expo-sdk-version> [--platform android|ios] [--quick] [--static-frameworks]}"
shift

PLATFORM="android"
QUICK_MODE=false
STATIC_FRAMEWORKS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="${2:?--platform requires a value}"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    --static-frameworks) STATIC_FRAMEWORKS=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$PLATFORM" == "android" || "$PLATFORM" == "ios" ]] || { echo "Invalid platform: $PLATFORM" >&2; exit 2; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-e2e.XXXXXX")}"
APP_NAME="e2e-sdk${SDK_VERSION}"
APP_DIR="${WORK_DIR}/${APP_NAME}"

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

log "Expo SDK ${SDK_VERSION} / ${PLATFORM} integration test (workdir: ${WORK_DIR})"

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

# 3. Install the packed SDK and configure app.json for non-interactive prebuild
log "Installing SDK tarball into the app..."
npm install --no-audit --no-fund "$TARBALL"
if [[ "$STATIC_FRAMEWORKS" == true ]]; then
  npm install --no-audit --no-fund expo-build-properties
fi
STATIC_FRAMEWORKS="$STATIC_FRAMEWORKS" node -e "
  const fs = require('fs');
  const j = JSON.parse(fs.readFileSync('app.json', 'utf8'));
  j.expo.android = { ...(j.expo.android || {}), package: 'com.appstack.e2e' };
  j.expo.ios = { ...(j.expo.ios || {}), bundleIdentifier: 'com.appstack.e2e' };
  // Normalize the expo-build-properties plugin so reused app dirs don't leak
  // a previous run's framework setting.
  const plugins = (j.expo.plugins || []).filter(
    (p) => (Array.isArray(p) ? p[0] : p) !== 'expo-build-properties'
  );
  if (process.env.STATIC_FRAMEWORKS === 'true') {
    plugins.push(['expo-build-properties', { ios: { useFrameworks: 'static' } }]);
  }
  j.expo.plugins = plugins;
  fs.writeFileSync('app.json', JSON.stringify(j, null, 2));
"

# 4. Prebuild the native project
log "Running expo prebuild (${PLATFORM})..."
rm -rf "$PLATFORM"
CI=1 npx expo prebuild --platform "$PLATFORM" --no-install

if [[ "$PLATFORM" == "android" ]]; then
  # 5a. Generate PackageList.java and assert our package is linked correctly
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

  # 6a. Full Android compile (debug — same Java compile path that release uses)
  log "Building Android app (assembleDebug)..."
  ./gradlew --no-daemon :app:assembleDebug
else
  # 5b. Install pods and assert the SDK pod was autolinked
  cd ios
  log "Installing pods..."
  # CocoaPods crashes on non-UTF-8 locales (common in minimal CI shells)
  export LANG="${LANG:-en_US.UTF-8}" LC_ALL="${LC_ALL:-en_US.UTF-8}"
  pod install

  grep -q "react-native-appstack-sdk" Podfile.lock \
    || fail "react-native-appstack-sdk missing from Podfile.lock — SDK was not autolinked"
  log "Podfile.lock looks correct:"
  grep -n "react-native-appstack-sdk" Podfile.lock | head -5 | sed 's/^/    /'

  if [[ "$QUICK_MODE" == true ]]; then
    log "✅ Quick mode: skipping full iOS build"
    exit 0
  fi

  # 6b. Full simulator build (no signing required)
  WORKSPACE="$(ls -d *.xcworkspace | head -1)"
  SCHEME="${WORKSPACE%.xcworkspace}"
  log "Building iOS app (xcodebuild, scheme ${SCHEME})..."
  xcodebuild -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    build
fi

log "✅ Expo SDK ${SDK_VERSION} / ${PLATFORM} integration test passed"
