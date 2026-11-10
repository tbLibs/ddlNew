#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
MODEL_FILES="$ROOT_DIR/ddlNew/Features/Message/Models"
swiftc "$localization_source" "$MODEL_FILES"/*.swift \
    "$ROOT_DIR/Tests/Conversations/main.swift" -o "$TMP_DIR/conversation-checks"
"$TMP_DIR/conversation-checks"
swiftc "$localization_source" -parse-as-library "$MODEL_FILES"/*.swift \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationOperationsClient.swift" \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationsStore.swift" \
    "$ROOT_DIR/Tests/Conversations/StoreChecks.swift" -o "$TMP_DIR/store-checks"
"$TMP_DIR/store-checks"
swiftc "$localization_source" -parse-as-library "$MODEL_FILES"/*.swift \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationOperationsClient.swift" \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationsStore.swift" \
    "$ROOT_DIR/Tests/Conversations/OperationChecks.swift" -o "$TMP_DIR/operation-checks"
"$TMP_DIR/operation-checks"
swiftc "$localization_source" -parse-as-library "$MODEL_FILES"/*.swift \
    "$ROOT_DIR/ddlNew/Features/Message/Services/ConversationOperationsClient.swift" \
    "$ROOT_DIR/Tests/Conversations/PreviewChecks.swift" -o "$TMP_DIR/preview-checks"
"$TMP_DIR/preview-checks"
