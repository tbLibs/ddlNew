#!/usr/bin/env python3
"""Exercise the real packaging script with an offline asc stand-in, not real signing."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[2] / 'Scripts/package-adhoc.sh'


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ddlNew packaging ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'Scripts').mkdir()
        self.script = self.root / 'Scripts/package-adhoc.sh'
        shutil.copy2(SCRIPT, self.script)
        uploader = self.root / 'Scripts/upload-adhoc.sh'
        uploader.write_text('#!/bin/bash\nprintf "%s" "$1" > "$UPLOAD_CALL"\n')
        uploader.chmod(0o755)
        (self.root / 'ddlNew.xcworkspace').mkdir()
        (self.root / 'Pods').mkdir()
        for path in ['Podfile.lock', 'Pods/Manifest.lock']:
            (self.root / path).write_text('fixture lock\n')
        self.archive = self.root / 'existing archive.xcarchive'
        self.archive.mkdir()
        (self.archive / 'Info.plist').write_bytes(plistlib.dumps({}))
        self.fixture = self.root / 'fixture.ipa'
        with zipfile.ZipFile(self.fixture, 'w') as ipa:
            ipa.writestr('Payload/ddlNew.app/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'com.example.fixture',
                'CFBundleShortVersionString': '9.8.7',
                'CFBundleVersion': '321',
                'CFBundleDisplayName': '叮咚 & 测试',
            }, fmt=plistlib.FMT_BINARY))
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        asc = bin_dir / 'asc'
        asc.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, plistlib, shutil, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps(args) + '\\n')
def flag(name):
    return pathlib.Path(args[args.index(name) + 1])
if args[:2] == ['xcode', 'archive']:
    path = flag('--archive-path')
    path.mkdir()
    (path / 'Info.plist').write_bytes(plistlib.dumps({}))
elif args[:2] == ['xcode', 'export']:
    if os.environ.get('EXPORT_FAIL'):
        print('simulated signing failure', file=sys.stderr)
        sys.exit(42)
    shutil.copyfile(os.environ['FIXTURE'], flag('--ipa-path'))
else:
    sys.exit(99)
''')
        asc.chmod(0o755)
        self.calls = self.root / 'calls.jsonl'
        self.output = self.root / 'output with spaces'
        self.env = dict(os.environ, PATH=f'{bin_dir}:{os.environ["PATH"]}',
                        CALLS=str(self.calls), FIXTURE=str(self.fixture),
                        UPLOAD_CALL=str(self.root / 'upload-call'))

    def run_script(self, *args):
        return subprocess.run(['/bin/bash', str(self.script), '--output', str(self.output),
                               *args], env=self.env, text=True, capture_output=True)

    def test_archive_export_and_manifest(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([c[1] for c in calls], ['archive', 'export'])
        self.assertIn('--xcodebuild-flag=generic/platform=iOS', calls[0])
        self.assertIn(f'--xcodebuild-flag={self.output}/DerivedData', calls[0])
        options = plistlib.loads((self.output / 'ExportOptions.plist').read_bytes())
        self.assertEqual(options['method'], 'release-testing')
        self.assertEqual(options['destination'], 'export')
        self.assertFalse(options['manageAppVersionAndBuildNumber'])
        item = plistlib.loads((self.output / 'manifest.plist').read_bytes())['items'][0]
        self.assertEqual(item['assets'][0]['url'],
                         'https://static.xingqitongim.com/ddlnew/ddlNew.ipa')
        self.assertEqual(item['metadata']['bundle-version'], '9.8.7')
        self.assertEqual(item['metadata']['build-version'], '321')
        self.assertEqual(item['metadata']['title'], '叮咚 & 测试')
        self.assertEqual(item['metadata']['bundle-identifier'], 'com.example.fixture')
        self.assertEqual((self.root / 'upload-call').read_text(), str(self.output))

    def test_version_and_build_are_archive_overrides(self):
        result = self.run_script('--version', '2.3.4', '--build-number', '567', '--no-upload')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertIn('--xcodebuild-flag=MARKETING_VERSION=2.3.4', calls[0])
        self.assertIn('--xcodebuild-flag=CURRENT_PROJECT_VERSION=567', calls[0])
        self.assertFalse(any('MARKETING_VERSION=' in value for value in calls[1]))
        self.assertFalse((self.root / 'upload-call').exists())

    def test_invalid_version_arguments_stop_early(self):
        for args in [('--version', '1.bad'), ('--version', '1.2.3.4'),
                     ('--build-number', '0'), ('--build', '-2'),
                     ('--archive', str(self.archive), '--version', '2.0')]:
            with self.subTest(args=args):
                result = self.run_script(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.calls.exists())
                self.assertFalse(self.output.exists())

    def test_reuse_archive_and_provisioning_flag(self):
        result = self.run_script('--archive', str(self.archive), '--allow-provisioning-updates')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][1], 'export')
        self.assertIn('--xcodebuild-flag=-allowProvisioningUpdates', calls[0])

    def test_export_failure_keeps_log_and_stops(self):
        self.env['EXPORT_FAIL'] = '1'
        result = self.run_script('--archive', str(self.archive))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.output / 'manifest.plist').exists())
        self.assertIn('simulated signing failure', (self.output / 'export.log').read_text())
        self.assertNotIn('打包完成', result.stdout)
        self.assertFalse((self.root / 'upload-call').exists())

    def test_existing_output_is_preserved(self):
        self.output.mkdir()
        sentinel = self.output / 'keep.txt'
        sentinel.write_text('keep')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), 'keep')
        self.assertFalse(self.calls.exists())

    def test_missing_version_rejects_manifest(self):
        with zipfile.ZipFile(self.fixture, 'w') as ipa:
            ipa.writestr('Payload/ddlNew.app/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'com.example.fixture',
            }))
        result = self.run_script('--archive', str(self.archive))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('CFBundleShortVersionString', result.stderr)
        self.assertFalse((self.output / 'manifest.plist').exists())
        self.assertNotIn('打包完成', result.stdout)

    def test_outdated_pods_stop_before_archive(self):
        (self.root / 'Pods/Manifest.lock').write_text('different')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.calls.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
