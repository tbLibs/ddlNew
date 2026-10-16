#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import re, sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
def block(marker):
    start = s.index(marker); opening = s.index('{', start); end = opening + 1; depth = 1
    while depth:
        depth += (s[end] == '{') - (s[end] == '}'); end += 1
    return s[start:end], s[opening+1:end-1]
fields = []
for name in ['messageFrames', 'latestLayout', 'visibleMessageIDs', 'scrollGeometry', 'followsInitialLatest', 'resizeFollowTask', 'pendingSendSuccessScroll']:
    match = re.search(r'^    @State private var '+name+r'\b.*$', s, re.M)
    if match: fields.append(match.group().replace('@State private', '@Tracked'))
    elif '    private var '+name+':' in s:
        fields.append(block('    private var '+name+':')[0].replace('private ', '').replace('nonmutating ', ''))
_, frames = block('.onPreferenceChange(ChatVisibilityPreference.self)')
_, latest = block('.onPreferenceChange(ChatLatestPreference.self)')
_, drag = block('.onChanged { _ in')
drag = drag.split(' in', 1)[1]
ended = block('.onEnded { _ in')[1].split(' in', 1)[1] if '.onEnded { _ in' in s else ''
frames = frames.split(' in', 1)[1]; latest = latest.split(' in', 1)[1].replace('positionSendSuccess(proxy)', '')
method = block('    private func updateVisibleMessages(')[0].replace('private ', '')
code = '''import SwiftUI
@MainActor final class ProductionScroll {
FIELDS
    let store = ScrollStore()
    var viewport = CGRect(x: 0, y: 0, width: 390, height: 500)
    var initialMessagesReady = true
    var latestFrame: CGRect { latestLayout.frame }
    func positionInitialMessages(_ proxy: Int) {}
    func positionLocatedMessage(_ proxy: Int) {}
METHOD
    func dragChanged() { DRAG }
    func dragEnded() { ENDED }
    func framesChanged(_ frames: [String: CGRect]) { let proxy = 0; FRAMES }
    func latestChanged(_ layout: ChatLatestPreference.Value) { let proxy = 0; LATEST }
}
'''.replace('FIELDS', '\n'.join(fields)).replace('METHOD', method).replace('FRAMES', frames).replace('LATEST', latest).replace('DRAG', drag).replace('ENDED', ended)
date_method = block('    private func showsDate(')[0].replace('private ', '')
date_call = 'showsDate(for: message, after: index > 0 ? records[index - 1] : nil)' if 'after previous:' in date_method else 'showsDate(for: message)'
code += '''
struct ChatMessageRecord { let id: String; let timestamp: Int64 }
@MainActor final class ProductionDates {
    var snapshotReads = 0
    var records: [ChatMessageRecord] = []
    var displayedMessages: [ChatMessageRecord] { snapshotReads += 1; return records }
    DATE_METHOD
    func results() -> [Bool] { records.enumerated().map { index, message in DATE_CALL } }
}
'''.replace('DATE_METHOD', date_method).replace('DATE_CALL', date_call)
(out/'Production.swift').write_text(code)
PY
GEOMETRY_FILE="$ROOT_DIR/ddlNew/Features/Chat/Components/ChatScrollGeometry.swift"
if [ ! -f "$GEOMETRY_FILE" ]; then
    GEOMETRY_FILE="$TMP_DIR/Geometry.swift"
    touch "$GEOMETRY_FILE"
fi
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Components/ChatLatestPreference.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatViewportPolicy.swift" "$GEOMETRY_FILE" \
 "$ROOT_DIR/Tests/Chat/ScrollPerformanceChecks.swift" "$TMP_DIR/Production.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
