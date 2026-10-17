#!/usr/bin/env bash
# rgx installer — fetches the prebuilt binary for this OS/arch, verifies its
# checksum, and installs it.
#
#   curl -fsSL https://raw.githubusercontent.com/rafay0342/homebrew-tap/main/get.sh | sh
#
# Options (environment):
#   RGX_VERSION=v5.0.0      install a specific tag instead of the latest
#   RGX_INSTALL_DIR=~/bin   where to put the binary
#   RGX_FROM_SOURCE=1       skip downloads, build with cargo
#   RGX_NO_VERIFY=1         skip checksum verification (not recommended)
#   RGX_ALLOW_UNSIGNED=1    permit checksum-only legacy releases (not recommended)
#   RGX_RELEASE_BASE=URL    install from a different host; the layout is
#                           <base>/latest, <base>/<tag>/<asset>, <base>/<tag>/SHA256SUMS
#   RGX_REPO=owner/name     resolve the newest tag from the GitHub API instead
#                           (only used when <base>/latest is unavailable)
#
# Everything lives inside main() and the file ends with `main "$@"`, so a
# truncated download can never execute a half-read script.
set -euo pipefail

# Public release assets are separate from the private source repository.
RELEASE_BASE="${RGX_RELEASE_BASE:-https://github.com/rafay0342/homebrew-tap/releases/download}"
REPO="${RGX_REPO:-}"
RELEASE_REPO="${RGX_RELEASE_REPO:-$REPO}"
if [ -z "$RELEASE_REPO" ] && [ "$RELEASE_BASE" = "https://github.com/rafay0342/homebrew-tap/releases/download" ]; then
  RELEASE_REPO="rafay0342/homebrew-tap"
fi
MARKER_BASE="$RELEASE_BASE"
case "$RELEASE_BASE" in
  https://github.com/*/releases/download) MARKER_BASE="${RELEASE_BASE%/download}/latest/download" ;;
esac
# Scratch dir is global: the EXIT trap fires after main() returns, when a
# function-local would already be gone (and unbound under `set -u`).
tmp=""
trap '[ -n "${tmp:-}" ] && rm -rf "$tmp"' EXIT
API_BASE="${RGX_API_BASE:-https://api.github.com}"

# Release signing key. A checksum proves the download was not corrupted; only a
# signature proves it came from the rgx maintainer. Whoever can write to the
# download host can rewrite the binary and SHA256SUMS together — this is what
# makes that forgery detectable.
RGX_PUBKEY="-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAzO6qCA9f0ca4Kz0GpVYAeGFfVywvAUspn4VHNkynNTs=
-----END PUBLIC KEY-----"
# Rotation for v5.1 and newer. Keep the previous key for existing signed releases.
RGX_PUBKEY_NEXT="-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAUEjGVBH/AK6NjF6Q35hYSnRYZrnB+rH/BqvsRggYroM=
-----END PUBLIC KEY-----"

main() {
  local dest target tag version asset url sudo_cmd

  say() { printf '%s\n' "$*" >&2; }
  die() { printf 'rgx install: %s\n' "$*" >&2; exit 1; }
  have() { command -v "$1" >/dev/null 2>&1; }

  have curl || have wget || die "need curl or wget"
  have tar || die "need tar"

  # ── platform ──────────────────────────────────────────────────────────────
  local os arch termux
  os=$(uname -s)
  arch=$(uname -m)

  # Termux reports Linux/aarch64 like any other arm64 box, but it runs on
  # Bionic inside an app sandbox: it needs its own build and its own bindir.
  termux=0
  if [ -n "${TERMUX_VERSION:-}" ] ||
     [ -d /data/data/com.termux/files/usr ] ||
     [ "$(uname -o 2>/dev/null)" = "Android" ]; then
    termux=1
  fi

  case "$os-$arch" in
    Linux-x86_64|Linux-amd64)
      [ "$termux" = 1 ] && target="android-x64" || target="linux-x64-musl" ;;
    Linux-aarch64|Linux-arm64)
      [ "$termux" = 1 ] && target="android-arm64" || target="linux-arm64-musl" ;;
    Linux-armv7l|Linux-armv8l)
      die "32-bit ARM has no prebuilt binary — set RGX_FROM_SOURCE=1 to build with cargo" ;;
    Darwin-arm64)                target="macos-arm64"      ;;
    Darwin-x86_64)               target="macos-x64"        ;;
    MINGW*|MSYS*|CYGWIN*)
      die "Windows is not installed by this script. Download
    $RELEASE_BASE/\$(curl -fsSL $RELEASE_BASE/latest)/rgx-<version>-windows-x64.zip
  and put rgx.exe somewhere on your PATH." ;;
    *) die "unsupported platform $os-$arch — set RGX_FROM_SOURCE=1 to build with cargo" ;;
  esac

  # ── where it goes ─────────────────────────────────────────────────────────
  # Prefer a directory already writable by this user over silently escalating.
  if [ -n "${RGX_INSTALL_DIR:-}" ]; then
    dest="$RGX_INSTALL_DIR"
  elif [ "$termux" = 1 ] && [ -n "${PREFIX:-}" ]; then
    # There is no /usr/local/bin on Termux, and no root to create one.
    dest="$PREFIX/bin"
  elif [ -w /usr/local/bin ] 2>/dev/null; then
    dest="/usr/local/bin"
  elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    dest="$HOME/.local/bin"
  else
    dest="/usr/local/bin"
  fi
  mkdir -p "$dest" 2>/dev/null || true
  sudo_cmd=""
  if [ ! -w "$dest" ]; then
    have sudo || die "$dest is not writable and sudo is unavailable — set RGX_INSTALL_DIR"
    sudo_cmd="sudo"
    say "note: $dest needs root, will use sudo"
  fi

  tmp=$(mktemp -d)

  fetch() { # url outfile
    if have curl; then
      curl -fsSL --retry 3 --connect-timeout 20 --max-time 300 \
        --max-filesize 268435456 -o "$2" "$1"
    else
      wget -q --timeout=20 --tries=3 -O "$2" "$1"
      [ "$(wc -c < "$2")" -le 268435456 ]
    fi
  }
  fetch_stdout() {
    if have curl; then
      curl -fsSL --retry 3 --connect-timeout 20 --max-time 30 \
        --max-filesize 1048576 "$1"
    else
      wget -q --timeout=20 --tries=3 -O- "$1" | head -c 1048577
    fi
  }

  # ── build from source when asked, or when there is no matching asset ───────
  build_from_source() {
    have cargo || die "cargo not found — install Rust from https://rustup.rs"
    say "building rgx from source (this takes a few minutes)…"
    local src="$tmp/src"
    if [ -n "$REPO" ] && have git; then
      git clone --depth 1 "https://github.com/$REPO.git" "$src" >/dev/null 2>&1 \
        || die "git clone failed"
    else
      # Source tarball from the same host that serves the binaries.
      fetch "$RELEASE_BASE/rgx-src-latest.tar.gz" "$tmp/src.tar.gz" \
        || die "no source tarball at $RELEASE_BASE/rgx-src-latest.tar.gz"
      tar -tzf "$tmp/src.tar.gz" > "$tmp/src.list" \
        || die "could not inspect source archive"
      while IFS= read -r entry; do
        case "$entry" in
          /*|../*|*/../*|*/..) die "source archive contains an unsafe path" ;;
        esac
      done < "$tmp/src.list"
      mkdir -p "$src" && tar -xzf "$tmp/src.tar.gz" -C "$src"
      [ -f "$src/Cargo.toml" ] && [ -d "$src/crates" ] \
        || die "source archive has an unexpected project layout"
    fi
    ( cd "$src" && cargo build --release ) || die "cargo build failed"
    printf '%s' "$src/target/release/rgx"
  }

  local binary=""
  if [ "${RGX_FROM_SOURCE:-0}" = "1" ]; then
    binary=$(build_from_source)
  else
    # ── resolve the tag ─────────────────────────────────────────────────────
    tag="${RGX_VERSION:-}"
    if [ -z "$tag" ] && [ "$termux" = 1 ]; then
      tag=$(fetch_stdout "$MARKER_BASE/latest-termux" 2>/dev/null | tr -d ' \t\r\n"') || true
    fi
    if [ -z "$tag" ]; then
      tag=$(fetch_stdout "$MARKER_BASE/latest" 2>/dev/null | tr -d ' \t\r\n"') || true
    fi
    if [ -z "$tag" ] && [ -n "$RELEASE_REPO" ]; then
      tag=$(fetch_stdout "$API_BASE/repos/$RELEASE_REPO/releases/latest" 2>/dev/null \
            | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1) || true
    fi
    # A 404 body or an autoindex page must never be pasted into a download URL.
    case "$tag" in
      v[0-9]*[!A-Za-z0-9._+-]*)
         say "ignoring unsafe version marker"
         tag="" ;;
      v[0-9]*) ;;
      *) [ -n "$tag" ] && say "ignoring unusable version marker: $(printf %.40s "$tag")"
         tag="" ;;
    esac
    if [ -z "$tag" ]; then
      say "no published release found at $RELEASE_BASE — falling back to a source build"
      binary=$(build_from_source)
    else
      version="${tag#v}"
      asset="rgx-$version-$target.tar.gz"
      url="$RELEASE_BASE/$tag/$asset"
      say "downloading ${asset}…"
      fetch "$url" "$tmp/$asset" || die "no asset $asset in release $tag"

      # ── checksum ──────────────────────────────────────────────────────────
      if [ "${RGX_NO_VERIFY:-0}" = "1" ]; then
        say "warning: skipping checksum verification (RGX_NO_VERIFY=1)"
      else
        fetch "$RELEASE_BASE/$tag/SHA256SUMS" "$tmp/SHA256SUMS" \
          || die "release $tag has no SHA256SUMS — refusing to install unverified"
        local want got
        want=$(awk -v f="$asset" '$2 == f || $2 == "*"f {print $1}' "$tmp/SHA256SUMS" | head -1)
        [ -n "$want" ] || die "$asset is not listed in SHA256SUMS"
        if have sha256sum;   then got=$(sha256sum "$tmp/$asset" | cut -d' ' -f1)
        elif have shasum;    then got=$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)
        elif have openssl;   then got=$(openssl dgst -sha256 "$tmp/$asset" | awk '{print $NF}')
        else die "no sha256 tool available — install coreutils or set RGX_NO_VERIFY=1"; fi
        [ "$want" = "$got" ] || die "checksum mismatch for $asset (expected $want, got $got)"

        # Signature over SHA256SUMS. Current rgx releases are signed, so absence
        # is a hard failure by default: a checksum hosted beside the artifact
        # cannot detect a compromised download server.
        if ! have openssl; then
          [ "${RGX_ALLOW_UNSIGNED:-0}" = "1" ] \
            || die "openssl is required to verify the release signature (or explicitly set RGX_ALLOW_UNSIGNED=1)"
          say "warning: openssl unavailable; accepting checksum-only release"
        elif fetch "$RELEASE_BASE/$tag/SHA256SUMS.sig" "$tmp/SHA256SUMS.sig" 2>/dev/null; then
          printf '%s' "$RGX_PUBKEY" > "$tmp/pub.pem"
          printf '%s' "$RGX_PUBKEY_NEXT" > "$tmp/pub-next.pem"
          if base64 -d < "$tmp/SHA256SUMS.sig" > "$tmp/sig.raw" 2>/dev/null ||
             base64 -D < "$tmp/SHA256SUMS.sig" > "$tmp/sig.raw" 2>/dev/null; then
            if openssl pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin \
                 -in "$tmp/SHA256SUMS" -sigfile "$tmp/sig.raw" >/dev/null 2>&1 ||
               openssl pkeyutl -verify -pubin -inkey "$tmp/pub-next.pem" -rawin \
                 -in "$tmp/SHA256SUMS" -sigfile "$tmp/sig.raw" >/dev/null 2>&1; then
              say "checksum ok · signature verified"
            else
              die "SIGNATURE INVALID for release $tag — refusing to install"
            fi
          else
            die "could not decode SHA256SUMS.sig"
          fi
        else
          [ "${RGX_ALLOW_UNSIGNED:-0}" = "1" ] \
            || die "release $tag has no signature — refusing checksum-only install"
          say "warning: accepting unsigned legacy release (checksum only)"
        fi
      fi

      # Extract exactly the expected regular payload to a fresh file. Never let
      # archive-controlled paths, symlinks, or a convenient-looking fallback
      # filename decide what gets installed.
      local member entries
      member="rgx-$version-$target"
      entries=$(tar -tzf "$tmp/$asset") || die "could not inspect $asset"
      [ "$entries" = "$member" ] || die "$asset has an unexpected archive layout"
      binary="$tmp/rgx.payload"
      tar -xOzf "$tmp/$asset" "$member" > "$binary" \
        || die "could not extract $member"
      [ -s "$binary" ] || die "archive contained an empty rgx binary"
    fi
  fi

  # ── install ───────────────────────────────────────────────────────────────
  chmod +x "$binary" 2>/dev/null || true
  # Validate before touching the working installation. The final `mv` stays on
  # the destination filesystem and is atomic, so Ctrl-C, a full disk, or a bad
  # executable cannot leave a half-written `rgx` behind.
  local staged previous had_previous preflight reported
  staged=$($sudo_cmd mktemp "$dest/.rgx.install.XXXXXX") \
    || die "could not create a staging file in $dest"
  if have install; then
    $sudo_cmd install -m 755 "$binary" "$staged" \
      || { $sudo_cmd rm -f "$staged"; die "could not stage rgx in $dest"; }
  else
    $sudo_cmd cp "$binary" "$staged" && $sudo_cmd chmod 755 "$staged" \
      || { $sudo_cmd rm -f "$staged"; die "could not stage rgx in $dest"; }
  fi
  # macOS quarantines downloaded binaries; strip it or Gatekeeper blocks the run.
  [ "$os" = "Darwin" ] && $sudo_cmd xattr -d com.apple.quarantine "$staged" 2>/dev/null || true

  preflight=$("$staged" --version 2>/dev/null) \
    || { $sudo_cmd rm -f "$staged"; die "downloaded binary will not run on $os-$arch"; }
  case "$preflight" in
    *"rgx "*) ;;
    *) $sudo_cmd rm -f "$staged"; die "downloaded binary returned an invalid version response" ;;
  esac
  if [ -n "${version:-}" ] && [ "$preflight" != "rgx $version" ]; then
    $sudo_cmd rm -f "$staged"
    die "release version mismatch (wanted rgx $version, got $(printf %.40s "$preflight"))"
  fi

  previous="$tmp/rgx.previous"
  had_previous=0
  if [ -f "$dest/rgx" ]; then
    $sudo_cmd cp "$dest/rgx" "$previous" \
      || { $sudo_cmd rm -f "$staged"; die "could not back up the existing rgx"; }
    had_previous=1
  fi
  $sudo_cmd mv -f "$staged" "$dest/rgx" \
    || { $sudo_cmd rm -f "$staged"; die "atomic install into $dest failed"; }

  # ── verify it actually runs ───────────────────────────────────────────────
  if ! reported=$("$dest/rgx" --version 2>/dev/null); then
    if [ "$had_previous" = 1 ]; then
      local restore
      restore=$($sudo_cmd mktemp "$dest/.rgx.restore.XXXXXX") || true
      if [ -n "${restore:-}" ] && $sudo_cmd install -m 755 "$previous" "$restore"; then
        $sudo_cmd mv -f "$restore" "$dest/rgx" || true
      fi
    else
      $sudo_cmd rm -f "$dest/rgx" || true
    fi
    die "installed binary failed validation; previous rgx was restored when available"
  fi
  say "installed $reported → $dest/rgx"

  case ":$PATH:" in
    *":$dest:"*) ;;
    *) say ""
       say "$dest is not on your PATH. Add this to your shell profile:"
       say "    export PATH=\"$dest:\$PATH\"" ;;
  esac
  say ""
  if "$dest/rgx" login --help >/dev/null 2>&1; then
    say "next: rgx login  (opens your browser), then run: rgx"
    say "SSH/headless: rgx login --device-code"
    say "API keys and devices: https://rafaygen.com/rgx/"
  else
    say "next: add a provider key to ~/.rgx/.env (GROQ_API_KEY, MISTRAL_API_KEY, …), then run: rgx"
  fi
  say "check your provider with: rgx  then  /doctor"
}

main "$@"
