#!/usr/bin/env python3
"""Audit the three language tables against production L10n call sites."""
import re, pathlib, json, subprocess, sys
from collections import Counter
ROOT = pathlib.Path(__file__).resolve().parents[2]

def swift_string(s, i):
    assert s[i] == '"'
    i += 1; out = ''
    while i < len(s):
        if s[i] == '"': return out, i + 1
        if s.startswith('\\(', i):
            depth = 1; i += 2
            while depth:
                if s[i] == '"': _, i = swift_string(s, i); continue
                if s[i] == '(': depth += 1
                elif s[i] == ')': depth -= 1
                i += 1
            out += '\x00'; continue
        if s[i] == '\\' and i + 1 < len(s):
            out += {'n':'\n', 'r':'\r', 't':'\t', '0':'\0'}.get(s[i+1], s[i+1]); i += 2
        else: out += s[i]; i += 1
    raise ValueError('Unterminated Swift literal')

def keys():
    # CallParticipant.stateText is a stable internal state used by call coordination.
    result = {"呼叫中", "已加入", "已拒绝", "未应答", "已离开"}
    for path in (ROOT/'ddlNew').rglob('*.swift'):
        s = path.read_text()
        for match in re.finditer(r'L10n\.(?:tr|lookup)\(\s*(?=")', s):
            value, _ = swift_string(s, match.end())
            result.add(value.replace('%','%%').replace('\x00','%@') if '\x00' in value else value)
        # Stable Chinese raw values localized for display only.
        if 'L10n.lookup(rawValue)' in s:
            for match in re.finditer(r'(?:case\s+|,\s*)\w+\s*=\s*(?=")', s):
                value, _ = swift_string(s, match.end())
                if re.search('[\u3400-\u9fff]',value): result.add(value)
    # These bundled activity examples explicitly opt into render-time lookup.
    # Other activity/user content is intentionally not treated as a translation key.
    sample_path = ROOT/'ddlNew/Features/Activities/Models/ClubActivity.swift'
    for line in sample_path.read_text().splitlines():
        if '.init(' not in line or 'isBuiltInSample: true' not in line: continue
        for match in re.finditer(r'\b(?:title|category|date|place|meetingPoint|requirement|notice):\s*(?=")', line):
            value, _ = swift_string(line, match.end())
            result.add(value)
    return result

def read_table(path):
    return json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(path)]))

def format_arguments(value):
    # Include integer/float specifiers: a translated %@ must never become %d.
    tokens = re.finditer(r"%%|%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?(hh|ll|h|l|q|z|t|j)?([@diuoxXfFeEgGaAcCsSp])", value)
    result = Counter(); sequential = 0
    for token in tokens:
        if token.group() == '%%': continue
        sequential += 1
        index = int(token.group(1)) if token.group(1) else sequential
        result[(index, (token.group(2) or '') + token.group(3))] += 1
    return result

def duplicate_keys(path):
    literals = re.findall(r'^\s*("(?:\\.|[^"\\])*")\s*=',path.read_text(),re.MULTILINE)
    return [key for key,count in Counter(json.loads(s) for s in literals).items() if count>1]

def main():
    expected = keys(); errors = []
    for language in ['zh-Hans','zh-Hant','en']:
        path = ROOT/'ddlNew/Resources/Localization'/f'{language}.lproj/Localizable.strings'
        table = read_table(path)
        duplicates = duplicate_keys(path)
        if duplicates: errors.append(f'{language}: duplicate keys: {duplicates}')
        stale = table.keys() - expected
        if stale: errors.append(f'{language}: stale keys: {sorted(stale)}')
        missing = expected-table.keys()
        if missing: errors.append(f'{language}: missing {len(missing)}: {sorted(missing)}')
        for key in expected & table.keys():
            source = format_arguments(key)
            target = format_arguments(table[key])
            if source != target: errors.append(f'{language}: placeholder mismatch: {key}')
            if language=='en' and re.search('[\u3400-\u9fff]',table[key]) and key!='简体中文、繁體中文、English':
                errors.append(f'en: Chinese text: {key}')
        privacy = read_table(path.with_name('InfoPlist.strings'))
        required = {'NSCameraUsageDescription', 'NSMicrophoneUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSPhotoLibraryAddUsageDescription'}
        if privacy.keys() != required or any(not v.strip() for v in privacy.values()):
            errors.append(f'{language}: incomplete privacy descriptions')
        if language == 'en' and any(re.search('[\u3400-\u9fff]', v) for v in privacy.values()):
            errors.append('en: untranslated privacy description')
        print(f'{language}: {len(table)} keys, {len(expected)} used keys, {len(missing)} missing')
    if errors:
        print('\n'.join(errors)); return 1
    return 0
if __name__=='__main__': sys.exit(main())
