#!/usr/bin/env python3
"""Run uploader/Expect and remote publication commands with local SSH/SCP substitutes."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / 'Scripts'


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ddlnew-upload-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / 'remote'
        self.remote.mkdir()
        self.artifacts = self.root / 'artifacts with spaces'
        self.artifacts.mkdir()
        (self.artifacts / 'ddlNew.ipa').write_bytes(b'new IPA fixture')
        (self.artifacts / 'manifest.plist').write_bytes(plistlib.dumps({'items': []}))
        (self.artifacts / 'do-not-upload.log').write_text('private log fixture')
        (self.remote / 'ddlNew.ipa').write_bytes(b'old IPA')
        (self.remote / 'manifest.plist').write_bytes(b'old manifest')
        (self.root / 'adhoc-upload-config.sh').write_text("DDLNEW_SSH_PASSWORD='fixture-only'\n")
        shutil.copy2(SCRIPTS / 'ssh-password.exp', self.root)
        self.make_tool('ssh', '''
import subprocess, sys
if '-O' in sys.argv: sys.exit(0)
sys.exit(subprocess.call(sys.argv[-1], shell=True, executable='/bin/bash'))
''')
        self.make_tool('scp', '''
import os, pathlib, shutil, sys
if os.environ.get('FAIL_TRANSFER'): sys.exit(23)
target = pathlib.Path(sys.argv[-1].split(':', 1)[1])
for source in sys.argv[-3:-1]: shutil.copy2(source, target)
if os.environ.get('CORRUPT'): (target / 'ddlNew.ipa').write_bytes(b'corrupt')
''')
        self.make_tool('sha256sum', '''
import hashlib, pathlib, sys
for line in sys.stdin:
    expected, name = line.strip().split('  ', 1)
    if hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest() != expected:
        print('checksum mismatch', file=sys.stderr)
        sys.exit(1)
''')
        source = (SCRIPTS / 'upload-adhoc.sh').read_text()
        source = source.replace('/data/static-site/ddlnew', str(self.remote))
        source = source.replace('/usr/bin/ssh', str(self.root / 'ssh'))
        source = source.replace('/usr/bin/scp', str(self.root / 'scp'))
        self.script = self.root / 'upload-adhoc.sh'
        self.script.write_text(source)
        self.env = dict(os.environ, PATH=f'{self.root}:{os.environ["PATH"]}')

    def make_tool(self, name, body):
        tool = self.root / name
        tool.write_text(f'#!{sys.executable}\n{body}')
        tool.chmod(0o755)

    def run_upload(self):
        return subprocess.run(['/bin/bash', str(self.script), str(self.artifacts)],
                              env=self.env, capture_output=True, text=True, timeout=20)

    def test_upload_checksums_and_cleanup(self):
        result = self.run_upload()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in ['ddlNew.ipa', 'manifest.plist']:
            self.assertEqual((self.remote / name).read_bytes(), (self.artifacts / name).read_bytes())
        self.assertFalse(list(self.remote.glob('.upload-*')))
        self.assertFalse((self.remote / '.publish-lock').exists())
        self.assertFalse(list(self.remote.rglob('do-not-upload.log')))
        self.assertNotIn('fixture-only', result.stdout + result.stderr)
        self.assertNotIn('上一版本备份', result.stdout)

    def test_first_upload_removes_empty_staging(self):
        (self.remote / 'ddlNew.ipa').unlink()
        (self.remote / 'manifest.plist').unlink()
        self.test_upload_checksums_and_cleanup()

    def test_manifest_replacement_failure_keeps_rollback(self):
        self.make_tool('mv', '''
import subprocess, sys
if sys.argv[-2] == 'manifest.plist': sys.exit(1)
sys.exit(subprocess.call(['/bin/mv'] + sys.argv[1:]))
''')
        result = self.run_upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.remote / 'ddlNew.ipa').read_bytes(), b'old IPA')
        self.assertEqual((self.remote / 'manifest.plist').read_bytes(), b'old manifest')
        self.assertTrue(list(self.remote.glob('.upload-*/previous-ddlNew.ipa')))
        self.assertFalse((self.remote / '.publish-lock').exists())
        self.assertNotIn('上传完成', result.stdout)

    def test_corrupt_transfer_preserves_release(self):
        self.env['CORRUPT'] = '1'
        result = self.run_upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.remote / 'ddlNew.ipa').read_bytes(), b'old IPA')
        self.assertEqual((self.remote / 'manifest.plist').read_bytes(), b'old manifest')
        self.assertNotIn('上传完成', result.stdout)

    def test_transfer_failure_preserves_release(self):
        self.env['FAIL_TRANSFER'] = '1'
        result = self.run_upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.remote / 'ddlNew.ipa').read_bytes(), b'old IPA')
        self.assertEqual((self.remote / 'manifest.plist').read_bytes(), b'old manifest')
        self.assertNotIn('上传完成', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
