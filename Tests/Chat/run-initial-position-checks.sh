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
    return s[start:end], s[opening+1:end-1]
_, changed = block('.onChange(of: store.messages.last?.id)')
_, geometry = block('.onPreferenceChange(ChatLatestPreference.self)')
changed = changed.split(' in', 1)[1]
geometry = geometry.split(' in', 1)[1]
new = 'private func positionInitialMessages(' in s
methods = block('    private func followAfterResize(')[0]
if new: methods += '\n' + block('    private func positionInitialMessages(')[0]
if '    private func positionSendSuccess(' in s:
    methods += '\n' + block('    private func positionSendSuccess(')[0].replace('private ', '')
if '    private func resumeChat(' in s:
    methods += '\n' + block('    private func resumeChat(')[0]
    resume = 'resumeChat(proxy)'
else:
    resume = block('.onAppear { store.isForeground')[1]
fields = 'var latestFrame = CGRect.zero\n' if not new else 'var latestLayout = ChatLatestLayout()\nvar latestFrame: CGRect { latestLayout.frame }\n'
fields += 'var pendingSendSuccessScroll = false\n'
argument = '_ frame: CGRect' if not new else '_ layout: ChatLatestLayout'
geometry_call = 'layout.frame' if not new else 'layout'
code = '''import SwiftUI
@MainActor final class ProductionInitialPosition {
    let store = PositionStore()
    var route = PositionRoute()
    var viewport = CGRect(x: 0, y: 0, width: 390, height: 500)
    var didInitialScroll = false
    var alignedInitialHistoryRevision = 0
    var followsInitialLatest = true
    var resizeFollowTask: Task<Void, Never>?
    var displayedMessages: [PositionMessage] { store.messages }
    var visibleUpdates = 0
    var scenePhase = ScenePhase.active
    func updateVisibleMessages() { visibleUpdates += 1 }
    func positionLocatedMessage(_ proxy: PositionProxy) {}
    func returnToLatest() { store.isAtBottom = true }
FIELDS
METHODS
    func changed(_ id: String?, proxy: PositionProxy) { CHANGED }
    func geometryChanged(ARGUMENT, proxy: PositionProxy) { GEOMETRY }
    func accept(_ layout: ChatLatestLayout, proxy: PositionProxy) { geometryChanged(GEOMETRY_CALL, proxy: proxy) }
    func resume(proxy: PositionProxy) { RESUME }
}
'''.replace('FIELDS',fields).replace('METHODS',methods).replace('CHANGED',changed).replace('ARGUMENT',argument).replace('GEOMETRY_CALL',geometry_call).replace('GEOMETRY',geometry).replace('RESUME',resume)
# 类型边界仅替代UI滚动执行，首次定位与布局回调执行生产方法。
code = code.replace('ScrollViewProxy', 'PositionProxy')
(out/'Production.swift').write_text(code)
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatViewportPolicy.swift" \
 "$ROOT_DIR/Tests/Chat/InitialPositionChecks.swift" "$TMP_DIR/Production.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
