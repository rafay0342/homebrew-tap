# RGX

Native coding agent for macOS and Linux, on Apple Silicon/ARM64 and Intel/x64.

```sh
npm install -g @rafay519/rgx
rgx
```

First launch opens browser sign-in, then continues directly into your agent
session. Sign in with an active [RafayGen account](https://rafaygen.com/rgx/).
Later launches reuse the saved login. SSH sessions display a device code.
Existing provider configurations also work without hosted sign-in.

## Native Homebrew install

```sh
brew install rafay0342/tap/rgx
rgx
```

Homebrew installs the native executable with a pinned SHA-256; Node and Rust
are not required. Upgrade with `brew upgrade rafay0342/tap/rgx`.

npm requires Node 18+ only for its launcher. It selects the matching native
binary automatically, without installation hooks or compilation. Keep optional
dependencies enabled. Update with `npm install -g @rafay519/rgx@latest`.

## Other installation options

The [signed release assets](https://github.com/rafay0342/homebrew-tap/releases/latest)
include native binaries and npm tarballs. The shell installer is:

```sh
curl -fsSL https://raw.githubusercontent.com/rafay0342/homebrew-tap/main/get.sh | sh
```

It verifies the release signature and checksum using the system OpenSSL or
LibreSSL, including macOS built-in tools. The agent runs as a direct native
binary without Node, Python, Rust or Homebrew. Set `RGX_INSTALL_DIR` to choose the installation directory.
If it is outside PATH, add that directory to your shell profile.

## Account and provider access

Hosted inference requires an active RafayGen account and an available model
server. You can revoke devices at [RGX account management](https://rafaygen.com/rgx/).
Use `rgx logout` to disconnect this device. In scripts and CI, authenticate
interactively first; noninteractive runs never open a browser.

For your own provider, configure keys privately or set `RGX_ENV_FILE` to your
provider file. `rgx router` shows configured routing without sending a request.

The CLI source remains private. This repository contains public distribution
files and release assets; other formulas in the tap are independent of RGX.
