"""Exercise the real package/install scripts over temporary HTTP assets."""
from functools import partial
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


class ReleaseInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.assets = self.root / 'assets'
        self.assets.mkdir()
        self.destination = self.root / 'user bin'
        self.destination.mkdir()
        self.existing = self.destination / 'buildwatch'
        self.existing.write_bytes(b'existing binary must survive a failed install')
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(self.assets)))
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.environment = dict(os.environ, BUILDWATCH_INSTALL_DIR=str(self.destination), BUILDWATCH_RELEASE_BASE_URL=f'http://127.0.0.1:{self.server.server_port}')

    def package(self, version='v9.9.9'):
        source = self.root / 'input binary'
        source.write_bytes(b'#!/bin/sh\nprintf "buildwatch test fixture\\n"\n')
        output = self.assets / version
        result = subprocess.run(['bash', str(ROOT / 'scripts/package-release.sh'), str(source), str(output)], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return source, output

    def install(self, version='v9.9.9'):
        return subprocess.run(['bash', str(ROOT / 'scripts/install-release.sh'), version], env=self.environment, text=True, capture_output=True)

    def assertRejected(self, result, message):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertEqual(self.existing.read_bytes(), b'existing binary must survive a failed install')
        self.assertEqual([p.name for p in self.destination.iterdir()], ['buildwatch'])

    def test_package_contains_only_executable_and_correct_checksum(self):
        source, output = self.package()
        with zipfile.ZipFile(output / 'buildwatch-macos.zip') as archive:
            self.assertEqual(archive.namelist(), ['buildwatch'])
            self.assertEqual(archive.read('buildwatch'), source.read_bytes())
        expected = hashlib.sha256((output / 'buildwatch-macos.zip').read_bytes()).hexdigest()
        self.assertEqual((output / 'SHA256SUMS').read_text().split(), [expected, 'buildwatch-macos.zip'])

    def test_readme_install_commands_use_verified_asset_and_user_directory(self):
        source, _ = self.package()
        blocks = re.findall(r'```bash\n(.*?)```', (ROOT / 'README.md').read_text(), re.S)
        install_block = next(block for block in blocks if 'scripts/install-release.sh' in block)
        shells = ['bash', 'sh']
        if shutil.which('zsh'):
            shells.append('zsh')
        for shell in shells:
            with self.subTest(shell=shell):
                result = subprocess.run([shell, '-ec', install_block], input='v9.9.9\n', cwd=ROOT, env=self.environment, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.existing.read_bytes(), source.read_bytes())
                self.assertTrue(os.access(self.existing, os.X_OK))
                self.assertIn('after checksum verification', result.stdout)

    def test_uppercase_checksum_is_accepted(self):
        source, output = self.package()
        checksum = (output / 'SHA256SUMS').read_text().split()[0].upper()
        (output / 'SHA256SUMS').write_text(f'{checksum}  buildwatch-macos.zip\n')
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.existing.read_bytes(), source.read_bytes())

    def test_missing_checksum_has_clear_version_boundary_and_preserves_install(self):
        self.assertRejected(self.install('v1.2.1'), 'v1.2.1 and earlier do not')

    def test_tampered_archive_is_not_installed(self):
        _, output = self.package()
        with (output / 'buildwatch-macos.zip').open('ab') as archive:
            archive.write(b'tampered after packaging')
        self.assertRejected(self.install(), 'checksum did not match')

    def test_malformed_or_duplicate_checksum_is_not_installed(self):
        _, output = self.package()
        valid = (output / 'SHA256SUMS').read_text()
        for value in ['not a checksum\n', valid + valid]:
            (output / 'SHA256SUMS').write_text(value)
            self.assertRejected(self.install(), 'exactly one SHA-256 value')

    def test_missing_archive_is_an_http_error_and_preserves_install(self):
        _, output = self.package()
        (output / 'buildwatch-macos.zip').unlink()
        self.assertRejected(self.install(), 'Could not download the binary archive')

    def test_archive_without_expected_executable_is_rejected(self):
        _, output = self.package()
        archive = output / 'buildwatch-macos.zip'
        with zipfile.ZipFile(archive, 'w') as zipped:
            zipped.writestr('../outside', 'not an executable')
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (output / 'SHA256SUMS').write_text(f'{digest}  buildwatch-macos.zip\n')
        self.assertRejected(self.install(), 'did not contain buildwatch')
        self.assertFalse((self.root / 'outside').exists())

    def test_invalid_version_is_rejected_before_downloading(self):
        self.assertRejected(self.install('../../main'), 'Pass an explicit release tag')


if __name__ == '__main__':
    unittest.main()
