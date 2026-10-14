#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatGroupDetail.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatGroupBanRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatGroupMember.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatGroupAction.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatGroupRemovalSelection.swift" \
 "$ROOT_DIR/Tests/Chat/GroupChecks.swift" -o "$TMP_DIR/group-checks"
"$TMP_DIR/group-checks"
