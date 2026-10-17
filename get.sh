#!/bin/sh
# POSIX entrypoint: curl -fsSL <public tap>/main/get.sh | sh
# The complete installer verifies the release signature and payload checksum.
set -eu

main() {
  command -v bash >/dev/null 2>&1 || {
    echo 'rgx: bash is required for installation (Termux: pkg install bash).' >&2
    exit 1
  }
  installer_url=${RGX_INSTALLER_URL:-https://raw.githubusercontent.com/rafay0342/homebrew-tap/main/install.sh}
  case "$installer_url" in
    https://*) ;;
    *) echo 'rgx: installer URL must use HTTPS.' >&2; exit 1 ;;
  esac
  install_tmp=$(mktemp -d)
  trap 'rm -rf "$install_tmp"' EXIT HUP INT TERM
  if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --proto-redir '=https' -fsSL --connect-timeout 20 --max-time 120 \
      --max-filesize 1048576 "$installer_url" -o "$install_tmp/install.sh"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only --timeout=20 -O "$install_tmp/install.sh" "$installer_url"
  else
    echo 'rgx: curl or wget is required.' >&2
    exit 1
  fi
  bash "$install_tmp/install.sh"
}

main "$@"
