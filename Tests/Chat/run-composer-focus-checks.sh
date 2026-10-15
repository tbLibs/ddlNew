#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-composer-focus.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
# 保留生产焦点绑定类型与同步/代理方法；仅UITextView和富文本绘制换成离线形状。
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import re, sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Components/ChatComposerTextInput.swift').read_text()
focus = re.search(r'var focused: ([^\n]+)', source).group(1)
def block(start):
    begin = source.index(start); cursor = source.index('{', begin) + 1; depth = 1
    while depth:
        depth += (source[cursor] == '{') - (source[cursor] == '}'); cursor += 1
    return source[begin:cursor] + '\n'
update = block('    func updateUIView(')
begin = block('        func textViewDidBeginEditing(')
end = block('        func textViewDidEndEditing(')
code = '''import SwiftUI
import Foundation
@MainActor struct ProductionFocusInput {
    var focused: FOCUS
    var text = ""
    var isEnabled = true
    struct Context { let coordinator: Coordinator }
UPDATE
    @MainActor final class Coordinator {
        var parent: ProductionFocusInput
        var renders = 0
        init(_ parent: ProductionFocusInput) { self.parent = parent }
        func render(_ view: EmojiTextView) { renders += 1 }
BEGIN
END
    }
}
'''.replace('FOCUS', focus).replace('UPDATE', update).replace('BEGIN', begin).replace('END', end)
(out/'ProductionFocusInput.swift').write_text(code)
PY
swiftc -parse-as-library "$TASK_TMP/ProductionFocusInput.swift" "$TASK_ROOT/Tests/Chat/ComposerFocusChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
