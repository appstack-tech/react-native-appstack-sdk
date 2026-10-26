#!/usr/bin/env bash
# Decides which stable version, if any, a commit on main releases.
#
# CHANGELOG.md is the source of truth: the release version is the first section
# below "## [Unreleased]", which must read "## [X.Y.Z] - YYYY-MM-DD". package.json
# keeps a placeholder version; build.yml stamps the real one at publish time.
#
#   * That version already has a tag -> nothing to release (prints release=false).
#   * No tag yet and it is newer than the latest stable tag -> release=true.
#   * Malformed header or a version that goes backwards -> exits 1.
#
# Needs the repository's tags locally (actions/checkout with fetch-depth: 0).
# Writes `version` and `release` to $GITHUB_OUTPUT when set, else to stdout.
set -euo pipefail

CHANGELOG="${1:-CHANGELOG.md}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

# First "## [" header that is not [Unreleased].
HEADER="$(grep -m1 -E '^## \[' <(grep -v -E '^## \[Unreleased\]' "$CHANGELOG") || true)"
if [[ -z "$HEADER" ]]; then
  echo "::error::No released version section found in $CHANGELOG."
  exit 1
fi

# Whole-string match, [.] keeps the dots literal (see build.yml for why).
if [[ ! "$HEADER" =~ ^'## ['([0-9]+[.][0-9]+[.][0-9]+)'] - '[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "::error::Latest changelog header must read '## [X.Y.Z] - YYYY-MM-DD', found: $HEADER"
  exit 1
fi
VERSION="${BASH_REMATCH[1]}"

if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
  echo "$VERSION is already tagged: nothing to release."
  {
    echo "version=$VERSION"
    echo "release=false"
  } >> "$OUT"
  exit 0
fi

LATEST="$(git tag -l | grep -E '^[0-9]+[.][0-9]+[.][0-9]+$' | sort -V | tail -n1 || true)"
if [[ -n "$LATEST" && "$(printf '%s\n%s\n' "$LATEST" "$VERSION" | sort -V | tail -n1)" != "$VERSION" ]]; then
  echo "::error::Changelog version $VERSION is not newer than the latest release $LATEST."
  exit 1
fi

echo "Releasing $VERSION (previous: ${LATEST:-none})."
{
  echo "version=$VERSION"
  echo "release=true"
} >> "$OUT"
