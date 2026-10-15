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
observed = re.search(r'\.onChange\(of: store\.(locationRevision|locatedMessageID)\)', s).group(1)
(out/'Observed.swift').write_text('import Foundation\n@MainActor extension ChatStore { var observedLocation: AnyHashable { AnyHashable('+observed+') } }\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" \
 "$ROOT_DIR/Tests/Chat/LocationChecks.swift" "$TMP_DIR/Observed.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import re, sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
def block(marker):
    start=s.index(marker); a=s.index('{',start); b=a+1; depth=1
    while depth:
        depth+=(s[b]=='{')-(s[b]=='}'); b+=1
    return s[start:b],s[a+1:b-1]
marker = '.onChange(of: store.locationRevision)' if '.onChange(of: store.locationRevision)' in s else '.onChange(of: store.locatedMessageID)'
callback=block(marker)[1].split(' in',1)[1]
banner_start=s.index('if let pinned = pinnedMessages.first')
a=s.index('Button {',banner_start)+len('Button '); b=a+1; depth=1
while depth:
    depth+=(s[b]=='{')-(s[b]=='}'); b+=1
banner=s[a+1:b-1]
methods=''
for name in ['receiveLocatedMessage', 'positionLocatedMessage', 'queueSheetLocation', 'locateAfterSheetDismissal']:
    if 'private func '+name+'(' in s: methods+='\n'+block('    private func '+name+'(')[0]
code='''import SwiftUI
@MainActor final class LocationScreen {
    var store = LocationUIStore()
    var runtime = LocationRuntime()
    var conversationClosed = false
    var pendingSheetLocation: (id: String, context: String)?
    var requested: [String] = []
    func locateMessage(_ id: String) { requested.append(id) }
    func bannerTapped() { let pinned = (serverID: "server-old", localID: "local-old"); BANNER }
    var pendingLocatedMessageID: String?
    var followsInitialLatest = true
    var didInitialScroll = false
    var showPinnedMessages = false
    var showFullHistorySearch = false
    var viewport = CGRect(x: 0,y: 0,width: 390,height: 500)
    var messageFrames: [String: CGRect] = [:]
    var resizeFollowTask: Task<Void,Never>?
METHODS
    func changed(_ proxy: LocationProxy) { let id = store.locatedMessageID; _ = id; CALLBACK }
    func layoutReady(_ proxy: LocationProxy) { POSITION }
    func selectFromSheet(_ id: String) { SELECT }
    func sheetDismissed() { DISMISS }
}
'''.replace('SELECT','queueSheetLocation(id)' if 'private func queueSheetLocation(' in s else 'locateMessage(id)').replace('DISMISS','locateAfterSheetDismissal()' if 'private func locateAfterSheetDismissal(' in s else '').replace('BANNER',banner).replace('METHODS',methods).replace('CALLBACK',callback).replace('POSITION','positionLocatedMessage(proxy)' if methods else '')
code=code.replace('ScrollViewProxy','LocationProxy')
(out/'LocationUI.swift').write_text(code)
PY
swiftc -parse-as-library "$ROOT_DIR/Tests/Chat/LocationLayoutChecks.swift" "$TMP_DIR/LocationUI.swift" -o "$TMP_DIR/layout-checks"
"$TMP_DIR/layout-checks"
