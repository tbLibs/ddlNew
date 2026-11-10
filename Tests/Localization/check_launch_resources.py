#!/usr/bin/env python3
"""Keep the system launch screen fixed in Simplified Chinese, independent of app language."""
from pathlib import Path
import plistlib
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2] / 'ddlNew/Resources'
path = root / 'AppLaunchScreen.storyboard'
assert path.exists(), 'Missing nonlocalized launch storyboard'
assert not list(root.glob('*.lproj/AppLaunchScreen.*')), 'Localized launch resources remain'
tree = ET.parse(path)
labels = {item.attrib['id']: item.attrib['text'] for item in tree.iter('label')}
assert labels == {'launch-title': '叮咚聊', 'launch-subtitle': '一起发现，一起参与'}
assert tree.getroot().attrib['launchScreen'] == 'YES'
for item in tree.iter():
    assert 'customClass' not in item.attrib, 'Launch cannot depend on application code'
print('Single Simplified Chinese launch resource PASS')

if len(sys.argv) > 1:
    app = Path(sys.argv[1])
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['UILaunchStoryboardName'] == 'AppLaunchScreen'
    assert not list(app.glob('*.lproj/*LaunchScreen.*')), 'Localized launch resources remain in the product'
    nibs = list((app / 'AppLaunchScreen.storyboardc').glob('*.nib'))
    assert nibs, 'Missing compiled launch storyboard'
    for nib in nibs:
        assert b'NSLocalizableString' not in nib.read_bytes(), 'Runtime translation lookup remains'
    print('Compiled nonlocalized launch resource PASS')
