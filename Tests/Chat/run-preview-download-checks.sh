#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
# 执行生产加载、关闭和失效方法；仅网络、iOS音频与解包暂停点由离线夹具提供。
python3 - "$task_root" "$task_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Media/ChatMediaPreviewStore.swift').read_text()
prefix = source[:source.index('    /// 缓存路径')]
prefix = prefix.replace('import AVFoundation\n', '').replace('ChatMediaPreviewStore: NSObject, ObservableObject, AVAudioPlayerDelegate', 'ProductionPreview: NSObject, ObservableObject')
def method(name):
    start = source.index('    ' + name)
    cursor = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[cursor] == '{') - (source[cursor] == '}')
        cursor += 1
    return source[start:cursor] + '\n'
methods = ''.join(method(name) for name in ['func load(', 'func invalidateMessage(', 'private func invalidate(', 'func close(', 'static func clearCache('])
# 包装器只在真实解包前加暂停点，仍执行 LegacyChatMediaCodec 的生产流式实现。
methods = methods.replace('LegacyChatMediaCodec.decodeFile(temporary)', 'PreviewDecodeGate.decodeFile(temporary)')
(out/'ProductionPreview.swift').write_text(prefix + methods + '}\n')
PY
swiftc -parse-as-library "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/ddlNew/Features/Chat/Models/"*.swift \
 "$task_root/ddlNew/Common/Media/LegacyChatMediaCodec.swift" \
 "$task_root/ddlNew/Network/Core/RemoteAvatarURL.swift" \
 "$task_temp/ProductionPreview.swift" "$task_root/Tests/Chat/PreviewDownloadChecks.swift" -o "$task_temp/checks"
"$task_temp/checks"
