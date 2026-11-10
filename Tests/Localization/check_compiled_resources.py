#!/usr/bin/env python3
"""Verify every catalog translation survives compilation into runtime tables."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
product = Path(sys.argv[1])
for name in ['Localizable', 'InfoPlist']:
    catalog = json.loads((root / f'ddlNew/Resources/Localization/{name}.xcstrings').read_text())
    for language in ['zh-Hans', 'zh-Hant', 'en']:
        path = product / f'{language}.lproj/{name}.strings'
        compiled = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
        expected = {key: entry['localizations'][language]['stringUnit']['value'] for key, entry in catalog['strings'].items() if entry.get('shouldTranslate') is not False}
        for key, value in expected.items():
            assert compiled.get(key) == value, f'{name}/{language}: compiled translation differs: {key}'
        print(f'{name}/{language}: {len(expected)} compiled translations verified')
