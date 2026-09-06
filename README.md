# Rune releases

This repository distributes verified Rune release artifacts built by a private,
gated build authority. It does not contain the Rune source code.

Rune remains proprietary. Read the [Rune Personal Use License Agreement](LICENSE)
before installation. Downloading, installing, copying, or using Rune means that
you accept that agreement.
Rune v0.1.5 ships under the personal, non-commercial grant in the current terms.
Rune v0.1.4 and earlier assets retain their prior stricter license terms.

## Install

Download the installer and inspect it before executing it:

```sh
curl --fail --location --proto '=https' \
  --output install.sh \
  https://raw.githubusercontent.com/pearl-computing/rune-releases/main/install.sh
less ./install.sh
sh ./install.sh --version 0.1.5
```

Inspect the script, choose an explicit release where reproducibility matters, and
keep the matching manifest and checksum with deployment records. Omitting
`--version` selects the latest stable GitHub release. Use `--bin-dir DIR` to install
outside `$HOME/.local/bin`.

The installer supports Linux and macOS on x86_64 and ARM64. It downloads only over
HTTPS from the Rune releases repository, verifies the archive SHA-256 before
extraction, verifies `rune --version`, and atomically replaces the destination
executable. A failed install preserves the previous executable.

## Verify manually

Each release contains `rune-manifest.json`, one archive and checksum per supported
target, and matching SBOM, dependency-notice, metadata, release-metadata, and
provenance assets. Compare the archive digest with both its `.sha256` file and the
version manifest before extracting it.
