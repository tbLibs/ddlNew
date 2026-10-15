#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Conversations/SDKConversationOperations.swift').read_text()
(tmp/'Production.swift').write_text(s.replace('import NoaChatCore\n',''))
stubs=(root/'Tests/Chat/RuntimeDepartureChecks.swift').read_text()
(tmp/'Dependencies.swift').write_text(stubs[:stubs.index('@main struct RuntimeDepartureChecks')])
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationAction.swift" \
 "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationActionPolicy.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatSettingsStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatRuntime.swift" \
 "$ROOT_DIR/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" \
 "$TMP_DIR/Dependencies.swift" "$TMP_DIR/Production.swift" "$ROOT_DIR/Tests/Chat/ReadCountOperationChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
