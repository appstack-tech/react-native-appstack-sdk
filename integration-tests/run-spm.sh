#!/bin/bash
set -Eeuo pipefail

# Integration test: verify the SDK autolinks and compiles through React Native's
# experimental Swift Package Manager integration in a fresh bare app.

REACT_NATIVE_VERSION="${REACT_NATIVE_VERSION:-0.87.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${SPM_INTEGRATION_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/appstack-spm.XXXXXX")}"
APP_NAME="AppstackSpmFixture"
APP_DIR="${WORK_DIR}/${APP_NAME}"
RUNTIME_DIR="${WORK_DIR}/runtime"
REQUESTS_FILE="${RUNTIME_DIR}/requests.jsonl"
MOCK_LOG="${RUNTIME_DIR}/mock-server.log"
RUNTIME_LOG="${RUNTIME_DIR}/simulator.log"
MOCK_PID=""
RUNTIME_LOG_PID=""
SIMULATOR_UDID=""
INSTALLED_BUNDLE_ID=""

log()  { echo "▶ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

cleanup() {
  local status=$?
  set +e
  if [[ -n "$RUNTIME_LOG_PID" ]]; then
    kill "$RUNTIME_LOG_PID" 2>/dev/null
    wait "$RUNTIME_LOG_PID" 2>/dev/null
  fi
  if [[ -n "$SIMULATOR_UDID" && -n "$INSTALLED_BUNDLE_ID" ]]; then
    xcrun simctl terminate "$SIMULATOR_UDID" "$INSTALLED_BUNDLE_ID" >/dev/null 2>&1
    xcrun simctl uninstall "$SIMULATOR_UDID" "$INSTALLED_BUNDLE_ID" >/dev/null 2>&1
  fi
  if [[ -n "$MOCK_PID" ]]; then
    kill "$MOCK_PID" 2>/dev/null
    wait "$MOCK_PID" 2>/dev/null
  fi
  if (( status != 0 )); then
    if [[ -s "$RUNTIME_LOG" ]]; then
      echo "---- simulator diagnostics ----" >&2
      grep -iE 'APPSTACK_RUNTIME|Appstack|fatal|exception|bytecode|terminating app' "$RUNTIME_LOG" \
        | tail -80 >&2 || true
    fi
    if [[ -s "$MOCK_LOG" ]]; then
      echo "---- recording backend diagnostics ----" >&2
      tail -40 "$MOCK_LOG" >&2
    fi
  fi
  return "$status"
}
trap cleanup EXIT

start_runtime_backend() {
  mkdir -p "$RUNTIME_DIR"
  : > "$RUNTIME_LOG"
  local port_file="${RUNTIME_DIR}/http-port"

  python3 "$ROOT_DIR/integration-tests/mock_server.py" \
    --port-file "$port_file" \
    --requests-file "$REQUESTS_FILE" \
    > "$MOCK_LOG" 2>&1 &
  MOCK_PID=$!

  for _ in $(seq 1 100); do
    [[ -s "$port_file" ]] && break
    kill -0 "$MOCK_PID" 2>/dev/null \
      || fail "Runtime recording backend exited during startup"
    sleep 0.1
  done
  [[ -s "$port_file" ]] || fail "Runtime recording backend did not publish its port"
  local port
  port="$(<"$port_file")"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port > 0 && port <= 65535 )) \
    || fail "Runtime recording backend published an invalid port"
  export APPSTACK_RUNTIME_PROXY_URL="http://127.0.0.1:${port}"
  log "Loopback recording backend ready at ${APPSTACK_RUNTIME_PROXY_URL}"
}

configure_runtime_app() {
  local template="$ROOT_DIR/integration-tests/spm-runtime-app.tsx"
  local entrypoint="$APP_DIR/App.tsx"
  local info_plist="$APP_DIR/ios/$APP_NAME/Info.plist"
  [[ -f "$template" ]] || fail "SwiftPM runtime entrypoint template is missing"
  [[ -f "$info_plist" ]] || fail "Generated app Info.plist is missing"

  cp "$template" "$entrypoint"
  APPSTACK_RUNTIME_RESULT_URL="${APPSTACK_RUNTIME_PROXY_URL}/runtime-result" \
    node -e '
      const fs = require("fs");
      const path = process.argv[1];
      const marker = "__APPSTACK_RUNTIME_RESULT_URL__";
      const source = fs.readFileSync(path, "utf8");
      if (!source.includes(marker)) throw new Error("runtime result URL marker missing");
      fs.writeFileSync(path, source.replace(marker, process.env.APPSTACK_RUNTIME_RESULT_URL));
    ' "$entrypoint"

  /usr/libexec/PlistBuddy -c "Delete :APPSTACK_DEV_PROXY_URL" "$info_plist" \
    >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c \
    "Add :APPSTACK_DEV_PROXY_URL string ${APPSTACK_RUNTIME_PROXY_URL}" "$info_plist"
  /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity" "$info_plist" \
    >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$info_plist"
  if /usr/libexec/PlistBuddy -c \
      "Print :NSAppTransportSecurity:NSAllowsLocalNetworking" "$info_plist" \
      >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c \
      "Set :NSAppTransportSecurity:NSAllowsLocalNetworking true" "$info_plist"
  else
    /usr/libexec/PlistBuddy -c \
      "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$info_plist"
  fi
}

run_runtime_probe() {
  local app_path="$1"
  [[ -d "$app_path" ]] || fail "Release app was not produced at ${app_path}"
  INSTALLED_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$app_path/Info.plist")"

  SIMULATOR_UDID="$(xcrun simctl list devices booted \
    | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [[ -z "$SIMULATOR_UDID" ]]; then
    SIMULATOR_UDID="$(xcrun simctl list devices available \
      | grep -E 'iPhone' | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
    [[ -n "$SIMULATOR_UDID" ]] || fail "No iOS simulator is available"
    log "Booting simulator ${SIMULATOR_UDID}..."
    xcrun simctl boot "$SIMULATOR_UDID" || true
  fi
  xcrun simctl bootstatus "$SIMULATOR_UDID" >/dev/null 2>&1 || true

  log "Installing and launching ${INSTALLED_BUNDLE_ID}..."
  xcrun simctl install "$SIMULATOR_UDID" "$app_path" \
    || fail "Failed to install SwiftPM runtime app"
  xcrun simctl spawn "$SIMULATOR_UDID" log stream --level debug --style syslog \
    --predicate "process == \"${APP_NAME}\" OR eventMessage CONTAINS[c] \"Appstack\" OR eventMessage CONTAINS \"APPSTACK_RUNTIME\"" \
    > "$RUNTIME_LOG" 2>&1 &
  RUNTIME_LOG_PID=$!
  sleep 1
  xcrun simctl launch "$SIMULATOR_UDID" "$INSTALLED_BUNDLE_ID" >/dev/null \
    || fail "Failed to launch SwiftPM runtime app"

  log "Waiting for the terminal runtime result (up to 120s)..."
  for _ in $(seq 1 60); do
    if grep -qE '/runtime-result.*"kind": "failure"' "$REQUESTS_FILE" 2>/dev/null \
        || grep -qE 'APPSTACK_RUNTIME_FAIL:|Unhandled JS Exception|Wrong bytecode version' \
          "$RUNTIME_LOG"; then
      fail "SwiftPM runtime probe reported an error"
    fi
    if grep -qE '/runtime-result.*"kind": "success"' "$REQUESTS_FILE" 2>/dev/null; then
      kill "$RUNTIME_LOG_PID" 2>/dev/null || true
      wait "$RUNTIME_LOG_PID" 2>/dev/null || true
      RUNTIME_LOG_PID=""
      return 0
    fi
    sleep 2
  done
  fail "Timed out waiting for the SwiftPM runtime result"
}

log "React Native ${REACT_NATIVE_VERSION} SwiftPM integration test (workdir: ${WORK_DIR})"

cd "$ROOT_DIR"
if [[ ! -d node_modules ]]; then
  log "Installing SDK dependencies..."
  npm ci
fi
PACKAGE_VERSION="$(node -p "require('./package.json').version")"
EXPECTED_WRAPPER_VERSION="react-native-${PACKAGE_VERSION}"

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
BUILD_LOG="${WORK_DIR}/xcodebuild-debug.log"
if ! xcodebuild \
    -project "ios/${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "${WORK_DIR}/derived-data-debug" \
    -packageAuthorizationProvider netrc \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    -quiet \
    build > "$BUILD_LOG" 2>&1; then
  tail -200 "$BUILD_LOG" >&2
  fail "SwiftPM simulator build failed (full log: ${BUILD_LOG})"
fi

start_runtime_backend
configure_runtime_app

log "Building a self-contained Release app for the runtime probe..."
RELEASE_BUILD_LOG="${RUNTIME_DIR}/xcodebuild-release.log"
# React Native 0.87's experimental SwiftPM downloader currently resolves a
# newer Hermes runtime than the hermesc binary shipped by its npm template.
# Keep Hermes as the native runtime, but embed source JS so that the smoke test
# is not coupled to those mismatched bytecode versions.
if ! xcodebuild \
    -project "ios/${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "${WORK_DIR}/derived-data-release" \
    -packageAuthorizationProvider netrc \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    USE_HERMES=false \
    -quiet \
    build > "$RELEASE_BUILD_LOG" 2>&1; then
  tail -200 "$RELEASE_BUILD_LOG" >&2
  fail "SwiftPM Release build failed (full log: ${RELEASE_BUILD_LOG})"
fi

APP_PATH="$(find "${WORK_DIR}/derived-data-release/Build/Products/Release-iphonesimulator" \
  -maxdepth 1 -name '*.app' -type d -print -quit)"
[[ -n "$APP_PATH" ]] || fail "SwiftPM Release build did not produce an app"
PLIST_PROXY="$(plutil -extract APPSTACK_DEV_PROXY_URL raw "$APP_PATH/Info.plist")"
[[ "$PLIST_PROXY" == "$APPSTACK_RUNTIME_PROXY_URL" ]] \
  || fail "Release app does not contain the loopback runtime proxy"

run_runtime_probe "$APP_PATH"
python3 "$ROOT_DIR/integration-tests/validate_runtime.py" \
  --requests-file "$REQUESTS_FILE" \
  --expected-wrapper-version "$EXPECTED_WRAPPER_VERSION"

log "✅ React Native ${REACT_NATIVE_VERSION} SwiftPM build and runtime test passed"
