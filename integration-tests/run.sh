#!/bin/bash
set -Eeuo pipefail

# Integration test: verify the SDK autolinks and compiles in a fresh Expo app.
#
# Scaffolds a throwaway Expo app for the given SDK version, installs the packed
# SDK tarball, runs `expo prebuild` and builds the native project. Catches
# autolinking/toolchain regressions (e.g. PackageList.java generation changes,
# podspec header path issues) before they hit consumers.
#
# Usage: ./integration-tests/run.sh <expo-sdk-version> [options]
#   <expo-sdk-version>    Expo SDK major version, e.g. 54, 55, 56, 57
#   --platform <p>        android (default) or ios
#   --architecture <a>    new (default) or legacy. SDK 54 writes this explicitly
#                         to Expo config; SDK 55+ supports only new architecture.
#                         The generated native configuration is always checked.
#   --quick               Stop after the autolinking assertion (no full native
#                         build). Useful for fast local iteration.
#   --static-frameworks   iOS only: build with `useFrameworks: "static"` via
#                         expo-build-properties (exercises different header
#                         search paths, common in apps using Firebase etc.)
#   --smoke               Run a hermetic runtime check against a loopback-only
#                         recording backend. Builds and launches a self-contained
#                         app, exercises the public JS API through the real native
#                         SDK, and validates native HTTP requests. Requires an
#                         Android emulator/device or iOS simulator.

SDK_VERSION="${1:?Usage: $0 <expo-sdk-version> [--platform android|ios] [--architecture new|legacy] [--quick] [--static-frameworks] [--smoke]}"
shift

PLATFORM="android"
ARCHITECTURE="new"
QUICK_MODE=false
STATIC_FRAMEWORKS=false
SMOKE_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="${2:?--platform requires a value}"; shift 2 ;;
    --architecture) ARCHITECTURE="${2:?--architecture requires a value}"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    --static-frameworks) STATIC_FRAMEWORKS=true; shift ;;
    --smoke) SMOKE_MODE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$SDK_VERSION" =~ ^[0-9]+$ ]] || { echo "Invalid Expo SDK version: $SDK_VERSION (expected a major version)" >&2; exit 2; }
SDK_MAJOR=$((10#$SDK_VERSION))
[[ "$PLATFORM" == "android" || "$PLATFORM" == "ios" ]] || { echo "Invalid platform: $PLATFORM" >&2; exit 2; }
[[ "$ARCHITECTURE" == "new" || "$ARCHITECTURE" == "legacy" ]] || {
  echo "Invalid architecture: $ARCHITECTURE (expected new or legacy)" >&2
  exit 2
}
if (( SDK_MAJOR >= 55 )) && [[ "$ARCHITECTURE" == "legacy" ]]; then
  echo "Expo SDK ${SDK_VERSION} does not support the legacy architecture; use Expo SDK 54 or earlier" >&2
  exit 2
fi
if [[ "$ARCHITECTURE" == "new" ]]; then
  NEW_ARCH_ENABLED=true
else
  NEW_ARCH_ENABLED=false
fi
if (( SDK_MAJOR <= 54 )); then
  WRITE_NEW_ARCH_CONFIG=true
else
  # Expo removed newArchEnabled from its documented app-config schema in SDK 55.
  # New Architecture is mandatory there, so let Expo generate its native defaults.
  WRITE_NEW_ARCH_CONFIG=false
fi
if [[ "$SMOKE_MODE" == true && "$QUICK_MODE" == true ]]; then
  echo "--smoke cannot be combined with --quick (smoke needs a full runnable build)" >&2; exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-e2e.XXXXXX")}"
APP_NAME="e2e-sdk${SDK_VERSION}"
APP_DIR="${WORK_DIR}/${APP_NAME}"

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

RUNTIME_DIR=""
RUNTIME_LOG=""
REQUESTS_FILE=""
MOCK_LOG=""
MOCK_PID=""
RUNTIME_LOG_PID=""
RUNTIME_HTTP_PORT=""
RUNTIME_TLS_PORT=""
RUNTIME_TLS_CERT=""
ANDROID_ADB=""
ANDROID_INSTALLED_PACKAGE=""
ANDROID_REVERSED_HTTP=""
ANDROID_REVERSED_TLS=""
IOS_RUNTIME_UDID=""
IOS_INSTALLED_BUNDLE=""

print_runtime_diagnostics() {
  [[ -n "$RUNTIME_DIR" ]] || return 0
  echo "---- bounded runtime diagnostics ----" >&2
  if [[ -s "$RUNTIME_LOG" ]]; then
    grep -iE 'APPSTACK_RUNTIME|Appstack|FATAL EXCEPTION|AndroidRuntime' \
      "$RUNTIME_LOG" 2>/dev/null \
      | tail -60 \
      | sed 's/^/    | /' >&2 || true
  fi
  if [[ -s "$MOCK_LOG" ]]; then
    echo "    mock server:" >&2
    tail -30 "$MOCK_LOG" | sed 's/^/    | /' >&2
  fi
  if [[ -s "$REQUESTS_FILE" ]]; then
    echo "    recorder captured $(wc -l < "$REQUESTS_FILE" | tr -d ' ') request(s)" >&2
    python3 - "$REQUESTS_FILE" <<'PY' \
      | tail -30 \
      | sed 's/^/    | /' >&2 || true
import json
import sys

with open(sys.argv[1], encoding="utf-8", errors="replace") as stream:
    for line in stream:
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            print("invalid recorder entry")
            continue
        body = item.get("body") if isinstance(item.get("body"), dict) else {}
        event = body.get("event_name")
        suffix = f" event={event}" if event else ""
        print(f"{item.get('method', '?')} {item.get('path', '?')}{suffix}")
PY
  else
    echo "    recorder captured no requests" >&2
  fi
}

cleanup_runtime() {
  local status=$?
  set +e

  if [[ -n "$RUNTIME_LOG_PID" ]]; then
    kill "$RUNTIME_LOG_PID" 2>/dev/null
    wait "$RUNTIME_LOG_PID" 2>/dev/null
  fi
  if [[ -n "$ANDROID_ADB" && -n "$ANDROID_INSTALLED_PACKAGE" ]]; then
    "$ANDROID_ADB" shell am force-stop "$ANDROID_INSTALLED_PACKAGE" >/dev/null 2>&1
    "$ANDROID_ADB" uninstall "$ANDROID_INSTALLED_PACKAGE" >/dev/null 2>&1
  fi
  if [[ -n "$ANDROID_ADB" && -n "$ANDROID_REVERSED_HTTP" ]]; then
    "$ANDROID_ADB" reverse --remove "tcp:$ANDROID_REVERSED_HTTP" >/dev/null 2>&1
  fi
  if [[ -n "$ANDROID_ADB" && -n "$ANDROID_REVERSED_TLS" ]]; then
    "$ANDROID_ADB" reverse --remove "tcp:$ANDROID_REVERSED_TLS" >/dev/null 2>&1
  fi
  if [[ -n "$IOS_RUNTIME_UDID" && -n "$IOS_INSTALLED_BUNDLE" ]]; then
    xcrun simctl terminate "$IOS_RUNTIME_UDID" "$IOS_INSTALLED_BUNDLE" >/dev/null 2>&1
    xcrun simctl uninstall "$IOS_RUNTIME_UDID" "$IOS_INSTALLED_BUNDLE" >/dev/null 2>&1
  fi
  if [[ -n "$MOCK_PID" ]]; then
    kill "$MOCK_PID" 2>/dev/null
    wait "$MOCK_PID" 2>/dev/null
  fi

  if (( status != 0 )); then
    print_runtime_diagnostics
  fi

  # The certificate is copied only into this generated debug source set. Remove
  # it even when INTEGRATION_WORK_DIR keeps the rest of the fixture for reuse.
  if [[ -n "$APP_DIR" ]]; then
    rm -f -- \
      "$APP_DIR/android/app/src/debug/res/raw/appstack_runtime_validation_ca.pem" \
      "$APP_DIR/android/app/src/debug/res/xml/appstack_runtime_validation_network_security_config.xml"
  fi
  if [[ -n "$RUNTIME_DIR" && -d "$RUNTIME_DIR" \
      && "$(basename "$RUNTIME_DIR")" == appstack-runtime.* ]]; then
    rm -rf -- "$RUNTIME_DIR"
  fi
  return "$status"
}
trap cleanup_runtime EXIT

# Resolve adb: prefer PATH, fall back to ANDROID_HOME/ANDROID_SDK_ROOT.
adb_bin() {
  if command -v adb >/dev/null 2>&1; then echo adb; return; fi
  for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
    [[ -n "$base" && -x "$base/platform-tools/adb" ]] && { echo "$base/platform-tools/adb"; return; }
  done
  fail "adb not found (set ANDROID_HOME or put platform-tools on PATH)"
}

stop_runtime_log_capture() {
  if [[ -n "$RUNTIME_LOG_PID" ]]; then
    kill "$RUNTIME_LOG_PID" 2>/dev/null || true
    wait "$RUNTIME_LOG_PID" 2>/dev/null || true
    RUNTIME_LOG_PID=""
  fi
}

start_runtime_backend() {
  RUNTIME_DIR="$(mktemp -d "${WORK_DIR%/}/appstack-runtime.${PLATFORM}.XXXXXX")"
  RUNTIME_LOG="$RUNTIME_DIR/runtime.log"
  REQUESTS_FILE="$RUNTIME_DIR/requests.jsonl"
  MOCK_LOG="$RUNTIME_DIR/mock-server.log"
  local port_file="$RUNTIME_DIR/http-port"
  local tls_port_file="$RUNTIME_DIR/tls-port"
  local tls_key="$RUNTIME_DIR/localhost-key.pem"
  RUNTIME_TLS_CERT="$RUNTIME_DIR/localhost-ca.pem"
  : > "$RUNTIME_LOG"

  local mock_arguments=(
    --port-file "$port_file"
    --requests-file "$REQUESTS_FILE"
  )
  if [[ "$PLATFORM" == "android" ]]; then
    (
      umask 077
      openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
        -subj '/CN=127.0.0.1' \
        -addext 'subjectAltName=IP:127.0.0.1' \
        -keyout "$tls_key" \
        -out "$RUNTIME_TLS_CERT" \
        >/dev/null 2>&1
    )
    mock_arguments+=(
      --tls-cert "$RUNTIME_TLS_CERT"
      --tls-key "$tls_key"
      --tls-port-file "$tls_port_file"
    )
  fi

  python3 "$ROOT_DIR/integration-tests/mock_server.py" "${mock_arguments[@]}" \
    > "$MOCK_LOG" 2>&1 &
  MOCK_PID=$!

  for _ in $(seq 1 100); do
    if [[ -s "$port_file" \
        && ( "$PLATFORM" == "ios" || -s "$tls_port_file" ) ]]; then
      break
    fi
    if ! kill -0 "$MOCK_PID" 2>/dev/null; then
      fail "Runtime recording backend exited during startup"
    fi
    sleep 0.1
  done
  [[ -s "$port_file" ]] || fail "Runtime recording backend did not publish its HTTP port"
  RUNTIME_HTTP_PORT="$(<"$port_file")"
  [[ "$RUNTIME_HTTP_PORT" =~ ^[0-9]+$ ]] \
    && (( RUNTIME_HTTP_PORT > 0 && RUNTIME_HTTP_PORT <= 65535 )) \
    || fail "Runtime recording backend published an invalid HTTP port"

  if [[ "$PLATFORM" == "android" ]]; then
    [[ -s "$tls_port_file" ]] || fail "Runtime recording backend did not publish its TLS port"
    RUNTIME_TLS_PORT="$(<"$tls_port_file")"
    [[ "$RUNTIME_TLS_PORT" =~ ^[0-9]+$ ]] \
      && (( RUNTIME_TLS_PORT > 0 && RUNTIME_TLS_PORT <= 65535 )) \
      || fail "Runtime recording backend published an invalid TLS port"
  fi

  export APPSTACK_RUNTIME_PROXY_URL="http://127.0.0.1:${RUNTIME_HTTP_PORT}"
  log "Loopback recording backend ready at ${APPSTACK_RUNTIME_PROXY_URL}"
}

configure_android_runtime_host() {
  local android_root="$1"
  local debug_root="$android_root/app/src/debug"
  local raw_root="$debug_root/res/raw"
  local xml_root="$debug_root/res/xml"
  local manifest_template="$ROOT_DIR/integration-tests/AndroidManifest.runtime.xml"
  local network_template="$ROOT_DIR/integration-tests/network_security_config.xml"
  local build_gradle="$android_root/app/build.gradle"

  [[ -f "$RUNTIME_TLS_CERT" ]] || fail "Runtime TLS certificate is missing"
  [[ -f "$manifest_template" ]] || fail "Runtime Android manifest template is missing"
  [[ -f "$network_template" ]] || fail "Runtime network-security template is missing"
  [[ -f "$build_gradle" ]] || fail "Generated Android app/build.gradle is missing"

  mkdir -p "$raw_root" "$xml_root"
  cp "$RUNTIME_TLS_CERT" "$raw_root/appstack_runtime_validation_ca.pem"
  cp "$network_template" \
    "$xml_root/appstack_runtime_validation_network_security_config.xml"
  sed "s|__APPSTACK_RUNTIME_PROXY_URL__|$APPSTACK_RUNTIME_PROXY_URL|g" \
    "$manifest_template" > "$debug_root/AndroidManifest.xml"

  APPSTACK_ANDROID_BUILD_GRADLE="$build_gradle" node -e '
    const fs = require("fs");
    const path = process.env.APPSTACK_ANDROID_BUILD_GRADLE;
    const marker = "// Appstack runtime check: bundle JS into the debug APK.";
    const source = fs.readFileSync(path, "utf8");
    if (!source.includes("react {")) {
      throw new Error("generated app/build.gradle has no React configuration block");
    }
    if (!source.includes(marker)) {
      fs.writeFileSync(
        path,
        source.replace(
          "react {",
          `react {\n    ${marker}\n    debuggableVariants = []`
        )
      );
    }
  '
}

# Write a throwaway root component that exercises the public JS API and reports
# one machine-readable terminal result to the loopback recorder. Console output
# remains useful diagnostics, but Release builds need not expose it to simctl.
write_runtime_entrypoint() {
  local app_dir="$1"
  cat > "${app_dir}/App.js" <<'JS'
import React, { useEffect, useState } from 'react';
import { Platform, Text, View } from 'react-native';
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

const RESULT_PREFIX = 'APPSTACK_RUNTIME_RESULT:';
const FAILURE_PREFIX = 'APPSTACK_RUNTIME_FAIL:';
const RESULT_URL = '__APPSTACK_RUNTIME_RESULT_URL__';
const delay = (milliseconds) => new Promise(resolve => setTimeout(resolve, milliseconds));

async function reportResult(kind, payload) {
  const response = await fetch(RESULT_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind, payload }),
  });
  if (!response.ok) {
    throw new Error(`runtime recorder rejected result with HTTP ${response.status}`);
  }
}

async function waitForAttribution() {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const value = await AppstackSDK.getAttributionParams();
    if (
      value &&
      value.runtime_validation === 'attributed' &&
      value.unicode === 'café 🚀'
    ) {
      return value;
    }
    await delay(500);
  }
  throw new Error('attribution parameters did not arrive from the recording backend');
}

export default function App() {
  const [status, setStatus] = useState('APPSTACK_RUNTIME_RUNNING');
  useEffect(() => {
    (async () => {
      try {
        const configured = await AppstackSDK.configure(
          'runtime-validation-local-key',
          false,
          undefined,
          0,
          'runtime-validation-user'
        );
        const attribution = await waitForAttribution();
        const callbackResults = await Promise.all([
          AppstackSDK.getAttributionParams(),
          AppstackSDK.getAttributionParams(),
          AppstackSDK.getAttributionParams(),
        ]);
        const validCallbacks = callbackResults.filter(
          value =>
            value &&
            value.runtime_validation === 'attributed' &&
            value.unicode === 'café 🚀'
        ).length;

        const customAccepted = await AppstackSDK.sendEvent(
          EventType.CUSTOM,
          'runtime_validation_custom',
          {
            string: 'bridge-value',
            number: 42,
            decimal: 9.75,
            boolean: true,
            unicode: 'café 🚀',
            array: ['one', 2, false],
            nested: { enabled: true, items: ['nested', 3, false] },
          }
        );
        const standardAccepted = await AppstackSDK.sendEvent(
          EventType.LOGIN,
          undefined,
          { state: 'ready', sequence: 2 }
        );

        let validationError = '';
        try {
          await AppstackSDK.sendEvent();
        } catch (error) {
          validationError =
            error && error.message ? error.message : String(error);
        }

        // Native event delivery is fire-and-forget.
        await delay(4000);
        const appstackId = await AppstackSDK.getAppstackId();
        const sdkDisabled = await AppstackSDK.isSdkDisabled();
        const uuidRe = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
        const result = {
          platform: Platform.OS,
          configured: configured === true,
          appstackIdPresent: uuidRe.test(String(appstackId || '')),
          sdkDisabled,
          callbackCount: callbackResults.length,
          successCount: validCallbacks,
          attributionValidated:
            attribution.runtime_validation === 'attributed' &&
            attribution.unicode === 'café 🚀',
          eventsAccepted:
            Number(customAccepted === true) + Number(standardAccepted === true),
          validationError,
          errors: [],
        };
        await reportResult('success', result);
        console.log(RESULT_PREFIX + JSON.stringify(result));
        setStatus('APPSTACK_RUNTIME_OK');
      } catch (error) {
        const message =
          error && error.message ? error.message : String(error);
        try {
          await reportResult('failure', { message });
        } catch (reportError) {
          console.error(
            FAILURE_PREFIX +
              `could not report "${message}": ${String(reportError)}`
          );
        }
        console.error(FAILURE_PREFIX + message);
        setStatus('APPSTACK_RUNTIME_FAIL');
      }
    })();
  }, []);
  return (
    <View>
      <Text>{status}</Text>
    </View>
  );
}
JS
  APPSTACK_RUNTIME_RESULT_URL="${APPSTACK_RUNTIME_PROXY_URL}/runtime-result" \
    node -e "
      const fs = require('fs');
      const path = process.argv[1];
      const marker = '__APPSTACK_RUNTIME_RESULT_URL__';
      const source = fs.readFileSync(path, 'utf8');
      if (!source.includes(marker)) throw new Error('runtime result URL marker missing');
      fs.writeFileSync(
        path,
        source.replace(marker, process.env.APPSTACK_RUNTIME_RESULT_URL)
      );
    " "${app_dir}/App.js"
}

run_android_smoke() {
  local apk="$1" pkg="$2"
  local adb; adb="$(adb_bin)"
  ANDROID_ADB="$adb"

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

  log "Forwarding recorder ports into the Android device..."
  "$adb" reverse "tcp:$RUNTIME_HTTP_PORT" "tcp:$RUNTIME_HTTP_PORT"
  ANDROID_REVERSED_HTTP="$RUNTIME_HTTP_PORT"
  "$adb" reverse "tcp:$RUNTIME_TLS_PORT" "tcp:$RUNTIME_TLS_PORT"
  ANDROID_REVERSED_TLS="$RUNTIME_TLS_PORT"

  log "Installing runtime APK: $(basename "$apk")"
  "$adb" install -r -d "$apk" >/dev/null || fail "adb install failed"
  ANDROID_INSTALLED_PACKAGE="$pkg"

  "$adb" logcat -c || true
  "$adb" logcat -v threadtime > "$RUNTIME_LOG" 2>&1 &
  RUNTIME_LOG_PID=$!
  log "Launching $pkg ..."
  "$adb" shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
    || fail "Failed to launch $pkg"

  log "Waiting for the terminal runtime result (up to 120s)..."
  for _ in $(seq 1 60); do
    if grep -qE '/runtime-result.*"kind": "failure"' "$REQUESTS_FILE" 2>/dev/null \
        || grep -qF "APPSTACK_RUNTIME_FAIL:" "$RUNTIME_LOG"; then
      fail "Runtime probe reported an error"
    fi
    if grep -qE "FATAL EXCEPTION|AndroidRuntime.*com\.appstack\.e2e" "$RUNTIME_LOG"; then
      fail "App crashed during the runtime check"
    fi
    if grep -qE '/runtime-result.*"kind": "success"' "$REQUESTS_FILE" 2>/dev/null; then
      stop_runtime_log_capture
      log "Terminal runtime result found"
      return 0
    fi
    sleep 2
  done
  fail "Timed out waiting for the terminal runtime result"
}

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
  IOS_RUNTIME_UDID="$udid"

  log "Installing app on simulator: $(basename "$app_path")"
  xcrun simctl install "$udid" "$app_path" || fail "simctl install failed"
  IOS_INSTALLED_BUNDLE="$bundle_id"

  # Capture only Appstack/probe messages from the unified log. The terminal
  # result itself travels through the recorder because Release JS console output
  # is not consistently exposed by simctl across Xcode versions.
  xcrun simctl spawn "$udid" log stream --level debug --style syslog \
    --predicate 'eventMessage CONTAINS[c] "Appstack" OR eventMessage CONTAINS "APPSTACK_RUNTIME"' \
    > "$RUNTIME_LOG" 2>&1 &
  RUNTIME_LOG_PID=$!
  sleep 1

  log "Launching ${bundle_id} ..."
  xcrun simctl launch "$udid" "$bundle_id" >/dev/null 2>&1 \
    || fail "Failed to launch $bundle_id"

  log "Waiting for the terminal runtime result (up to 120s)..."
  for _ in $(seq 1 60); do
    if grep -qE '/runtime-result.*"kind": "failure"' "$REQUESTS_FILE" 2>/dev/null \
        || grep -qF "APPSTACK_RUNTIME_FAIL:" "$RUNTIME_LOG"; then
      fail "Runtime probe reported an error"
    fi
    if grep -qE '/runtime-result.*"kind": "success"' "$REQUESTS_FILE" 2>/dev/null; then
      stop_runtime_log_capture
      log "Terminal runtime result found"
      return 0
    fi
    sleep 2
  done
  fail "Timed out waiting for the terminal runtime result"
}

log "Expo SDK ${SDK_VERSION} / ${PLATFORM} / ${ARCHITECTURE} architecture integration test (workdir: ${WORK_DIR})"

# 1. Pack the SDK (prepack hook builds lib/ via bob)
cd "$ROOT_DIR"
if [[ ! -d node_modules ]]; then
  log "Installing SDK dependencies..."
  npm ci
fi
PACKAGE_VERSION="$(node -p "require('./package.json').version")"
EXPECTED_WRAPPER_VERSION="react-native-${PACKAGE_VERSION}"
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
if [[ "$SMOKE_MODE" == true ]]; then
  start_runtime_backend
fi
STATIC_FRAMEWORKS="$STATIC_FRAMEWORKS" SMOKE_MODE="$SMOKE_MODE" \
  NEW_ARCH_ENABLED="$NEW_ARCH_ENABLED" WRITE_NEW_ARCH_CONFIG="$WRITE_NEW_ARCH_CONFIG" \
  APPSTACK_RUNTIME_PROXY_URL="${APPSTACK_RUNTIME_PROXY_URL:-}" node -e "
  const fs = require('fs');
  const j = JSON.parse(fs.readFileSync('app.json', 'utf8'));
  if (process.env.WRITE_NEW_ARCH_CONFIG === 'true') {
    j.expo.newArchEnabled = process.env.NEW_ARCH_ENABLED === 'true';
  } else {
    // SDK 55+ always uses New Architecture and no longer documents this field.
    // Delete stale values when reusing a generated test app between runs.
    delete j.expo.newArchEnabled;
  }
  j.expo.android = { ...(j.expo.android || {}), package: 'com.appstack.e2e' };

  const existingIos = j.expo.ios || {};
  const infoPlist = { ...(existingIos.infoPlist || {}) };
  delete infoPlist.APPSTACK_DEV_PROXY_URL;
  const appTransportSecurity = {
    ...(infoPlist.NSAppTransportSecurity || {})
  };
  delete appTransportSecurity.NSAllowsLocalNetworking;
  if (Object.keys(appTransportSecurity).length > 0) {
    infoPlist.NSAppTransportSecurity = appTransportSecurity;
  } else {
    delete infoPlist.NSAppTransportSecurity;
  }

  if (process.env.SMOKE_MODE === 'true') {
    if (!process.env.APPSTACK_RUNTIME_PROXY_URL) {
      throw new Error('APPSTACK_RUNTIME_PROXY_URL is required in smoke mode');
    }
    infoPlist.APPSTACK_DEV_PROXY_URL = process.env.APPSTACK_RUNTIME_PROXY_URL;
    infoPlist.NSAppTransportSecurity = {
      ...(infoPlist.NSAppTransportSecurity || {}),
      NSAllowsLocalNetworking: true
    };
  }
  j.expo.ios = {
    ...existingIos,
    bundleIdentifier: 'com.appstack.e2e',
    ...(Object.keys(infoPlist).length > 0 ? { infoPlist } : {})
  };
  if (Object.keys(infoPlist).length === 0) {
    delete j.expo.ios.infoPlist;
  }

  // Normalize repo-owned plugins so reused app dirs do not leak settings from
  // a previous run.
  const plugins = (j.expo.plugins || []).filter(
    (p) => ![
      'expo-build-properties',
      './withAppstackDevProxy'
    ].includes(Array.isArray(p) ? p[0] : p)
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
  if [[ "$SMOKE_MODE" == true ]]; then
    configure_android_runtime_host "$APP_DIR/android"
  fi

  ACTUAL_NEW_ARCH="$(sed -n 's/^newArchEnabled=//p' android/gradle.properties | tail -1)"
  if (( SDK_MAJOR >= 55 )); then
    [[ -z "$ACTUAL_NEW_ARCH" || "$ACTUAL_NEW_ARCH" == "true" ]] \
      || fail "Android generated an invalid mandatory-architecture setting: newArchEnabled=${ACTUAL_NEW_ARCH}"
    log "Android architecture confirmed: new architecture is mandatory in Expo SDK ${SDK_VERSION} (newArchEnabled=${ACTUAL_NEW_ARCH:-<omitted>})"
  else
    [[ "$ACTUAL_NEW_ARCH" == "$NEW_ARCH_ENABLED" ]] \
      || fail "Android architecture mismatch: requested ${ARCHITECTURE}, generated newArchEnabled=${ACTUAL_NEW_ARCH:-<missing>}"
    log "Android architecture confirmed: ${ARCHITECTURE} (newArchEnabled=${ACTUAL_NEW_ARCH})"
  fi

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
    # The short-lived test CA and proxy metadata exist only under src/debug.
    # The generated debug variant bundles JS so it launches without Metro.
    write_runtime_entrypoint "$APP_DIR"
    grep -qF "$APPSTACK_RUNTIME_PROXY_URL" app/src/debug/AndroidManifest.xml \
      || fail "Runtime proxy metadata is missing from the debug manifest"
    [[ -f app/src/debug/res/raw/appstack_runtime_validation_ca.pem ]] \
      || fail "Runtime CA is missing from the debug source set"
    [[ ! -e app/src/main/res/raw/appstack_runtime_validation_ca.pem ]] \
      || fail "Runtime CA leaked into the main source set"
    grep -qF 'debuggableVariants = []' app/build.gradle \
      || fail "Debug APK is not configured to bundle its JS"

    log "Building Android runtime app (assembleDebug, self-contained)..."
    if ! ./gradlew --no-daemon :app:assembleDebug \
        > "$RUNTIME_DIR/android-build.log" 2>&1; then
      tail -120 "$RUNTIME_DIR/android-build.log" >&2
      fail "Android runtime build failed"
    fi
    APK="$(ls app/build/outputs/apk/debug/*.apk 2>/dev/null | head -1)"
    [[ -n "$APK" ]] || fail "Debug APK not found after assembleDebug"
    APK_CONTENTS="$(unzip -Z1 "$APK")"
    grep -qF 'assets/index.android.bundle' <<<"$APK_CONTENTS" \
      || fail "Debug APK does not contain its JS bundle"
    run_android_smoke "$APK" "com.appstack.e2e"
    python3 "$ROOT_DIR/integration-tests/validate_runtime.py" \
      --requests-file "$REQUESTS_FILE" \
      --expected-wrapper-version "$EXPECTED_WRAPPER_VERSION"
    log "✅ Android hermetic runtime check passed"
  else
    # 6a. Full Android compile (debug — same Java compile path that release uses)
    log "Building Android app (assembleDebug)..."
    ./gradlew --no-daemon :app:assembleDebug
  fi
else
  ACTUAL_NEW_ARCH="$(node -e '
    const p = require("./ios/Podfile.properties.json");
    if (p.newArchEnabled !== undefined) process.stdout.write(String(p.newArchEnabled));
  ')"
  if (( SDK_MAJOR >= 55 )); then
    [[ -z "$ACTUAL_NEW_ARCH" || "$ACTUAL_NEW_ARCH" == "true" ]] \
      || fail "iOS generated an invalid mandatory-architecture setting: newArchEnabled=${ACTUAL_NEW_ARCH}"
    log "iOS architecture confirmed: new architecture is mandatory in Expo SDK ${SDK_VERSION} (newArchEnabled=${ACTUAL_NEW_ARCH:-<omitted>})"
  else
    [[ "$ACTUAL_NEW_ARCH" == "$NEW_ARCH_ENABLED" ]] \
      || fail "iOS architecture mismatch: requested ${ARCHITECTURE}, generated newArchEnabled=${ACTUAL_NEW_ARCH:-<missing>}"
    log "iOS architecture confirmed: ${ARCHITECTURE} (newArchEnabled=${ACTUAL_NEW_ARCH})"
  fi

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
    write_runtime_entrypoint "$APP_DIR"
    log "Building iOS app (xcodebuild Release, runnable/self-contained; scheme ${SCHEME})..."
    if ! xcodebuild -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration Release \
        -sdk iphonesimulator \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath build \
        CODE_SIGNING_ALLOWED=NO \
        COMPILER_INDEX_STORE_ENABLE=NO \
        build > "$RUNTIME_DIR/ios-build.log" 2>&1; then
      tail -120 "$RUNTIME_DIR/ios-build.log" >&2
      fail "iOS runtime build failed"
    fi
    APP_PATH="$(ls -d build/Build/Products/Release-iphonesimulator/*.app 2>/dev/null | head -1)"
    [[ -n "$APP_PATH" ]] || fail "Built .app not found after Release build"
    PLIST_PROXY="$(plutil -extract APPSTACK_DEV_PROXY_URL raw "$APP_PATH/Info.plist")"
    [[ "$PLIST_PROXY" == "$APPSTACK_RUNTIME_PROXY_URL" ]] \
      || fail "Built iOS app does not contain the loopback runtime proxy"
    run_ios_smoke "$APP_PATH" "com.appstack.e2e"
    python3 "$ROOT_DIR/integration-tests/validate_runtime.py" \
      --requests-file "$REQUESTS_FILE" \
      --expected-wrapper-version "$EXPECTED_WRAPPER_VERSION"
    log "✅ iOS hermetic runtime check passed"
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

log "✅ Expo SDK ${SDK_VERSION} / ${PLATFORM} / ${ARCHITECTURE} architecture integration test passed"
