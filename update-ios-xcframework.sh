#!/bin/bash
set -euo pipefail

# Updates the vendored ios/AppstackSDK.xcframework from the public native SDK
# repo's GitHub Releases.
#
# To bump the version, edit VERSION below and re-run this script.

VERSION="4.4.0"

REPO="appstack-tech/ios-appstack-sdk"
ASSET_NAME="AppstackSDK.xcframework.zip"
DEST_DIR="ios/AppstackSDK.xcframework"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${ASSET_NAME} ${VERSION} from ${REPO}..."
if ! curl -fL --progress-bar -o "${TMP_DIR}/${ASSET_NAME}" "$URL"; then
  echo "Failed to download ${URL}" >&2
  echo "Check that version ${VERSION} exists at https://github.com/${REPO}/releases" >&2
  exit 1
fi

echo "Unzipping..."
unzip -q "${TMP_DIR}/${ASSET_NAME}" -d "${TMP_DIR}/extracted"

if [[ ! -d "${TMP_DIR}/extracted/AppstackSDK.xcframework" ]]; then
  echo "Downloaded archive does not contain AppstackSDK.xcframework" >&2
  exit 1
fi

echo "Replacing ${DEST_DIR}..."
rm -rf "$DEST_DIR"
mv "${TMP_DIR}/extracted/AppstackSDK.xcframework" "$DEST_DIR"

echo "Done. ios/AppstackSDK.xcframework is now at version ${VERSION}."
echo "Remember to update CHANGELOG.md and test a pod install before committing."
