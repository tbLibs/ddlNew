#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import re, sys
root, temp = map(Path, sys.argv[1:])
mapper = (root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
start = mapper.index('        let sdk = NoaIMSDKManager.sharedTool()')
end = mapper.index('        return record', start)
metadata = mapper[start:end]
bubble = (root/'ddlNew/Features/Chat/Components/ChatMessageBubble.swift').read_text()
image = bubble[bubble.index('    private var avatarImage:'):]
argument = re.search(r'KFImage\(RemoteAvatarURL.resolve\(([^,]+),', image).group(1)
resource = ''
if argument.strip() == 'avatarResource':
    start = bubble.index('    private var avatarResource:')
    opening = bubble.index('{', start)
    depth = 1; end = opening + 1
    while depth:
        depth += (bubble[end] == '{') - (bubble[end] == '}')
        end += 1
    resource = bubble[start:end].replace('private var', 'var', 1)
(temp/'Production.swift').write_text('''import Foundation
struct ProductionMapper {
    static func metadata(_ input: ChatMessageRecord, userUID: String, group: Bool = false) -> ChatMessageRecord {
        var record = input
        let model = MessageKind(chatType: Kind(rawValue: group ? 1 : 0))
'''+metadata+'''        return record
    }
}
@MainActor struct ProductionAvatar {
    let message: ChatMessageRecord
    let own: Bool
    let session: Session
'''+resource+'''
    var displayedResource: String { '''+argument+''' }
}
''')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatMessageRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatFailureReason.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatMentionSegment.swift" \
 "$ROOT_DIR/Tests/Chat/AvatarChecks.swift" "$TMP_DIR/Production.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
