#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc "$localization_source" -parse-as-library \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatMessageRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatFailureReason.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatMentionSegment.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatMessageMerge.swift" \
 "$ROOT_DIR/Tests/Chat/RecallCacheChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
