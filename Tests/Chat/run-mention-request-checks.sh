#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 执行页面实际加载/资格方法；仅SDK等待与SwiftUI容器替换为离线形状。
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
def block(start):
    begin = source.index(start)
    cursor = source.index('{', begin) + 1
    depth = 1
    while depth:
        depth += (source[cursor] == '{') - (source[cursor] == '}')
        cursor += 1
    return source[begin:cursor].replace('private ', '') + '\n'
request = block('private struct ChatMentionRequest')
methods = block('    private func loadMentionMembers(') + block('    private func isCurrentMentionRequest(')
prefix = '''import Foundation
@MainActor final class ProductionMentionPage {
    let store = MentionStoreShape()
    let runtime = MentionRuntimeShape()
    var mentionRequest: ChatMentionRequest?
    var showMentionPicker = false
    var mentionMembers: [ChatGroupMember] = []
    var composerMode = ChatComposerMode()
    var composerFocused = false
    var showSettings = false
    var selectedProfile: String?
'''
(out/'ProductionMentionPage.swift').write_text(request + prefix + methods + '}\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$TMP_DIR/ProductionMentionPage.swift" \
 "$ROOT_DIR/Tests/Chat/MentionRequestChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
