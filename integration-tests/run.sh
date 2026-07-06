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
#   --smoke               After building, install the app on a running emulator
#                         (Android) or simulator (iOS), launch it, and assert the
#                         JS -> bridge -> native SDK round trip actually works at
#                         runtime (catches bridge-registration / crash-on-init
#                         bugs that a compile-only build cannot). Requires a
#                         device to be available: Android via adb (in CI:
#                         reactivecircus/android-emulator-runner), iOS via a
#                         booted simulator (in CI: xcrun simctl boot).

SDK_VERSION="${1:?Usage: $0 <expo-sdk-version> [--platform android|ios] [--quick] [--static-frameworks]}"
shift

PLATFORM="android"
QUICK_MODE=false
STATIC_FRAMEWORKS=false
SMOKE_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="${2:?--platform requires a value}"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    --static-frameworks) STATIC_FRAMEWORKS=true; shift ;;
    --smoke) SMOKE_MODE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$PLATFORM" == "android" || "$PLATFORM" == "ios" ]] || { echo "Invalid platform: $PLATFORM" >&2; exit 2; }
if [[ "$SMOKE_MODE" == true && "$QUICK_MODE" == true ]]; then
  echo "--smoke cannot be combined with --quick (smoke needs a full runnable build)" >&2; exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-e2e.XXXXXX")}"
APP_NAME="e2e-sdk${SDK_VERSION}"
APP_DIR="${WORK_DIR}/${APP_NAME}"

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# Values the smoke entrypoint passes to configure(). The bridge no longer logs
# its arguments (device logging is delegated to the native SDK's sanitized,
# level-gated logger), so these are not asserted against logs; the configure ->
# sendEvent -> getAppstackId round trip — and the UUID getAppstackId returns — is
# what proves the arguments marshaled across the boundary. Kept distinctive so
# they stand out in captured log dumps when a run fails.
SMOKE_API_KEY="SMOKEKEY-abc12345"
SMOKE_LOG_LEVEL="2"
SMOKE_USER_ID="smoke-user-42"

# Resolve adb: prefer PATH, fall back to ANDROID_HOME/ANDROID_SDK_ROOT.
adb_bin() {
  if command -v adb >/dev/null 2>&1; then echo adb; return; fi
  for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
    [[ -n "$base" && -x "$base/platform-tools/adb" ]] && { echo "$base/platform-tools/adb"; return; }
  done
  fail "adb not found (set ANDROID_HOME or put platform-tools on PATH)"
}

# Write a throwaway root component that drives configure -> sendEvent ->
# getAppstackId on launch and prints a sentinel. The blank template's index
# imports ./App, so overwriting App.js is enough regardless of the `main` field.
# The distinctive SMOKE_* values are injected from the shell so the run_*_smoke
# assertions can confirm they arrive intact on the native side.
write_smoke_entrypoint() {
  local app_dir="$1"
  {
    cat <<'JS_HEAD'
import React, { useEffect, useState } from 'react';
import { Text, View } from 'react-native';
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';
JS_HEAD
    printf '\n// Values injected by run.sh --smoke and passed straight into configure().\n'
    printf '// Not asserted against logs anymore; the round trip below is the check.\n'
    printf "const SMOKE_API_KEY = '%s';\n" "$SMOKE_API_KEY"
    printf 'const SMOKE_LOG_LEVEL = %s;\n' "$SMOKE_LOG_LEVEL"
    printf "const SMOKE_USER_ID = '%s';\n" "$SMOKE_USER_ID"
    cat <<'JS_BODY'

// Smoke entrypoint injected by integration-tests/run.sh --smoke.
// Exercises the JS -> bridge -> native round trip and logs a sentinel CI greps
// for. A fake API key is fine: we assert the round trip resolves and
// getAppstackId returns a real UUID, not that the backend accepts the key.
export default function App() {
  const [status, setStatus] = useState('APPSTACK_SMOKE_RUNNING');
  useEffect(() => {
    (async () => {
      try {
        await AppstackSDK.configure(SMOKE_API_KEY, false, undefined, SMOKE_LOG_LEVEL, SMOKE_USER_ID);
        await AppstackSDK.sendEvent(EventType.CUSTOM, 'APPSTACK_SMOKE_EVENT');
        const id = await AppstackSDK.getAppstackId();
        const uuidRe = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
        if (!id || !uuidRe.test(String(id))) {
          throw new Error('getAppstackId returned a non-UUID value: ' + String(id));
        }
        console.log('APPSTACK_SMOKE_OK id=' + String(id));
        setStatus('APPSTACK_SMOKE_OK');
      } catch (e) {
        console.error('APPSTACK_SMOKE_FAIL ' + (e && e.message ? e.message : String(e)));
        setStatus('APPSTACK_SMOKE_FAIL');
      }
    })();
  }, []);
  return (
    <View>
      <Text>{status}</Text>
    </View>
  );
}
JS_BODY
  } > "${app_dir}/App.js"
}

# Install the release APK on an available device, launch it, and poll logcat for
# the success/failure sentinel. Success REQUIRES the JS sentinel APPSTACK_SMOKE_OK
# (emitted only after the full configure -> sendEvent -> getAppstackId round trip);
# the native "configure ... successfully" log is supplemental output only, since it
# fires on configure alone and would otherwise let the check pass early.
run_android_smoke() {
  local apk="$1" pkg="$2"
  local adb; adb="$(adb_bin)"

  log "Waiting for an Android device/emulator..."
  "$adb" get-state >/dev/null 2>&1 || "$adb" wait-for-device
  # Wait for full boot so the launcher/JS runtime is ready.
  local booted=""
  for _ in $(seq 1 60); do
    booted="$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    [[ "$booted" == "1" ]] && break
    sleep 2
  done
  [[ "$booted" == "1" ]] || fail "No booted Android device/emulator available for --smoke"

  log "Installing release APK: $(basename "$apk")"
  "$adb" install -r -d "$apk" >/dev/null || fail "adb install failed"

  "$adb" logcat -c || true
  log "Launching $pkg ..."
  "$adb" shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
    || fail "Failed to launch $pkg"

  local ok_js="APPSTACK_SMOKE_OK"
  local fail_js="APPSTACK_SMOKE_FAIL"

  log "Waiting for SDK round-trip sentinel in logcat (up to 90s)..."
  local dump=""
  for _ in $(seq 1 45); do
    dump="$("$adb" logcat -d 2>/dev/null || true)"

    # Immediate failure signals first, so a configure-then-fail run cannot slip
    # through on the native configure log.
    if grep -qF "$fail_js" <<<"$dump"; then
      grep -F "$fail_js" <<<"$dump" | head -3 >&2
      fail "SDK smoke FAILED at runtime (JS reported an error)"
    fi
    if grep -qE "FATAL EXCEPTION|AndroidRuntime.*com\.appstack\.e2e" <<<"$dump"; then
      grep -E "FATAL EXCEPTION|AndroidRuntime" <<<"$dump" | head -8 >&2
      fail "App crashed at runtime during smoke"
    fi

    # Success requires the JS sentinel = full configure -> sendEvent ->
    # getAppstackId round trip. The native log is printed only as context.
    if grep -qF "$ok_js" <<<"$dump"; then
      log "Smoke sentinel found (JS round-trip complete):"
      grep -F "$ok_js" <<<"$dump" | head -1 | sed 's/^/    /'
      return 0
    fi
    sleep 2
  done
  echo "---- last 40 logcat lines ----" >&2
  "$adb" logcat -d 2>/dev/null | tail -40 >&2 || true
  fail "Timed out waiting for SDK smoke sentinel (no round-trip confirmation)"
}

# Install the .app on a booted simulator, launch it, and poll the unified log for
# the sentinel. Success REQUIRES the JS sentinel APPSTACK_SMOKE_OK, emitted only
# after the full configure -> sendEvent -> getAppstackId round trip. The bridge
# itself no longer logs (device logging is delegated to the native SDK's
# sanitized, level-gated logger), so the JS sentinel is the sole signal — and the
# getAppstackId UUID it carries is native-backed proof the SDK initialized.
run_ios_smoke() {
  local app_path="$1" bundle_id="$2"
  [[ -d "$app_path" ]] || fail ".app not found at $app_path"

  # Prefer an already-booted simulator; otherwise boot the first available iPhone.
  local udid
  udid="$(xcrun simctl list devices booted | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [[ -z "$udid" ]]; then
    udid="$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
    [[ -n "$udid" ]] || fail "No iOS simulator available for --smoke"
    log "Booting simulator ${udid} ..."
    xcrun simctl boot "$udid" || true
  fi
  xcrun simctl bootstatus "$udid" >/dev/null 2>&1 || true

  log "Installing app on simulator: $(basename "$app_path")"
  xcrun simctl install "$udid" "$app_path" || fail "simctl install failed"

  # Capture the unified log (JS console output routed to os_log) in the
  # background, filtered to our sentinel to keep it cheap.
  local capture; capture="$(mktemp "${TMPDIR:-/tmp}/appstack-ios-smoke.XXXXXX")"
  xcrun simctl spawn "$udid" log stream --level debug --style syslog \
    --predicate 'eventMessage CONTAINS "APPSTACK_SMOKE"' \
    > "$capture" 2>/dev/null &
  local log_pid=$!
  sleep 1

  log "Launching ${bundle_id} ..."
  xcrun simctl launch "$udid" "$bundle_id" >/dev/null 2>&1 \
    || { kill "$log_pid" 2>/dev/null || true; fail "simctl launch failed"; }

  local ok_js="APPSTACK_SMOKE_OK"
  local fail_js="APPSTACK_SMOKE_FAIL"

  log "Waiting for SDK round-trip sentinel in the simulator log (up to 90s)..."
  local found=false
  for _ in $(seq 1 45); do
    # Immediate failure signal first, so a configure-then-fail run cannot slip
    # through on the native configure log.
    if grep -qF "$fail_js" "$capture"; then
      kill "$log_pid" 2>/dev/null || true
      grep -F "$fail_js" "$capture" | head -3 >&2
      fail "SDK smoke FAILED at runtime (JS reported an error)"
    fi
    # Success requires the JS sentinel = full configure -> sendEvent ->
    # getAppstackId round trip.
    if grep -qF "$ok_js" "$capture"; then
      found=true; break
    fi
    sleep 2
  done
  kill "$log_pid" 2>/dev/null || true

  if [[ "$found" == true ]]; then
    log "Smoke sentinel found (JS round-trip complete):"
    grep -F "$ok_js" "$capture" | head -1 | sed 's/^/    /'
    rm -f "$capture"
    return 0
  fi
  echo "---- last 40 captured log lines ----" >&2
  tail -40 "$capture" >&2 || true
  rm -f "$capture"
  fail "Timed out waiting for SDK smoke sentinel (no round-trip confirmation)"
}

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

  if [[ "$SMOKE_MODE" == true ]]; then
    # 6a. Build a runnable release APK (Expo default: debug-signed, non-minified,
    # JS bundle embedded → launches without Metro) and drive it on a device.
    write_smoke_entrypoint "$APP_DIR"
    log "Building Android app (assembleRelease, runnable/self-contained)..."
    ./gradlew --no-daemon :app:assembleRelease
    APK="$(ls app/build/outputs/apk/release/*.apk 2>/dev/null | head -1)"
    [[ -n "$APK" ]] || fail "Release APK not found after assembleRelease"
    run_android_smoke "$APK" "com.appstack.e2e"
    log "✅ Android runtime smoke passed (SDK bridge round-trip confirmed)"
  else
    # 6a. Full Android compile (debug — same Java compile path that release uses)
    log "Building Android app (assembleDebug)..."
    ./gradlew --no-daemon :app:assembleDebug
  fi
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
  if [[ "$SMOKE_MODE" == true ]]; then
    # Release embeds the JS bundle → the app launches without Metro. Simulator
    # builds need no code signing.
    write_smoke_entrypoint "$APP_DIR"
    log "Building iOS app (xcodebuild Release, runnable/self-contained; scheme ${SCHEME})..."
    xcodebuild -workspace "$WORKSPACE" \
      -scheme "$SCHEME" \
      -configuration Release \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath build \
      CODE_SIGNING_ALLOWED=NO \
      COMPILER_INDEX_STORE_ENABLE=NO \
      build
    APP_PATH="$(ls -d build/Build/Products/Release-iphonesimulator/*.app 2>/dev/null | head -1)"
    [[ -n "$APP_PATH" ]] || fail "Built .app not found after Release build"
    run_ios_smoke "$APP_PATH" "com.appstack.e2e"
    log "✅ iOS runtime smoke passed (SDK bridge round-trip confirmed)"
  else
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
fi

log "✅ Expo SDK ${SDK_VERSION} / ${PLATFORM} integration test passed"
