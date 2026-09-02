#!/bin/bash
set -Eeuo pipefail

# Integration test: verify the SDK autolinks and compiles through React Native's
# experimental Swift Package Manager integration in a fresh bare app.

REACT_NATIVE_VERSION="${REACT_NATIVE_VERSION:-0.87.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${SPM_INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-spm.XXXXXX")}"
APP_NAME="AppstackSpmFixture"
APP_DIR="${WORK_DIR}/${APP_NAME}"

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

log "React Native ${REACT_NATIVE_VERSION} SwiftPM integration test (workdir: ${WORK_DIR})"

cd "$ROOT_DIR"
if [[ ! -d node_modules ]]; then
  log "Installing SDK dependencies..."
  npm ci
fi

log "Packing SDK tarball..."
npm pack --silent --pack-destination "$WORK_DIR" > /dev/null
TARBALL="$(find "$WORK_DIR" -maxdepth 1 -name 'react-native-appstack-sdk-*.tgz' -print -quit)"
[[ -n "$TARBALL" ]] || fail "npm pack did not produce an SDK tarball"

log "Scaffolding a bare React Native ${REACT_NATIVE_VERSION} app..."
node "$ROOT_DIR/node_modules/@react-native-community/cli/build/bin.js" init "$APP_NAME" \
  --version "$REACT_NATIVE_VERSION" \
  --pm npm \
  --directory "$APP_DIR" \
  --install-pods false \
  --skip-git-init

cd "$APP_DIR"
log "Installing the packed SDK..."
npm install --no-audit --no-fund --save-exact "$TARBALL"

# The stock 0.87 template includes safe-area-context, which does not currently
# ship a Package.swift. Keep this check focused on Appstack's self-managed
# package instead of relying on a generated, uncommitted fallback manifest.
npm uninstall --no-audit --no-fund react-native-safe-area-context

[[ -f node_modules/react-native-appstack-sdk/ios/Package.swift ]] \
  || fail "Published SDK tarball is missing ios/Package.swift"

log "Running React Native SwiftPM autolinking..."
npx react-native spm add --deintegrate --yes

AUTOLINKED_SDK="ios/build/generated/autolinking/libs/ReactNativeAppstackSdk"
[[ -L "$AUTOLINKED_SDK" ]] || fail "SDK was not added as a self-managed Swift package"
[[ -f "$AUTOLINKED_SDK/Package.swift" ]] || fail "Autolinked SDK manifest cannot be resolved"
grep -q 'product(name: "ReactNativeAppstackSdk"' \
  ios/build/generated/autolinking/Package.swift \
  || fail "SDK product is missing from the generated autolinking package"

log "Building the SwiftPM app for an iOS Simulator..."
BUILD_LOG="${WORK_DIR}/xcodebuild.log"
if ! xcodebuild \
    -project "ios/${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build > "$BUILD_LOG" 2>&1; then
  tail -200 "$BUILD_LOG" >&2
  fail "SwiftPM simulator build failed (full log: ${BUILD_LOG})"
fi

log "✅ React Native ${REACT_NATIVE_VERSION} SwiftPM integration test passed"
