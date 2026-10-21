#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
sed '/@main struct ChatChecks/,$d' "$ROOT_DIR/Tests/Chat/StoreChecks.swift" > "$TMP_DIR/client.swift"
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Media/ChatMediaStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" "$TMP_DIR/client.swift" \
 "$ROOT_DIR/Tests/Chat/MediaChecks.swift" -o "$TMP_DIR/media-checks"
"$TMP_DIR/media-checks"
