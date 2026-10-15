#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp = map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatActionsClient.swift').read_text()
start=s.index('            let current = SDKChatMessageMapper.record(original')
end=s.index('            models.append(original)',start)
production='import Foundation\nstruct ProductionFreshness { static func check(original: CurrentMessage, context: ChatContext, currentPermission: ChatPermission) throws {\n'+s[start:end]+'\n} }'
(tmp/'production.swift').write_text(production)
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/Tests/Chat/ForwardFreshnessChecks.swift" "$TMP_DIR/production.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
