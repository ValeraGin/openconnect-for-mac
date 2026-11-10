#!/usr/bin/env python3
"""Reject stale or focus-taking public captures without launching macOS UI."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('screenshots', Path(__file__).with_name('screenshots.py'))
shots = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shots)


class ExportProof(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'app'
        (self.app / 'Contents/MacOS').mkdir(parents=True)
        (self.app / 'Contents/MacOS/ocmac-app').write_bytes(b'build A')
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleShortVersionString='0.27.0')))
        self.out = self.root / 'captures'
        self.out.mkdir()
        for lang in ['en', 'ru']:
            png = self.out / f'{lang}-connection.png'
            png.write_bytes(b'synthetic fixture')
            png.with_suffix('.json').write_text(json.dumps(dict(
                binarySHA256=shots.digest(self.app / 'Contents/MacOS/ocmac-app'),
                plistSHA256=shots.digest(self.app / 'Contents/Info.plist'), appVersion='0.27.0',
                syntheticData=True, capture='screencapture-passive-window', appearanceMode='inactive',
                focusPreserved=True, builtInDisplay=True, appearance='NSAppearanceNameAqua',
                active=False, keyWindow=False, mainWindow=False, screen='settings', page='connection')))

    def run_mode(self, mode):
        with patch.object(shots, 'ROOT', self.root), patch.object(shots, 'APP', self.app), \
                patch.object(shots, 'EXPORTS', {'profile.png': 'connection'}), \
                patch.object(sys, 'argv', ['screenshots.py', mode, '--output', str(self.out)]), \
                patch.object(shots.subprocess, 'check_output', return_value='ocmac 0.27.0\n'), \
                patch.object(shots.subprocess, 'run', side_effect=AssertionError('Must not launch UI')), \
                contextlib.redirect_stdout(io.StringIO()):
            shots.main()

    def test_all_proofs_checked_before_replacing_any_public_image(self):
        public = self.root / 'assets/profile.png'
        public.parent.mkdir()
        public.write_bytes(b'previous release')
        path = self.out / 'ru-connection.json'
        report = json.loads(path.read_text())
        report['active'] = True
        path.write_text(json.dumps(report))
        with self.assertRaises(SystemExit):
            self.run_mode('--export-only')
        self.assertEqual(public.read_bytes(), b'previous release')
        self.assertFalse((self.root / 'assets/captures.json').exists())

    def test_missing_focus_proof_is_rejected(self):
        path = self.out / 'en-connection.json'
        report = json.loads(path.read_text())
        del report['focusPreserved']
        path.write_text(json.dumps(report))
        with self.assertRaises(SystemExit):
            self.run_mode('--export-only')

    def test_changed_bundle_with_same_version_is_rejected(self):
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleShortVersionString='0.27.0', CFBundleVersion='new')))
        with self.assertRaises(SystemExit):
            self.run_mode('--export-only')

    def test_export_and_verify_detect_changed_public_image(self):
        self.run_mode('--export-only')
        self.run_mode('--verify-only')
        (self.root / 'assets/ru/profile.png').write_bytes(b'changed')
        with self.assertRaises(SystemExit):
            self.run_mode('--verify-only')


if __name__ == '__main__':
    unittest.main()
