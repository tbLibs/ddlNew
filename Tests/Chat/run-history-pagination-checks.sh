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
    '    func cached(', '    func history(', '    private func cacheSnapshot(', '    private func startGroupPermissionRefresh('
])
(out/'ProductionHistory.swift').write_text('import Foundation\nimport ObjectiveC\nextension HistoryClient {\n'+methods+'\n}\n')
view = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
refresh = view[view.index('.refreshable {'):view.index('.simultaneousGesture', view.index('.refreshable {'))]
action = re.search(r'await store\.(\w+)\(\)', refresh).group(1)
(out/'RefreshAction.swift').write_text('extension ChatStore { func invokePullToRefresh() async { await '+action+'() } }\n')

mapper = (root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
status = re.search(r'status: (ChatMessageStatus\(rawValue: model.messageStatus\) \?\? \.\w+),', mapper).group(1)
(out/'ProductionMessageStatus.swift').write_text('enum ProductionMessageStatus { static func map(_ rawValue: Int) -> ChatMessageStatus { '+status.replace('model.messageStatus', 'rawValue')+' } }\n')


db = (root/'NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/DataBaseModule/NoaIMDBTool+ChatMessage.mm').read_text()
query = db[db.index('- (NSArray<NoaIMChatMessageModel *> *)getChatMessageTimelineWith:'):]
predicate = re.search(r'where:(.*?) orders:', query).group(1).replace('NoaIMChatMessageModel.messageStatus', 'rawValue')
(out/'ProductionTimelineStatus.swift').write_text('enum ProductionTimelineStatus { static func includes(_ rawValue: Int) -> Bool { '+predicate+' } }\n')

PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" \
 "$ROOT_DIR/Tests/Chat/HistoryPaginationChecks.swift" "$TMP_DIR/ProductionHistory.swift" "$TMP_DIR/RefreshAction.swift" "$TMP_DIR/ProductionMessageStatus.swift" "$TMP_DIR/ProductionTimelineStatus.swift" \
 "$ROOT_DIR/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
