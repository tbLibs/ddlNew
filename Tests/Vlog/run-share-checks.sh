#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library \
 "$ROOT/ddlNew/Common/Localization/L10n.swift" \
 "$ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT/ddlNew/Features/Chat/Services/ChatMediaShareOperation.swift" \
 "$ROOT/Tests/Vlog/ShareChecks.swift" -o "$TMP/checks"
"$TMP/checks"
