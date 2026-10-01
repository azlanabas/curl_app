#!/usr/bin/env bash
#
# Cut a release: regenerate SHA256SUMS, verify everything, commit, tag, push.
#
#   tools/make-release.sh 0.2.0
#
# Refuses to release if the tests fail, if shellcheck complains, if the version in
# bin/curl-app does not match the VERSION file, or if the tree is dirty afterwards.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
cd "$ROOT"

VERSION=${1:-}
[ -n "$VERSION" ] || { printf 'usage: tools/make-release.sh <version>  e.g. 0.2.0\n' >&2; exit 2; }

case "$VERSION" in
  *[!0-9.]*) printf 'error: version must look like 0.2.0\n' >&2; exit 2 ;;
esac

_log() { printf '==> %s\n' "$*"; }

# 1. version consistency: VERSION file and the constant baked into the app
_log "setting version $VERSION"
printf '%s\n' "$VERSION" > VERSION
if grep -q '^CURL_APP_VERSION=' bin/curl-app; then
  sed -i.bak "s|^CURL_APP_VERSION=.*|CURL_APP_VERSION=\"$VERSION\"|" bin/curl-app
  rm -f bin/curl-app.bak
else
  printf 'error: no CURL_APP_VERSION= line in bin/curl-app\n' >&2
  exit 1
fi

# 2. lint
if command -v shellcheck >/dev/null 2>&1; then
  _log "shellcheck"
  shellcheck -S style install.sh uninstall.sh bin/curl-app tests/*.sh tools/*.sh
else
  _log "shellcheck not installed — skipping"
fi

# 3. tests
_log "tests"
bash tests/test_anagram.sh >/dev/null
bash tests/test_install.sh >/dev/null

# 4. checksums
_log "regenerating SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum bin/curl-app > SHA256SUMS
else
  shasum -a 256 bin/curl-app > SHA256SUMS
fi
cat SHA256SUMS

# 5. commit and tag
_log "committing"
git add -A
git commit -m "release: v$VERSION"

_log "tagging v$VERSION"
git tag -a "v$VERSION" -m "v$VERSION"

_log "pushing"
git push origin HEAD
git push origin "v$VERSION"

_log "released v$VERSION"
printf '\n  curl -fsSL https://azlanabas.github.io/curl_app/install.sh | bash\n\n'
