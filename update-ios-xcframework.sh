#!/bin/bash
set -euo pipefail

# Updates the vendored ios/AppstackSDK.xcframework from the public native SDK
# repo's GitHub Releases.
#
# To bump the version, edit VERSION below and re-run this script.

VERSION="4.6.0-rc1"

REPO="appstack-tech/ios-appstack-sdk"
ASSET_NAME="AppstackSDK.xcframework.zip"
DEST_DIR="ios/AppstackSDK.xcframework"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"

# Staged under ios/ so the final replace (below) is a same-filesystem rename,
# not a cross-device copy that could fail halfway through.
TMP_DIR="$(mktemp -d "ios/.xcframework-update.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${ASSET_NAME} ${VERSION} from ${REPO}..."
if ! curl -fL --progress-bar -o "${TMP_DIR}/${ASSET_NAME}" "$URL"; then
  echo "Failed to download ${URL}" >&2
  echo "Check that version ${VERSION} exists at https://github.com/${REPO}/releases" >&2
  exit 1
fi

echo "Verifying checksum against Package.swift@${VERSION}..."
PACKAGE_SWIFT_URL="https://raw.githubusercontent.com/${REPO}/${VERSION}/Package.swift"
PACKAGE_SWIFT_FILE="${TMP_DIR}/Package.swift"
if ! curl -fsSL -o "$PACKAGE_SWIFT_FILE" "$PACKAGE_SWIFT_URL"; then
  echo "Failed to fetch ${PACKAGE_SWIFT_URL} to verify the asset checksum" >&2
  exit 1
fi

EXPECTED_CHECKSUM="$(python3 - "$PACKAGE_SWIFT_FILE" "$URL" <<'PYEOF'
import re
import sys

with open(sys.argv[1]) as f:
    text = f.read()
target_url = sys.argv[2]

pairs = re.findall(r'url:\s*"([^"]+)"\s*,\s*checksum:\s*"([a-f0-9]{64})"', text)
for url, checksum in pairs:
    if url == target_url:
        print(checksum)
        break
PYEOF
)"

if [[ -z "$EXPECTED_CHECKSUM" ]]; then
  echo "Could not find a checksum for ${URL} in ${PACKAGE_SWIFT_URL}" >&2
  exit 1
fi

ACTUAL_CHECKSUM="$(shasum -a 256 "${TMP_DIR}/${ASSET_NAME}" | awk '{print $1}')"
if [[ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]]; then
  echo "Checksum mismatch for ${ASSET_NAME}!" >&2
  echo "  expected: ${EXPECTED_CHECKSUM}" >&2
  echo "  actual:   ${ACTUAL_CHECKSUM}" >&2
  exit 1
fi
echo "Checksum OK (${ACTUAL_CHECKSUM})"

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

echo "Done. ios/AppstackSDK.xcframework is now at version ${VERSION}."
echo "Remember to update CHANGELOG.md and test a pod install before committing."
