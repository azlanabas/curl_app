#!/usr/bin/env bash
# Installer tests. Every case runs in a throwaway HOME with a stripped environment,
# so nothing here can touch the real machine's shell config.
set -u
LC_ALL=C
export LC_ALL

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)
BASH_BIN=${BASH_BIN:-bash}

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

SB=$(mktemp -d "${TMPDIR:-/tmp}/curl-app-test.XXXXXX")
trap 'rm -rf "$SB"' EXIT

# A sandbox HOME with a sentinel line in .bashrc, so we can prove the installer
# only ever adds its own block and uninstall leaves everything else intact.
mkhome() {
  h="$SB/$1"
  mkdir -p "$h"
  printf '# pre-existing user config\nexport SENTINEL=1\n' > "$h/.bashrc"
  printf '%s' "$h"
}

# run installer/uninstaller in a fully controlled environment
# shellcheck disable=SC2068
run_in() { # <home> <script> [args...]
  h=$1; s=$2; shift 2
  env -i HOME="$h" PATH=/usr/bin:/bin SHELL=/bin/bash \
    CURL_APP_SOURCE_DIR="$SOURCE_DIR" \
    CURL_APP_NO_MODIFY_PATH="${NMP:-}" \
    "$BASH_BIN" "$s" ${@+"$@"} > "$SB/out.log" 2>&1
}

# ---------------------------------------------------------------- case 1
# Clean install from a local checkout.
H1=$(mkhome home1)
SOURCE_DIR="$REPO_ROOT"
if run_in "$H1" "$REPO_ROOT/install.sh"; then
  BIN="$H1/.curl-app/bin/curl-app"
  if [ -x "$BIN" ]; then ok "clean install places an executable at ~/.curl-app/bin/curl-app"
  else no "clean install places an executable at ~/.curl-app/bin/curl-app" "$(cat "$SB/out.log")"; fi

  if [ "$("$BASH_BIN" "$BIN" --version 2>/dev/null)" = "curl-app 0.1.0" ]; then
    ok "installed binary runs and reports its version"
  else no "installed binary runs and reports its version" "got: $("$BASH_BIN" "$BIN" --version 2>&1)"; fi

  if printf 'silent\n' | "$BASH_BIN" "$BIN" --word listen >/dev/null 2>&1; then
    ok "installed binary answers a query correctly"
  else no "installed binary answers a query correctly"; fi

  if [ -f "$H1/.curl-app/VERSION" ]; then ok "VERSION file written into the install dir"
  else no "VERSION file written into the install dir"; fi

  if [ "$(grep -c '^# curl_app$' "$H1/.bashrc")" = "1" ]; then ok "PATH block added to .bashrc exactly once"
  else no "PATH block added to .bashrc exactly once" "$(cat "$H1/.bashrc")"; fi

  if grep -q 'export PATH=.*\.curl-app/bin' "$H1/.bashrc"; then ok "PATH block exports the install dir"
  else no "PATH block exports the install dir" "$(cat "$H1/.bashrc")"; fi
else
  no "clean install exits 0" "$(cat "$SB/out.log")"
fi

# ---------------------------------------------------------------- case 2
# Idempotency: installing twice must not duplicate the rc block.
run_in "$H1" "$REPO_ROOT/install.sh" >/dev/null 2>&1
if [ "$(grep -c '^# curl_app$' "$H1/.bashrc")" = "1" ]; then
  ok "re-install is idempotent (still one PATH block)"
else
  no "re-install is idempotent (still one PATH block)" "$(grep -c '^# curl_app$' "$H1/.bashrc") blocks"
fi

# ---------------------------------------------------------------- case 3
# Optimisation: a checksum mismatch must fail closed and install nothing.
H3=$(mkhome home3)
TAMPERED="$SB/tampered"
cp -R "$REPO_ROOT" "$TAMPERED"
printf '\n# tampered\n' >> "$TAMPERED/bin/curl-app"   # content changed, SHA256SUMS left stale
SOURCE_DIR="$TAMPERED"
if run_in "$H3" "$TAMPERED/install.sh"; then
  no "tampered payload is rejected" "installer exited 0 — checksum verification is not enforced"
else
  if grep -qi 'checksum' "$SB/out.log"; then ok "tampered payload is rejected"
  else no "tampered payload is rejected" "non-zero exit but no checksum message: $(cat "$SB/out.log")"; fi
  if [ ! -e "$H3/.curl-app/bin/curl-app" ]; then ok "tampered payload installs nothing"
  else no "tampered payload installs nothing"; fi
fi
SOURCE_DIR="$REPO_ROOT"

# ---------------------------------------------------------------- case 4
# NO_MODIFY_PATH must leave the shell config untouched.
H4=$(mkhome home4)
NMP=1
if run_in "$H4" "$REPO_ROOT/install.sh"; then
  if [ "$(grep -c '^# curl_app$' "$H4/.bashrc")" = "0" ]; then ok "CURL_APP_NO_MODIFY_PATH leaves the rc file alone"
  else no "CURL_APP_NO_MODIFY_PATH leaves the rc file alone"; fi
else
  no "install with NO_MODIFY_PATH exits 0" "$(cat "$SB/out.log")"
fi
NMP=

# ---------------------------------------------------------------- case 5
# Uninstall restores the rc file and removes the install dir.
if run_in "$H1" "$REPO_ROOT/uninstall.sh"; then
  if [ ! -d "$H1/.curl-app" ]; then ok "uninstall removes the install directory"
  else no "uninstall removes the install directory"; fi
  if [ "$(grep -c '^# curl_app$' "$H1/.bashrc")" = "0" ]; then ok "uninstall removes the PATH block"
  else no "uninstall removes the PATH block" "$(cat "$H1/.bashrc")"; fi
  if grep -q 'SENTINEL=1' "$H1/.bashrc"; then ok "uninstall preserves the rest of the rc file"
  else no "uninstall preserves the rest of the rc file" "$(cat "$H1/.bashrc")"; fi
else
  no "uninstall exits 0" "$(cat "$SB/out.log")"
fi

# ---------------------------------------------------------------- case 6
# Missing source must fail loudly rather than install something empty.
H6=$(mkhome home6)
SOURCE_DIR="$SB/does-not-exist"
if run_in "$H6" "$REPO_ROOT/install.sh"; then
  no "missing payload fails the install" "exited 0"
else
  ok "missing payload fails the install"
fi
SOURCE_DIR="$REPO_ROOT"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
