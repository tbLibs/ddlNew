#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys, re
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
def method(marker):
    start = s.index(marker)
    a = s.index('{', start)
    b, depth = a + 1, 1
    while depth:
        depth += (s[b] == '{') - (s[b] == '}')
        b += 1
    return s[start:b]
methods = '\n'.join(method(marker) for marker in [
    '    func cached(', '    func history(', '    private func cacheSnapshot('
])
(out/'ProductionHistory.swift').write_text('import Foundation\nimport ObjectiveC\nextension HistoryClient {\n'+methods+'\n}\n')
view = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
refresh = view[view.index('.refreshable {'):view.index('.simultaneousGesture', view.index('.refreshable {'))]
action = re.search(r'await store\.(\w+)\(\)', refresh).group(1)
(out/'RefreshAction.swift').write_text('extension ChatStore { func invokePullToRefresh() async { await '+action+'() } }\n')

PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" \
 "$ROOT_DIR/Tests/Chat/HistoryPaginationChecks.swift" "$TMP_DIR/ProductionHistory.swift" "$TMP_DIR/RefreshAction.swift" \
 "$ROOT_DIR/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
