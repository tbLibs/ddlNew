#!/usr/bin/env python3
"""Check embedded launch translations and keep localized storyboard layouts identical."""
from pathlib import Path
import plistlib
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2] / 'ddlNew/Resources'
expected = {
    'zh-Hans': ('叮咚聊', '一起发现，一起参与'),
    'zh-Hant': ('叮咚聊', '一起發現，一起參與'),
    'en': ('DingDong Chat', 'Discover and take part together'),
}
assert not (root / 'Base.lproj/AppLaunchScreen.storyboard').exists(), 'Launch must select a complete language variant'
baseline = None
for language, texts in expected.items():
    folder = root / f'{language}.lproj'
    path = folder / 'AppLaunchScreen.storyboard'
    assert path.exists(), f'{language}: missing self-contained launch storyboard'
    assert not (folder / 'AppLaunchScreen.strings').exists(), f'{language}: launch text must be embedded'
    tree = ET.parse(path)
    labels = {item.attrib['id']: item for item in tree.iter('label')}
    assert labels['launch-title'].attrib['text'] == texts[0], language
    assert labels['launch-subtitle'].attrib['text'] == texts[1], language
    assert tree.getroot().attrib['launchScreen'] == 'YES', language
    for item in tree.iter():
        assert 'customClass' not in item.attrib, f'{language}: launch cannot depend on application code'
    # Only the translated text may differ; images, constraints, colors and typography must match.
    for item in labels.values():
        item.attrib.pop('text')
    layout = ET.tostring(tree.getroot())
    if baseline is None:
        baseline = layout
    else:
        assert layout == baseline, f'{language}: launch layout differs from zh-Hans'
    print(f'{language}: embedded launch text and layout PASS')

if len(sys.argv) > 1:
    app = Path(sys.argv[1])
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['UILaunchStoryboardName'] == 'AppLaunchScreen'
    assert not (app / 'Base.lproj/AppLaunchScreen.storyboardc').exists(), 'Unexpected Base launch fallback'
    assert not list(app.glob('*.lproj/*LaunchScreen.strings')), 'Stale launch strings remain in the product'
    for language in expected:
        folder = app / f'{language}.lproj/AppLaunchScreen.storyboardc'
        nibs = list(folder.glob('*.nib'))
        assert nibs, f'{language}: missing compiled launch storyboard'
        for nib in nibs:
            assert b'NSLocalizableString' not in nib.read_bytes(), f'{language}: runtime translation lookup remains'
        print(f'{language}: compiled standalone launch resource PASS')
