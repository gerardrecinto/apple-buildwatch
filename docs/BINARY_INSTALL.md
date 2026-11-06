# Install a release binary with checksum verification

The source instructions in the [README](../README.md#build-from-source) are
available now. Release archives through **v1.2.1** have no checksum
file. Use the source instructions while that is the latest release.

After a newer release publishes both `buildwatch-macos.zip` and `SHA256SUMS`,
use `scripts/install-release.sh` from a checkout of this repository. Pass the
exact tag shown on that release. The script requires a version; it never
silently selects a different release or installs an archive without a checksum.

It downloads with `curl -fL`, checks the archive with SHA-256, extracts only the
`buildwatch` entry, and installs to `$HOME/.local/bin`. It does not use `sudo`
or write `/usr/local/bin`. Set `BUILDWATCH_INSTALL_DIR` to choose another
folder. The printed full path works even when that folder is not on `PATH`.

The release binary is for macOS. A checksum does not establish CPU compatibility
or notarization. Build from source to use your own toolchain and architecture.

The checksum file comes from the same release as the archive. It detects a
corrupted archive or an archive that does not match that file. It does not
establish publisher identity or protect against a compromised release. This
workflow does not publish a signature or signed provenance.

## Check before installing

Open the [release page](https://github.com/gerardrecinto/apple-buildwatch/releases)
and confirm that its assets contain both files. A missing file, HTTP error,
malformed checksum, archive mismatch, or missing executable makes the installer
stop before touching the install folder. It reports what failed and suggests
building from source.

Running `scripts/install-release.sh v1.2.1` is expected to fail with that
explanation. It is not an installation command for the current release.

## Test release packaging locally

The automated check uses a temporary HTTP server, generated archives, and a
temporary install folder. It neither downloads a public release nor changes
any installed binary.

```bash
python3 -m unittest discover -s scripts -p 'test_release_install.py' -v
```
