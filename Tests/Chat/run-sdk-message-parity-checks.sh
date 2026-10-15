#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" "${1:-}" <<'PY'
from pathlib import Path
import re, sys
root,tmp = map(Path, sys.argv[1:3]); override=sys.argv[3]
s = Path(override).read_text() if override else (root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
if '    nonisolated static func systemSummary' in s:
    start=s.index('    nonisolated static func systemSummary')
    summary=s[start:s.index('    /// 历史和置顶原文',start)].replace('NoaChatCore.UserInfo', 'UserInfo')
else:
    summary='static func systemSummary(_ server: IMServerMessage, userUID: String) -> String { "" }'
branches=[]
for line in s.splitlines():
    if re.match(r'\s*case (1|2|3, 7|12): record',line): branches.append(line)
production='import Foundation\nstruct ProductionMapper {\n'+summary+'\nstatic func media(_ model: MediaModel, type: Int) -> ChatMessageRecord { var record = ChatMessageRecord(localID: "m", conversationID: "g", senderID: "B", senderName: "B", type: type, timestamp: 1)\nswitch type {\n'+'\n'.join(branches)+'\ndefault: break\n}\nreturn record }\n}'
delegate=(root/'ddlNew/Network/IM/Chat/SDKChatDelegate.swift').read_text()
start=delegate.index('    private func publish(')
publish=delegate[start:delegate.rfind('\n}')].replace('private func publish', 'func publish')
production += '\nstruct ProductionDelegate { let userUID: String; let conversationID: String; let changed: (ChatEvent) -> Void\n'+publish+'\n}\n'
(tmp/'production.swift').write_text(production)
# 夹具按生产Proto取值边界建模；生成字段集合只为编译真实方法，不复写摘要算法。
fields=sorted(set(re.findall(r'server\.([a-zA-Z]+Message|delGroupNotice|groupMessageTop|dialogUserMessageTop)\b',(root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()+delegate)))
(tmp/'server.swift').write_text('import Foundation\nstruct ServerKind { let rawValue: Int }\nfinal class IMServerMessage { var sMsgType = ServerKind(rawValue: 0)\n'+''.join('var '+name+': Body! = Body()\n' for name in fields)+'}\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/Tests/Chat/SDKMessageParityChecks.swift" "$TMP_DIR/production.swift" "$TMP_DIR/server.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
