#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-voice-gesture.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
# 编译生产UIControl的跟踪方法，仅替换UIKit触摸输入边界；不访问麦克风或真实聊天。
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Components/ChatVoiceRecordButton.swift').read_text()
start = s.index('    final class VoiceControl: UIControl {')
cursor = s.index('{', start) + 1
depth = 1
while depth:
    depth += (s[cursor] == '{') - (s[cursor] == '}')
    cursor += 1
(out/'VoiceControl.swift').write_text('import Foundation\nimport CoreGraphics\n' + s[start:cursor].replace('@objc ', ''))
PY
swiftc -parse-as-library "$TASK_TMP/VoiceControl.swift" "$TASK_ROOT/Tests/Chat/VoiceGestureChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
