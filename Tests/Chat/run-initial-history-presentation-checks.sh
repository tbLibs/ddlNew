#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
def block(marker):
    start = s.index(marker); opening = s.index('{', start); end = opening + 1; depth = 1
    while depth:
        depth += (s[end] == '{') - (s[end] == '}'); end += 1
    return s[start:end].replace('private ', '').replace('ScrollViewProxy', 'PresentationProxy')
# 使用真实视图的放行条件、首屏定位方法及布局快照表达式；仅替代系统滚动执行。
start = s.index('ChatLatestPreference.Value(frame:')
end = start + len('ChatLatestPreference.Value('); depth = 1
while depth:
    depth += (s[end] == '(') - (s[end] == ')'); end += 1
layout = s[start:end].replace('geometry.frame(in: .named("chatViewport"))', 'frame')
code = '''import SwiftUI
@MainActor final class PresentationScreen {
    let store: ChatStore
    let route: ChatRoute
    init(store: ChatStore, route: ChatRoute) { self.store = store; self.route = route }
    var displayedMessages: [ChatMessageRecord] { store.messages.filter(\\.isVisible) }
    var latestLayout = ChatLatestPreference.Value()
    var latestFrame: CGRect { latestLayout.frame }
    var viewport = CGRect(x: 0, y: 0, width: 390, height: 500)
    var followsInitialLatest = true
    var didInitialScroll = false
    var alignedInitialHistoryRevision = 0
    var resizeFollowTask: Task<Void, Never>?
    var visibleUpdates = 0
    func updateVisibleMessages() { visibleUpdates += 1 }
METHODS
    func layout(_ frame: CGRect) -> ChatLatestPreference.Value {
        let messages = displayedMessages
        let initialHistoryRevision = store.initialHistoryRevision
        return LAYOUT
    }
    func align(_ proxy: PresentationProxy) { positionInitialMessages(proxy) }
}
'''.replace('METHODS', block('    private var initialMessagesReady:')+'\n'+block('    private func positionInitialMessages(')).replace('LAYOUT', layout)
(out/'Presentation.swift').write_text(code)
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Components/ChatLatestPreference.swift" \
 "$ROOT_DIR/Tests/Chat/InitialHistoryPresentationChecks.swift" "$TMP_DIR/Presentation.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
