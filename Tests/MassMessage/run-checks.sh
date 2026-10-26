#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc -parse-as-library \
 "$ROOT_DIR/ddlNew/Features/MassMessage/Models/MassMessageRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/MassMessage/Services/MassMessageStore.swift" \
 "$ROOT_DIR/ddlNew/Features/MassMessage/Services/MassMessageRecipientsStore.swift" \
 "$ROOT_DIR/ddlNew/Features/MassMessage/Services/MassMessageComposerStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatAttachment.swift" \
 "$ROOT_DIR/Tests/MassMessage/StoreChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
