#!/usr/bin/env bash
#
# curl_app installer for macOS and Linux.
#
# Usage:
#   curl -fsSL https://azlanabas.github.io/curl_app/install.sh | bash
#   curl -fsSL https://azlanabas.github.io/curl_app/install.sh | CURL_APP_VERSION=0.1.0 bash
#   curl -fsSL https://azlanabas.github.io/curl_app/install.sh | bash -s -- --dir /usr/local/curl-app
#
# Environment:
#   CURL_APP_VERSION         install a specific version, e.g. 0.1.0 (default: latest release)
#   CURL_APP_INSTALL_DIR     installation directory, default $HOME/.curl-app
#   CURL_APP_CHANNEL         stable (default) or edge (main branch, unversioned)
#   CURL_APP_NO_MODIFY_PATH  non-empty: do not touch your shell rc file
#   CURL_APP_SOURCE_DIR      development only: install from a local checkout
#
# Flags:
#   -h, --help               show help
#   --version V              install a specific version
#   --channel stable|edge    choose the release channel
#   --dir PATH               installation directory
#   --uninstall              remove an existing installation and exit
#
# This script NEVER reads standard input. When it is invoked as
# `curl -fsSL <url> | bash`, stdin is the script itself — anything that prompted
# would hang. All configuration is via environment variables and flags.

# shellcheck disable=SC2016
#   SC2016: the single-quoted '$PATH' further down is intentional. It must be
#   written literally into the user's shell rc file (or printed for the user to
#   paste), not expanded by this script.

set -eu

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'error: this installer must run under bash — use: curl -fsSL <url> | bash\n' >&2
  exit 1
fi

APP_NAME="curl-app"
REPO_SLUG="azlanabas/curl_app"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}"
SITE_BASE="https://azlanabas.github.io/curl_app"
MARKER="# curl_app"

INSTALL_DIR="${CURL_APP_INSTALL_DIR:-$HOME/.curl-app}"
VERSION_REQ="${CURL_APP_VERSION:-}"
CHANNEL="${CURL_APP_CHANNEL:-stable}"
NO_MODIFY_PATH="${CURL_APP_NO_MODIFY_PATH:-}"
SOURCE_DIR="${CURL_APP_SOURCE_DIR:-}"
DO_UNINSTALL=0
REF=""

# ------------------------------------------------------------------- output
_log() { printf '==> %s\n' "$*"; }
_warn() { printf 'warning: %s\n' "$*" >&2; }
_err() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
_have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
curl_app installer

Usage:
  curl -fsSL ${SITE_BASE}/install.sh | bash
  curl -fsSL ${SITE_BASE}/install.sh | CURL_APP_VERSION=0.1.0 bash
  curl -fsSL ${SITE_BASE}/install.sh | bash -s -- --dir /opt/curl-app

Options:
  -h, --help               Show this help
  --version V              Install a specific version (default: latest)
  --channel stable|edge    stable = tagged release (default), edge = main branch
  --dir PATH               Installation directory
  --uninstall              Remove an existing installation

Environment:
  CURL_APP_VERSION         Same as --version
  CURL_APP_INSTALL_DIR     Same as --dir (default \$HOME/.curl-app)
  CURL_APP_CHANNEL         Same as --channel
  CURL_APP_NO_MODIFY_PATH  Non-empty: leave your shell rc file alone
  CURL_APP_SOURCE_DIR      Development only: install from a local checkout
EOF
}

# ------------------------------------------------------------------ fetching
_fetch() {
  if _have curl; then
    curl -fsSL "$1"
  elif _have wget; then
    wget -qO- "$1"
  else
    _err "curl or wget is required"
  fi
}

_sha256() {
  if _have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif _have shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    _err "sha256sum or shasum is required to verify the download"
  fi
}

# --------------------------------------------------------------- arg parsing
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --version)
      [ $# -ge 2 ] || _err "--version requires a value"
      VERSION_REQ=$2
      shift 2
      ;;
    --version=*)
      VERSION_REQ=${1#--version=}
      shift
      ;;
    --channel)
      [ $# -ge 2 ] || _err "--channel requires a value"
      CHANNEL=$2
      shift 2
      ;;
    --channel=*)
      CHANNEL=${1#--channel=}
      shift
      ;;
    --dir)
      [ $# -ge 2 ] || _err "--dir requires a value"
      INSTALL_DIR=$2
      shift 2
      ;;
    --dir=*)
      INSTALL_DIR=${1#--dir=}
      shift
      ;;
    --uninstall)
      DO_UNINSTALL=1
      shift
      ;;
    *)
      _err "unknown option: $1 (try --help)"
      ;;
  esac
done

case "$CHANNEL" in
  stable|edge) ;;
  *) _err "unknown channel: $CHANNEL (expected stable or edge)" ;;
esac

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) _err "unsupported operating system: $(uname -s) — macOS and Linux only" ;;
esac

# -------------------------------------------------------------------- rc file
_rc_file() {
  case "${SHELL:-}" in
    */zsh) printf '%s' "$HOME/.zshrc" ;;
    */bash)
      if [ -f "$HOME/.bashrc" ]; then
        printf '%s' "$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        printf '%s' "$HOME/.bash_profile"
      elif [ -f "$HOME/.profile" ]; then
        printf '%s' "$HOME/.profile"
      else
        printf '%s' "$HOME/.bashrc"
      fi
      ;;
    */fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
    *) printf '%s' "$HOME/.profile" ;;
  esac
}

_strip_rc() {
  rc=$1
  tmp="$rc.curl_app.tmp"
  awk -v m="$MARKER" '
    { line[NR] = $0 }
    END {
      n = NR
      for (i = 1; i <= n; i++) {
        if (line[i] == m || (line[i] == "" && i + 1 <= n && line[i+1] == m)) {
          if (line[i] == "") i++
          if (i + 1 <= n && (index(line[i+1], "PATH=") > 0 || index(line[i+1], "fish_add_path") > 0)) i++
          continue
        }
        print line[i]
      }
    }
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
}

_uninstall() {
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    _log "removed $INSTALL_DIR"
  else
    _log "nothing installed at $INSTALL_DIR"
  fi
  rc=$(_rc_file)
  if [ -f "$rc" ] && grep -qF "$INSTALL_DIR/bin" "$rc" 2>/dev/null; then
    _strip_rc "$rc"
    _log "removed the PATH entry from $rc"
  fi
  _log "uninstalled"
  exit 0
}

if [ "$DO_UNINSTALL" -eq 1 ]; then
  _uninstall
fi

# --------------------------------------------------------- resolve the source
if [ -n "$SOURCE_DIR" ]; then
  [ -d "$SOURCE_DIR" ] || _err "CURL_APP_SOURCE_DIR does not exist: $SOURCE_DIR"
  [ -f "$SOURCE_DIR/bin/$APP_NAME" ] || _err "no bin/$APP_NAME in $SOURCE_DIR"
  REF="local"
  if [ -f "$SOURCE_DIR/VERSION" ]; then
    VERSION_STR=$(tr -d ' \t\r\n' < "$SOURCE_DIR/VERSION")
  else
    VERSION_STR="unknown"
  fi
  [ -n "$VERSION_STR" ] || VERSION_STR="unknown"
  _log "installing from local checkout: $SOURCE_DIR (version $VERSION_STR)"
elif [ "$CHANNEL" = "edge" ]; then
  REF="main"
  VERSION_STR="edge"
  _warn "edge channel: installing the unversioned main branch"
else
  VERSION_STR="$VERSION_REQ"
  if [ -z "$VERSION_STR" ]; then
    _log "resolving the latest version"
    VERSION_STR=$(_fetch "$RAW_BASE/main/VERSION" | tr -d ' \t\r\n')
  fi
  [ -n "$VERSION_STR" ] || _err "could not determine the latest version"
  REF="v$VERSION_STR"
fi

# ------------------------------------------------------------------- download
mkdir -p "$INSTALL_DIR/bin"
TMP="$INSTALL_DIR/bin/.$APP_NAME.tmp"
SUMS_TMP="$INSTALL_DIR/.SHA256SUMS.tmp"
cleanup() { rm -f "$TMP" "$SUMS_TMP"; }
trap cleanup EXIT

_fetch_source() {
  if [ -n "$SOURCE_DIR" ]; then
    cat "$SOURCE_DIR/bin/$APP_NAME"
  else
    _fetch "$RAW_BASE/$REF/bin/$APP_NAME"
  fi
}

_fetch_sums() {
  if [ -n "$SOURCE_DIR" ]; then
    cat "$SOURCE_DIR/SHA256SUMS"
  else
    _fetch "$RAW_BASE/$REF/SHA256SUMS"
  fi
}

_log "downloading $APP_NAME $VERSION_STR"
_fetch_source > "$TMP" || _err "download failed ($REF)"
_fetch_sums > "$SUMS_TMP" || _err "could not fetch SHA256SUMS for $REF"

[ -s "$TMP" ] || _err "downloaded file is empty"
head -n 1 "$TMP" | grep -q '^#!' || _err "downloaded file is not a script — refusing to install it"

# ------------------------------------------------------------------- verify
expected=$(awk -v f="bin/$APP_NAME" '$2 == f || $2 == "*" f { print $1; exit }' "$SUMS_TMP")
[ -n "$expected" ] || _err "no checksum for bin/$APP_NAME in SHA256SUMS"
actual=$(_sha256 "$TMP")
expected_lc=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
actual_lc=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
if [ "$expected_lc" != "$actual_lc" ]; then
  _err "checksum mismatch for $APP_NAME
  expected $expected_lc
  actual   $actual_lc
Refusing to install a payload that does not match its published checksum."
fi
_log "checksum verified"

# ------------------------------------------------------------------- install
chmod 755 "$TMP"
mv "$TMP" "$INSTALL_DIR/bin/$APP_NAME"
printf '%s\n' "$VERSION_STR" > "$INSTALL_DIR/VERSION"
_log "installed to $INSTALL_DIR/bin/$APP_NAME"

# ---------------------------------------------------------------------- PATH
case ":$PATH:" in
  *":$INSTALL_DIR/bin:"*)
    _log "$INSTALL_DIR/bin is already on your PATH"
    ;;
  *)
    if [ -n "$NO_MODIFY_PATH" ]; then
      _warn "not touching your shell config (CURL_APP_NO_MODIFY_PATH is set)"
      _warn "add this yourself: export PATH=\"$INSTALL_DIR/bin:\$PATH\""
    else
      rc=$(_rc_file)
      mkdir -p "$(dirname "$rc")" 2>/dev/null || true
      if [ -f "$rc" ] && grep -qsF "$INSTALL_DIR/bin" "$rc"; then
        _log "$rc already references $INSTALL_DIR/bin"
      else
        case "$rc" in
          *fish*)
            printf '\n%s\nfish_add_path "%s/bin"\n' "$MARKER" "$INSTALL_DIR" >> "$rc"
            ;;
          *)
            printf '\n%s\nexport PATH="%s/bin:$PATH"\n' "$MARKER" "$INSTALL_DIR" >> "$rc"
            ;;
        esac
        _log "added $INSTALL_DIR/bin to PATH in $rc"
      fi
    fi
    ;;
esac

printf '\n'
_log "$APP_NAME $VERSION_STR is installed."
printf '\n  Open a new terminal (or run: export PATH="%s/bin:$PATH") and then:\n\n' "$INSTALL_DIR"
printf '      %s\n\n' "$APP_NAME"
printf '  Uninstall with:\n\n'
printf '      curl -fsSL %s/uninstall.sh | bash\n\n' "$SITE_BASE"
