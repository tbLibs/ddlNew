#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
    "$ROOT_DIR/Tests/Conversations/main.swift" -o "$TMP_DIR/conversation-checks"
"$TMP_DIR/conversation-checks"
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationsStore.swift" \
    "$ROOT_DIR/Tests/Conversations/StoreChecks.swift" -o "$TMP_DIR/store-checks"
"$TMP_DIR/store-checks"
