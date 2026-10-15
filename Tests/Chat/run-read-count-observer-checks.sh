#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatUnreadObserver.swift').read_text()
start=s.index('nonisolated private final class SDKChatUnreadDelegate')
(tmp/'Production.swift').write_text('import Foundation\nimport ObjectiveC\n'+s[start:].replace('private final class SDKChatUnreadDelegate','final class ProductionUnreadDelegate'))
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$TMP_DIR/Production.swift" "$ROOT_DIR/Tests/Chat/ReadCountObserverChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
