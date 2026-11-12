"""Check task-owned UI, state and error literals against the three-language catalog."""
import json, re
from pathlib import Path
root = Path(__file__).resolve().parents[2]
catalog = json.loads((root / 'ddlNew/Resources/Localization/Localizable.xcstrings').read_text())['strings']
keys = {'最多输入%@个字符', '标记为%@', '群事项', '转为事项', '事项'}
for path in (root / 'ddlNew/Features/Tasks').glob('*.swift'):
    for key in re.findall(r'"([^"\n]*)"', path.read_text()):
        if re.search(r'[\u4e00-\u9fff]', key) and '\\(' not in key:
            keys.add(key)
for key in keys:
    assert key in catalog, f'Missing translation key: {key}'
    for language in ['en', 'zh-Hans', 'zh-Hant']:
        unit = catalog[key]['localizations'][language]['stringUnit']
        assert unit['value'] and unit['state'] == 'translated', (key, language)
print(f'Task localization: {len(keys)} UI/status/error keys verified in three languages')
