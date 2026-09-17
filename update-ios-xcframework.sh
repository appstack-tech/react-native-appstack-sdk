#!/bin/bash
set -euo pipefail

# Updates the vendored ios/AppstackSDK.xcframework from the public native SDK
# repo's GitHub Releases, and keeps the SwiftPM dependency aligned.
#
# Stable mode (default): vendor the exact released version.
#
#   ./update-ios-xcframework.sh            # uses VERSION below
#   ./update-ios-xcframework.sh 4.7.2      # explicit stable version
#
# Release-candidate mode: vendor the current build from the native SDK's rolling
# RC channel. The SwiftPM dependency is pinned to the channel branch, not to a
# version, and the CocoaPods artifact is the current RC binary. This is a
# temporary testing state — restore the stable `exact:` pin before shipping.
#
#   ./update-ios-xcframework.sh --rc
#
# The stable VERSION below is the default and is what the determinism check
# (__tests__/SwiftPackage.test.js) reads; --rc does not change it.

VERSION="4.7.1"
MODE="stable"

REPO="appstack-tech/ios-appstack-sdk"
ASSET_NAME="AppstackSDK.xcframework.zip"
DEST_DIR="ios/AppstackSDK.xcframework"
SPM_MANIFEST="ios/Package.swift"
RC_BRANCH="rc"

case "${1:-}" in
  "")
    ;;
  --rc | rc)
    MODE="rc"
    ;;
  -*)
    echo "Unknown option: $1" >&2
    echo "Usage: $0 [--rc | <stable-version>]" >&2
    exit 2
    ;;
  *)
    VERSION="$1"
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# The ref whose Package.swift describes the artifact we are about to vendor:
# a version tag for stable, the rolling channel branch for an RC.
if [[ "$MODE" == "rc" ]]; then
  REF="$RC_BRANCH"
  DEPENDENCY_CLAUSE="branch: \"${RC_BRANCH}\""
  CHANNEL_LABEL="release candidate (branch ${RC_BRANCH})"
else
  REF="$VERSION"
  DEPENDENCY_CLAUSE="exact: \"${VERSION}\""
  CHANNEL_LABEL="${VERSION}"
fi

MANIFEST_URL="https://raw.githubusercontent.com/${REPO}/${REF}/Package.swift"

# Staged under ios/ so the final replace (below) is a same-filesystem rename,
# not a cross-device copy that could fail halfway through.
TMP_DIR="$(mktemp -d "ios/.xcframework-update.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Resolving ${CHANNEL_LABEL} artifact from ${REPO}@${REF}..."
PACKAGE_SWIFT_FILE="${TMP_DIR}/Package.swift"
if ! curl -fsSL --retry 3 --retry-delay 2 -o "$PACKAGE_SWIFT_FILE" "$MANIFEST_URL"; then
  echo "Failed to fetch ${MANIFEST_URL}" >&2
  if [[ "$MODE" == "rc" ]]; then
    echo "The ${RC_BRANCH} channel may not have been published yet; run the release workflow for a candidate first." >&2
  else
    echo "Check that version ${VERSION} exists at https://github.com/${REPO}/releases" >&2
  fi
  exit 1
fi

# Read the binaryTarget url + checksum from the manifest rather than assuming
# the asset path, so an upstream rename is followed instead of hardcoded.
MANIFEST_FIELDS="$(python3 - "$PACKAGE_SWIFT_FILE" <<'PYEOF'
import re
import sys

text = open(sys.argv[1]).read()
urls = re.findall(r'url:\s*"(https://[^"]*\.zip)"', text)
checksums = re.findall(r'checksum:\s*"([0-9a-fA-F]{64})"', text)
if len(urls) != 1 or len(checksums) != 1:
    sys.exit(
        f"expected exactly one url and one checksum in {sys.argv[1]}, "
        f"found {len(urls)} url(s) and {len(checksums)} checksum(s)"
    )
print(urls[0], checksums[0].lower())
PYEOF
)" || {
  echo "Could not read the binaryTarget url and checksum from ${MANIFEST_URL}" >&2
  exit 1
}

URL="${MANIFEST_FIELDS%% *}"
EXPECTED_CHECKSUM="${MANIFEST_FIELDS##* }"

if [[ -z "$URL" || -z "$EXPECTED_CHECKSUM" ]]; then
  echo "Could not parse the binaryTarget url and checksum from ${MANIFEST_URL}" >&2
  exit 1
fi

echo "Downloading ${ASSET_NAME} (${CHANNEL_LABEL})..."
if ! curl -fL --progress-bar -o "${TMP_DIR}/${ASSET_NAME}" "$URL"; then
  echo "Failed to download ${URL}" >&2
  exit 1
fi

ACTUAL_CHECKSUM="$(shasum -a 256 "${TMP_DIR}/${ASSET_NAME}" | awk '{print $1}')"
if [[ "$(printf '%s' "$ACTUAL_CHECKSUM" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$EXPECTED_CHECKSUM" | tr '[:upper:]' '[:lower:]')" ]]; then
  echo "Checksum mismatch for ${ASSET_NAME}!" >&2
  echo "  expected: ${EXPECTED_CHECKSUM}  (from ${MANIFEST_URL})" >&2
  echo "  actual:   ${ACTUAL_CHECKSUM}" >&2
  if [[ "$MODE" == "rc" ]]; then
    echo "The RC channel is mutable and was likely republished mid-download; re-run this script." >&2
  fi
  exit 1
fi
echo "Checksum OK (${ACTUAL_CHECKSUM})"

echo "Preparing SwiftPM manifest for native SDK ${CHANNEL_LABEL}..."
if [[ ! -f "$SPM_MANIFEST" ]]; then
  echo "Missing ${SPM_MANIFEST}; cannot keep CocoaPods and SwiftPM versions aligned" >&2
  exit 1
fi
STAGED_SPM_MANIFEST="${TMP_DIR}/ReactNativeAppstackSdk.Package.swift"
cp -p "$SPM_MANIFEST" "$STAGED_SPM_MANIFEST"
python3 - "$STAGED_SPM_MANIFEST" "$DEPENDENCY_CLAUSE" <<'PYEOF'
import re
import sys

path, clause = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as stream:
    source = stream.read()

# Rewrites the version requirement in place, whichever form it currently has,
# so switching between stable (`exact:`) and RC (`branch:`) needs no manual edit.
pattern = re.compile(
    r'(\.package\(\s*'
    r'url:\s*"https://github\.com/appstack-tech/ios-appstack-sdk\.git",\s*'
    r')(?:exact|branch):\s*"[^"]+"'
    r'(\s*\))',
    re.DOTALL,
)
updated, count = pattern.subn(lambda match: f"{match.group(1)}{clause}{match.group(2)}", source)
if count != 1:
    raise SystemExit(
        f"Expected exactly one public Appstack SwiftPM dependency in {path}; found {count}"
    )

with open(path, "w", encoding="utf-8") as stream:
    stream.write(updated)
PYEOF

echo "Unzipping..."
unzip -q "${TMP_DIR}/${ASSET_NAME}" -d "${TMP_DIR}/extracted"

NEW_XCFRAMEWORK="${TMP_DIR}/extracted/AppstackSDK.xcframework"
if [[ ! -d "$NEW_XCFRAMEWORK" ]]; then
  echo "Downloaded archive does not contain AppstackSDK.xcframework" >&2
  exit 1
fi

echo "Validating xcframework bundle..."
python3 - "$NEW_XCFRAMEWORK" <<'PYEOF'
import os
import plistlib
import sys

bundle = sys.argv[1]
root = os.path.realpath(bundle)

if os.path.islink(bundle):
    sys.exit("xcframework root is a symlink")

info_plist = os.path.join(root, "Info.plist")
if not os.path.isfile(info_plist):
    sys.exit("Missing Info.plist in xcframework")

with open(info_plist, "rb") as f:
    plist = plistlib.load(f)

libraries = plist.get("AvailableLibraries") or []
if not libraries:
    sys.exit("Info.plist has no AvailableLibraries")

for lib in libraries:
    identifier = lib.get("LibraryIdentifier")
    binary_path = lib.get("BinaryPath")
    if not identifier or not binary_path:
        sys.exit(f"Malformed library entry in Info.plist: {lib}")

    slice_dir = os.path.join(root, identifier)
    if os.path.islink(slice_dir) or not os.path.isdir(slice_dir):
        sys.exit(f"Missing or symlinked slice directory: {identifier}")

    binary_full = os.path.realpath(os.path.join(slice_dir, binary_path))
    if not (binary_full == root or binary_full.startswith(root + os.sep)):
        sys.exit(f"Binary path escapes xcframework bundle: {identifier}/{binary_path}")

    if not os.path.isfile(binary_full) or os.path.getsize(binary_full) == 0:
        sys.exit(f"Missing or empty binary for {identifier}: {binary_path}")

print(f"Validated {len(libraries)} librar{'y' if len(libraries) == 1 else 'ies'} in xcframework")
PYEOF

echo "Replacing ${DEST_DIR}..."
BACKUP_DIR="${TMP_DIR}/backup"
BACKUP_SPM_MANIFEST="${TMP_DIR}/Package.swift.backup"
cp -p "$SPM_MANIFEST" "$BACKUP_SPM_MANIFEST"
if [[ -e "$DEST_DIR" ]]; then
  mv "$DEST_DIR" "$BACKUP_DIR"
fi

if ! mv "$NEW_XCFRAMEWORK" "$DEST_DIR"; then
  echo "Failed to install new xcframework; restoring previous version" >&2
  if [[ -e "$BACKUP_DIR" ]]; then
    if ! mv "$BACKUP_DIR" "$DEST_DIR"; then
      echo "Failed to restore backup from ${BACKUP_DIR}; leaving it in place for manual recovery." >&2
      trap - EXIT
    fi
  fi
  exit 1
fi

if ! mv "$STAGED_SPM_MANIFEST" "$SPM_MANIFEST"; then
  echo "Failed to update ${SPM_MANIFEST}; restoring previous iOS artifacts" >&2
  if [[ -e "$DEST_DIR" ]]; then
    mv "$DEST_DIR" "$NEW_XCFRAMEWORK" || true
  fi
  if [[ -e "$BACKUP_DIR" ]]; then
    mv "$BACKUP_DIR" "$DEST_DIR" || true
  fi
  cp -p "$BACKUP_SPM_MANIFEST" "$SPM_MANIFEST" || true
  exit 1
fi

if [[ "$MODE" == "rc" ]]; then
  echo "Done. ios/AppstackSDK.xcframework is now the current ${RC_BRANCH} candidate (${ACTUAL_CHECKSUM})."
  echo "Done. ${SPM_MANIFEST} now resolves ios-appstack-sdk branch ${RC_BRANCH}."
  echo "This is a temporary test state: restore the stable exact: pin before releasing."
else
  echo "Done. ios/AppstackSDK.xcframework is now at version ${VERSION}."
  echo "Done. ${SPM_MANIFEST} now resolves ios-appstack-sdk ${VERSION}."
fi
echo "Remember to update CHANGELOG.md and run the CocoaPods and SwiftPM integration tests before committing."
