#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
start=s.index('    func makeModel(');end=s.index('    /// 正文已读',start)
mapper=(root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
branch=next(line for line in mapper.splitlines() if line.strip().startswith('case 5: record.'))
(tmp/'Production.swift').write_text('import Foundation\nimport UniformTypeIdentifiers\nstruct ProductionFileClient {\n'+s[start:end]+'\n}\nstruct ProductionFileMapper { static func record(_ model: NoaIMChatMessageModel) -> ChatMessageRecord { var record = ChatMessageRecord(localID: model.msgID ?? "", conversationID: model.toID ?? "", senderID: model.fromID ?? "", senderName: "", type: 5, timestamp: 1)\nswitch 5 {\n'+branch+'\ndefault: break\n}\nreturn record }\n}\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$TMP_DIR/Production.swift" "$ROOT_DIR/Tests/Chat/FileNameContractChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
