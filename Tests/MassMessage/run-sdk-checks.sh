#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
sed '/^import NoaChatCore$/d' "$ROOT_DIR/ddlNew/Network/IM/MassMessage/SDKMassMessageClient.swift" > "$TMP_DIR/SDKMassMessageClient.swift"
swiftc -parse-as-library \
 "$ROOT_DIR/ddlNew/Features/MassMessage/Models/MassMessageRecord.swift" \
 "$ROOT_DIR/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" \
 "$TMP_DIR/SDKMassMessageClient.swift" "$ROOT_DIR/Tests/MassMessage/SDKChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
