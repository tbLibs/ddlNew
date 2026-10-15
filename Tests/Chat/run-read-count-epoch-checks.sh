#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
if [ "${1:-}" = "--legacy" ]; then
 swiftc -DREAD_LEGACY_BASELINE -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$ROOT_DIR/Tests/Chat/ReadCountEpochChecks.swift" -o "$TMP_DIR/checks"
else
 swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$ROOT_DIR/Tests/Chat/ReadCountEpochChecks.swift" -o "$TMP_DIR/checks"
fi
"$TMP_DIR/checks"
