#!/usr/bin/env bash
# Behaviour tests for bin/curl-app. Black-box only: the CLI contract is exercised,
# never the internals.
set -u
LC_ALL=C
export LC_ALL

HERE=$(cd "$(dirname "$0")" && pwd)
APP="$HERE/../bin/curl-app"
BASH_BIN=${BASH_BIN:-bash}

pass=0
fail=0

# check <label> <expected_exit> <expected_regex> -- <command...>
check() {
  label=$1; want_code=$2; want_re=$3
  shift 3
  out=$("$@" 2>&1)
  code=$?
  ok=1
  [ "$code" -eq "$want_code" ] || ok=0
  if ! printf '%s' "$out" | grep -Eq "$want_re"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$label"
    printf '       want exit=%s regex=%s\n' "$want_code" "$want_re"
    printf '       got  exit=%s\n' "$code"
    printf '       out  %s\n' "$out"
  fi
}

if [ ! -x "$APP" ]; then
  printf 'FATAL: %s is missing or not executable\n' "$APP"
  exit 1
fi

check "listen/silent -> anagram"          0 'IS an anagram'  "$BASH_BIN" "$APP" --word listen silent
check "listen/banana -> not an anagram"   1 'NOT an anagram' "$BASH_BIN" "$APP" --word listen banana
check "case is ignored"                   0 'IS an anagram'  "$BASH_BIN" "$APP" --word Listen SILENT
check "punctuation is ignored"            0 'IS an anagram'  "$BASH_BIN" "$APP" --word 'listen!' 's-i-l-e-n-t'
check "identical word is an anagram"      0 'identical'      "$BASH_BIN" "$APP" --word listen listen
check "differing lengths -> negative"     1 'NOT an anagram' "$BASH_BIN" "$APP" --word abc abcd
check "two-letter anagram"                0 'IS an anagram'  "$BASH_BIN" "$APP" --word ab ba
check "identical single letter"           0 'identical'      "$BASH_BIN" "$APP" --word a a
check "heart/earth"                       0 'IS an anagram'  "$BASH_BIN" "$APP" --word heart earth
check "empty guess -> usage error"        2 'empty'          "$BASH_BIN" "$APP" --word listen ''
check "non-letters only -> usage error"   2 'empty'          "$BASH_BIN" "$APP" --word listen '12345'
check "unknown option -> usage error"     2 'unknown option' "$BASH_BIN" "$APP" --bogus
check "--help exits 0"                    0 'anagram challenge' "$BASH_BIN" "$APP" --help
check "--version prints the version"      0 '0\.1\.0'        "$BASH_BIN" "$APP" --version
check "--list shows the pairs"            0 'listen silent'  "$BASH_BIN" "$APP" --list
check "guess via stdin (non-tty)"         0 'IS an anagram'  "$BASH_BIN" -c "printf 'silent\n' | '$BASH_BIN' '$APP' --word listen"
check "--seed is accepted"                0 'IS an anagram'  "$BASH_BIN" "$APP" --word listen silent --seed 7
check "hint offered on failure"           1 'Hint'           "$BASH_BIN" "$APP" --word listen banana

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
