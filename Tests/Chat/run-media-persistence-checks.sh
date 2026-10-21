#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
a=s.index('    func saveFailedMedia('); b=s.index('    /// 只更新同一消息', a)
mapper=(root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
a2=mapper.index('        // 仅恢复本人失败消息'); b2=mapper.index('        let sdk = ', a2)
(tmp/'production.swift').write_text('import Foundation\nextension PersistenceClient {\n'+s[a:b]+'}\nfunc restore(_ source: ChatMessageRecord, _ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {\nvar record = source; let type = record.type\n'+mapper[a2:b2]+'\nreturn record\n}\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$TMP_DIR/production.swift" \
 "$ROOT_DIR/Tests/Chat/MediaPersistenceChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
