# curl_app

One-line installer demo: a `curl | bash` install script that drops an anagram
challenge CLI onto your machine.

```bash
curl -fsSL https://azlanabas.github.io/curl_app/install.sh | bash
```

Then, in a new terminal:

```bash
curl-app
```

```
curl-app — Anagram Challenge v0.1.0
Letters only — case and punctuation are ignored. Type q to quit.

Your word:  LISTEN

Your anagram: silent

✓ Correct — "silent" IS an anagram of "listen"  (6 letters)
```

## What it does

The app shows one word. You type a word. It tells you whether yours is an anagram
of the one shown — letters only, so case and punctuation are ignored and
`"Night!"` matches `"thing"`. Any rearrangement counts, not just the curated one;
the curated partner is offered as a hint when you get it wrong.

Once installed it works offline and has **zero dependencies** — no Python, no
Node, no build step.

## Usage

```
curl-app                        show one word, then type an anagram of it
curl-app --word listen silent   check a pair non-interactively and exit
curl-app --word listen          check one word read from stdin
curl-app --list                 print the built-in word pairs
curl-app --seed 7               reproducible word choice
curl-app --version
curl-app --help
```

Exit codes make it scriptable:

| code | meaning |
|---|---|
| 0 | the words are anagrams |
| 1 | the words are not anagrams |
| 2 | usage error or empty input |

```bash
curl-app --word listen silent && echo "anagram"
```

## Install options

```bash
# pin a version
curl -fsSL https://azlanabas.github.io/curl_app/install.sh | CURL_APP_VERSION=0.1.0 bash

# choose the install directory
curl -fsSL https://azlanabas.github.io/curl_app/install.sh | bash -s -- --dir /opt/curl-app

# track the main branch instead of a tagged release
curl -fsSL https://azlanabas.github.io/curl_app/install.sh | CURL_APP_CHANNEL=edge bash

# do not touch my shell rc file
curl -fsSL https://azlanabas.github.io/curl_app/install.sh | CURL_APP_NO_MODIFY_PATH=1 bash
```

| variable | meaning |
|---|---|
| `CURL_APP_VERSION` | install a specific version (default: latest) |
| `CURL_APP_INSTALL_DIR` | install directory (default `$HOME/.curl-app`) |
| `CURL_APP_CHANNEL` | `stable` (default) or `edge` |
| `CURL_APP_NO_MODIFY_PATH` | non-empty: leave your shell rc file alone |
| `CURL_APP_SOURCE_DIR` | development only: install from a local checkout |

Flags: `--help`, `--version V`, `--channel stable|edge`, `--dir PATH`, `--uninstall`.

## Uninstall

```bash
curl -fsSL https://azlanabas.github.io/curl_app/uninstall.sh | bash
```

This removes `~/.curl-app` and the PATH block this project added to your shell rc
file. Nothing else in the rc file is touched, and a backup is left at
`<rc>.curl_app.bak`.

## How it works

```
                                  install.sh  ── downloads ─▶  bin/curl-app
curl ─▶ azlanabas.github.io/curl_app/install.sh                    │
                                       │                           │
                                  SHA256SUMS ── verifies ──────────┘
                                       │
                          ~/.curl-app/bin/curl-app  +  PATH entry in ~/.zshrc
```

The install script is served by GitHub Pages, so the URL is short and stable.
The payload itself is fetched from an **immutable git tag** on
`raw.githubusercontent.com`, and its SHA-256 is checked against the `SHA256SUMS`
published alongside it. If the bytes don't match, nothing is installed.

Design notes:

- **Pure `bash`, 3.2-compatible.** macOS ships bash 3.2 at `/bin/bash`, so the
  scripts avoid associative arrays, `${var,,}`, `mapfile` and friends. CI runs the
  suite on `macos-latest` under `/bin/bash` to prove it.
- **The installer never reads stdin.** When you run `curl … | bash`, stdin *is*
  the script. Anything that prompted for input would hang. All configuration is by
  environment variable or flag.
- **The payload is a single file**, fetched directly rather than as a tarball.
  GitHub does not guarantee byte-stability for auto-generated archive files, so
  checksums over those can rot; a raw file pinned to a tag does not.
- **PATH editing is idempotent.** The rc block is marked with `# curl_app` and only
  added once, and `CURL_APP_NO_MODIFY_PATH` opts out entirely.

### A note on `curl | bash`

Piping a remote script straight into your shell executes whatever the server
sends, with your privileges. That is the tradeoff this whole install style makes.
If you'd rather look first:

```bash
curl -fsSL https://azlanabas.github.io/curl_app/install.sh -o install.sh
less install.sh
bash install.sh
```

Because the payload is checksum-verified, you can at least confirm that what you
run is exactly what was published.

## Development

```bash
bash tests/test_anagram.sh    # app behaviour
bash tests/test_install.sh    # installer, idempotency, checksum, uninstall
tools/make-release.sh 0.2.0   # regenerate SHA256SUMS, verify, commit, tag, push
```

`CURL_APP_SOURCE_DIR=$(pwd) bash install.sh` installs from the working tree
without touching the network, which is how the tests exercise `install.sh`.

## Licence

MIT — see [LICENSE](LICENSE).
