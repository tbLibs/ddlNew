#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 提取实际生产关闭/失效方法；音频及网络形状替代仅存在这个离线目标。
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Media/ChatMediaPreviewStore.swift').read_text()
prefix = source[:source.index('    /// 缓存路径')]
prefix = prefix.replace('import CryptoKit\n', '').replace('import AVFoundation\n', '').replace('ChatMediaPreviewStore: NSObject, ObservableObject, AVAudioPlayerDelegate', 'ProductionPreview: NSObject, ObservableObject')
def method(name):
    start = source.index('    ' + name)
    body = source.index('{', start)
    depth = 1
    cursor = body + 1
    while depth:
        depth += (source[cursor] == '{') - (source[cursor] == '}')
        cursor += 1
    return source[start:cursor] + '\n'
methods = method('func invalidateDeletedMessages(') + method('private func invalidate(') + method('func close(')
methods += method('func invalidateMessage(')
helper = '''
    /// 测试形状只注入已绑定附件；不读取真实账号或资源。
    func prepare(context: ChatContext, senderID: String, session: URLSession, player: AVAudioPlayer) {
        loadedContext = context; loadedSenderID = senderID; loadedMessageID = "m"
        self.session = session; self.player = player
        file = URL(fileURLWithPath: "/tmp/anonymous-qa-file"); loading = true; playing = true
    }
}
'''
(out/'ProductionPreview.swift').write_text(prefix + methods + helper)
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$TMP_DIR/ProductionPreview.swift" \
 "$ROOT_DIR/Tests/Chat/PreviewInvalidationChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
