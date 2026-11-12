#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'Tests/Chat/RuntimeDepartureChecks.swift').read_text()
(tmp/'Dependencies.swift').write_text(s[:s.index('@main struct RuntimeDepartureChecks')])
PY
swiftc "$localization_source" -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatSettingsStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatRuntime.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/TaskRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/TaskRepository.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/PersonalTaskStore.swift" \
 "$TMP_DIR/Dependencies.swift" "$ROOT_DIR/Tests/Chat/ReadCountRuntimeChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
