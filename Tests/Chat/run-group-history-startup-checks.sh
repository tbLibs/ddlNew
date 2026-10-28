#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
def method(marker):
    start = s.index(marker); a = s.index('{', start); b = a + 1; depth = 1
    while depth:
        depth += (s[b] == '{') - (s[b] == '}'); b += 1
    return s[start:b]
fixture = (root/'Tests/Chat/GroupHistoryStartupChecks.swift').read_text()
fixture = fixture.replace('// PRODUCTION_METHODS', method('    private func startGroupPermissionRefresh(') + '\n' + method('    func stop(') + '\n' + method('    func refreshPermissions('))
(out/'Checks.swift').write_text(fixture)
PY
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Models/"*.swift "$TASK_TMP/Checks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
