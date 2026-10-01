#!/usr/bin/env bash
#
# curl_app uninstaller for macOS and Linux.
#
#   curl -fsSL https://azlanabas.github.io/curl_app/uninstall.sh | bash
#
# Removes the install directory and the PATH block this project added to your
# shell rc file. Nothing else in the rc file is touched.
#
# Environment:
#   CURL_APP_INSTALL_DIR   install directory, default $HOME/.curl-app

set -eu

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'error: this uninstaller must run under bash — use: curl -fsSL <url> | bash\n' >&2
  exit 1
fi

INSTALL_DIR="${CURL_APP_INSTALL_DIR:-$HOME/.curl-app}"
MARKER="# curl_app"

_log() { printf '==> %s\n' "$*"; }

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
  cp "$rc" "$rc.curl_app.bak"
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

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) printf 'error: unsupported operating system: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

removed=0

if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  _log "removed $INSTALL_DIR"
  removed=1
else
  _log "nothing installed at $INSTALL_DIR"
fi

rc=$(_rc_file)
if [ -f "$rc" ] && grep -qF "$INSTALL_DIR/bin" "$rc" 2>/dev/null; then
  _strip_rc "$rc"
  _log "removed the PATH entry from $rc (backup: $rc.curl_app.bak)"
fi

if [ "$removed" -eq 1 ]; then
  _log "curl-app uninstalled. Open a new terminal to pick up the change."
else
  _log "nothing to uninstall."
fi
