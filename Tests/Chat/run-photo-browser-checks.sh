#!/bin/sh
set -eu
gallery_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
gallery_temp=$(mktemp -d)
trap 'rm -rf "$gallery_temp"' EXIT
python3 - "$gallery_root" "$gallery_temp" <<'PY'
from pathlib import Path
import sys
import re
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
    var context: ChatContext? = ChatContext(userUID: "u", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "chat", kind: .single, title: "", avatarURL: ""))
    var errorMessage: String?
    func markVisible(_ id: String, voicePlayed: Bool) async {}
    var toggledID: String?
    func toggleSelection(_ id: String) { toggledID = id }
}
struct ContactsRoute { let contactID: String }
enum GalleryPanel { case keyboard, selection }
struct GalleryComposer { var panel = GalleryPanel.keyboard }
@MainActor final class GalleryVoiceBoundary {
    var openedID: String?
    func stop() { openedID = nil }
    func toggle(_ message: ChatMessageRecord, context: ChatContext, onPlayed: @escaping () -> Void, onError: @escaping (String) -> Void) { openedID = message.id }
}
@MainActor final class GalleryRouteHarness {
    let store = GalleryRouteStore()
    let voicePlayback = GalleryVoiceBoundary()
    var composerMode = GalleryComposer()
    var selectedProfile: ContactsRoute?
    var forwardRecord: ChatMessageRecord?
    var locationMessage: ChatMessageRecord?
    var mediaMessage: ChatMessageRecord?
    var mediaGallery: ChatPhotoBrowserRequest?
    func open(_ message: ChatMessageRecord) { activateMessage(message) }
'''
(out/'GalleryRoute.swift').write_text(harness + re.sub(r'(?<![.\w])store\.', 'self.store.', source[start:cursor]) + '\n}\n')
view = (root/'ddlNew/Features/Chat/Views/ChatPhotoBrowserView.swift').read_text()
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
    var controlsVisible = true
    var isClosing = false
    var saveFeedback: String?
    var allowSharing = true
    var shareRequest: ChatPhotoBrowserShareRequest?
    let resources = ChatPhotoBrowserResources(warmImage: { _ in {} })
    var preview: GalleryPreviewBoundary { resources.current }
    let playback = GalleryPlaybackBoundary()
    init(context: ChatContext, items: [ChatMessageRecord]) { self.context = context; self.items = items; currentID = items[0].id }
    func load() async { await loadCurrent() }
    func choose(_ id: String) { select(id) }
    func shareFile(_ file: URL, message: ChatMessageRecord) { share(file, message: message) }
    func finishSharing(_ id: UUID, error: String?) { finishShare(requestID: id, error: error) }
''' + method('select(') + method('loadCurrent(') + method('share(') + method('finishShare(') + '}\n')
bridge = (root/'ddlNew/Features/Chat/Media/PhotoBrowser/ChatPhotoBrowser.swift').read_text()
def bridge_method(name):
    start = bridge.index('        func ' + name)
    cursor = bridge.index('{', start) + 1
    depth = 1
    while depth:
        depth += (bridge[cursor] == '{') - (bridge[cursor] == '}')
        cursor += 1
    return bridge[start:cursor] + '\n'
(out/'GalleryBrowserSelection.swift').write_text('import Foundation\n' + '''
@MainActor final class GalleryBrowserSelectionHarness {
    final class Parent {
        var calls: [String] = []
        func onSelect(_ id: String) { calls.append(id) }
    }
    let parent = Parent()
    var selection = ChatPhotoBrowserSelection(ids: ["one", "two", "three"], selectedID: "one")
    var isAttached = true
    var isReloading = false
''' + bridge_method('didSelect(') + bridge_method('publishSelection(') + '}\n')
PY
swiftc -parse-as-library "$gallery_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$gallery_root/ddlNew/Features/Chat/Models/"*.swift "$gallery_temp/"*.swift \
 "$gallery_root/ddlNew/Features/Chat/Media/PhotoBrowser/ChatPhotoBrowserResources.swift" \
 "$gallery_root/Tests/Chat/PhotoBrowserChecks.swift" -o "$gallery_temp/checks"
"$gallery_temp/checks"
