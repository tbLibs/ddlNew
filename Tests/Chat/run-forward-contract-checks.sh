#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" "${1:-}" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:3]); override = sys.argv[3]
s = Path(override).read_text() if override else (root/'ddlNew/Network/IM/Chat/SDKChatActionsClient.swift').read_text()
if '    private func forwardingMessage(' in s:
    start = s.index('    private func forwardingMessage(')
    production = s[start:s.rfind('\n}')].replace('private func forwardingMessage', 'func forwardingMessage')
else:
    production = 'func forwardingMessage(_ original: NoaIMChatMessageModel) -> IMChatMessage { LingIMModelTool.shared().getChatMessageModel(fromLingIMChatMessageModel: original) }'
start = s.index('        for index in ordered.indices {')
end = s.index('        return result', start)
loop = s[start:end]
legacy = 'let target = StubTarget();' if 'target.makeModel' in loop else ''
cache = 'func cache(ordered: [ChatMessageRecord], entries: [IMChatMessage], models: [NoaIMChatMessageModel], ids: [String], serverIDs: [String], recipient: ChatRoute, destination: ChatContext, receiver: ToMessage) -> [ChatMessageRecord] { let sdk = FakeSDK(); let context = destination; '+legacy+' let sentTime: Int64 = 500; var result: [ChatMessageRecord] = []\n'+loop+'\nreturn result }'
(tmp/'production.swift').write_text('import Foundation\nstruct ProductionForwarder {\n'+production+'\n'+cache+'\n}\n')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/Tests/Chat/ForwardContractChecks.swift" "$TMP_DIR/production.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
