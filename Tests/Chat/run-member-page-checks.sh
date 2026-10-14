#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 成员分页解析复用生产模型，匿名场景不访问服务端或SDK数据库。
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/Tests/Chat/GroupMemberPageChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
