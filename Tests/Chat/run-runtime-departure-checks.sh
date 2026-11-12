#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc "$localization_source" -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatSettingsStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatRuntime.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/TaskRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/TaskRepository.swift" \
 "$ROOT_DIR/ddlNew/Features/Tasks/PersonalTaskStore.swift" \
 "$ROOT_DIR/Tests/Chat/RuntimeDepartureChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
