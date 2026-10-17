# RafayGen Homebrew tap

RGX is a native terminal coding agent for macOS and Linux (ARM64 and x64).

## Homebrew

```sh
brew install rafay0342/tap/rgx
rgx --version
```

Upgrade with `brew upgrade rafay0342/tap/rgx`. The formula installs a native
binary with a pinned SHA-256; Node.js and Rust are not required.

## Global native install

```sh
curl -fsSL https://raw.githubusercontent.com/rafay0342/homebrew-tap/main/get.sh | sh
```

The installer detects macOS, Linux or Termux, verifies the Ed25519 release
signature and SHA-256 checksum, then atomically installs the native binary.
Set `RGX_INSTALL_DIR` to choose a directory. Default destinations are a writable
`/usr/local/bin`, `~/.local/bin`, or Termux's `$PREFIX/bin`. If the destination
is not on PATH, the installer prints the exact shell-profile line to add.
On Termux, install prerequisites with `pkg install curl bash openssl-tool coreutils tar`.

## npm

The package name is `@rafaygen/rgx`. Install the release tarball directly:

```sh
npm install -g https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-npm-5.1.2.tgz
rgx --version
```

The short command `npm install -g @rafaygen/rgx` becomes available after npm
registry publication. The tarball command works independently of registry
publication. Node 18+ launches the native binary; optional packages select
macOS/Linux and ARM64/x64. No install hooks or compilation are used. Keep npm
optional dependencies enabled. Use npm for updates rather than `rgx upgrade`.

## Configure model access

Installing the CLI does not configure a model provider. Set your provider keys
privately, or point `RGX_ENV_FILE` at an existing provider-key file. Run
`rgx router` to see the selected provider order without making API requests.
`rgx login` requires a reachable RGX account gateway. Existing gateway hosting
is separate from these public downloads.

## Release assets

[Download signed native archives and npm packages](https://github.com/rafay0342/homebrew-tap/releases/latest).
The CLI source repository remains private; this tap contains only distribution
files and public release assets. Existing formulas in this tap are independent
of RGX.
