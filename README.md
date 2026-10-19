# RGX — native terminal coding agent

Install the native macOS/Linux CLI globally:

```sh
curl -fsSL https://rafaygen.com/dl/rgx/install.sh | sh
rgx
```

The shell installer selects ARM64 or x64, verifies the checksum and maintainer
signature, and installs a direct native executable. No Node, Python, Rust or
Homebrew is required. macOS system LibreSSL is supported.

First launch opens browser sign-in and continues into your agent session.
Use an active [RafayGen account](https://rafaygen.com/rgx/). Later launches reuse
the saved login. SSH uses a device code. Existing provider configurations work
without hosted sign-in. Noninteractive runs never open a browser.

## npm alternative

```sh
npm install -g @rafay519/rgx
rgx
```

npm requires Node 18+ for its launcher and selects the same native executable.
Keep optional dependencies enabled. Update with `npm install -g @rafay519/rgx@latest`.

## Homebrew alternative

```sh
brew install rafay0342/tap/rgx
```

Homebrew installs a native binary with a pinned SHA-256.

[Download signed native releases](https://github.com/rafay0342/homebrew-tap/releases/latest).
Hosted model access depends on the RGX model server being online. Manage/revoke
devices at the RGX account page, or disconnect with `rgx logout`.

Set `RGX_INSTALL_DIR` to customize the shell installation directory. If it is
outside PATH, add that directory to your shell profile. Shell installations
update with `rgx upgrade`; npm and Homebrew installations use their package manager.

The CLI source remains private. This repository contains public distribution
files and release assets. Other formulas in the tap are independent of RGX.
