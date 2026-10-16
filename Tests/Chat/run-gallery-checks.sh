#!/bin/sh
set -eu
gallery_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
gallery_temp=$(mktemp -d)
trap 'rm -rf "$gallery_temp"' EXIT
python3 - "$gallery_root" "$gallery_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
start = source.index('    private func activateMessage(')
cursor = source.index('{', start) + 1
depth = 1
while depth:
    depth += (source[cursor] == '{') - (source[cursor] == '}')
    cursor += 1
harness = '''import Foundation
@MainActor final class GalleryRouteStore {
    var messages: [ChatMessageRecord] = []
    var toggledID: String?
    func toggleSelection(_ id: String) { toggledID = id }
}
struct ContactsRoute { let contactID: String }
enum GalleryPanel { case keyboard, selection }
struct GalleryComposer { var panel = GalleryPanel.keyboard }
@MainActor final class GalleryRouteHarness {
    let store = GalleryRouteStore()
    var composerMode = GalleryComposer()
    var selectedProfile: ContactsRoute?
    var forwardRecord: ChatMessageRecord?
    var locationMessage: ChatMessageRecord?
    var mediaMessage: ChatMessageRecord?
    var mediaGallery: ChatMediaGallery?
    func open(_ message: ChatMessageRecord) { activateMessage(message) }
'''
(out/'GalleryRoute.swift').write_text(harness + source[start:cursor] + '\n}\n')
view = (root/'ddlNew/Features/Chat/Views/ChatMediaGalleryView.swift').read_text()
def method(name):
    start = view.index('    private func ' + name)
    cursor = view.index('{', start) + 1
    depth = 1
    while depth:
        depth += (view[cursor] == '{') - (view[cursor] == '}')
        cursor += 1
    return view[start:cursor] + '\n'
(out/'GalleryLifecycle.swift').write_text('import Foundation\n@MainActor final class GalleryLifecycleHarness {\n' + '''
    let context: ChatContext
    let items: [ChatMessageRecord]
    var currentID: String
    var currentMessage: ChatMessageRecord? { items.first { $0.id == currentID } }
    var scenePhase = GalleryScenePhase.active
    var zoomScale: CGFloat = 1
    var controlsVisible = true
    var saveFeedback: String?
    let preview = GalleryPreviewBoundary()
    let playback = GalleryPlaybackBoundary()
    init(context: ChatContext, items: [ChatMessageRecord]) { self.context = context; self.items = items; currentID = items[0].id }
    func load() async { await loadCurrent() }
    func choose(_ id: String) { select(id) }
''' + method('select(') + method('loadCurrent(') + '}\n')
PY
swiftc -parse-as-library "$gallery_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$gallery_root/ddlNew/Features/Chat/Models/"*.swift "$gallery_temp/"*.swift \
 "$gallery_root/Tests/Chat/GalleryChecks.swift" -o "$gallery_temp/checks"
"$gallery_temp/checks"
