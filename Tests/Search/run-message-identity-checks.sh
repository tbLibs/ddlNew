#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:])
s = (root/'ddlNew/Network/IM/Search/SDKGlobalSearchClient.swift').read_text()
if 'enum GlobalSearchMessageIdentity' in s:
    production = s[s.index('enum GlobalSearchMessageIdentity'):]
else:
    start = s.index('                let type = Int(message.chatType.rawValue)')
    end = s.index('                let messageID', start)
    segment = s[start:end]
    production = 'enum GlobalSearchMessageIdentity { static func peer(status: Int, chatType: Int, from: String, to: String, userUID: String) -> String? { let message = Message(messageStatus: status, chatType: Kind(rawValue: chatType), fromID: from, toID: to); let showAssistant = true; for _ in 0..<1 {\n'+segment+'\nreturn peer }; return nil } }'
(tmp/'production.swift').write_text('import Foundation\nstruct Kind { let rawValue: Int }\nstruct Message { let messageStatus: Int; let chatType: Kind; let fromID: String?; let toID: String? }\n'+production)
PY
swiftc -parse-as-library "$TMP_DIR/production.swift" "$ROOT_DIR/Tests/Search/MessageIdentityChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
