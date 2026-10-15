#!/bin/sh
# 编译真实可见已读和群权限策略，隔离SDK与认证数据。
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-read-permission.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Models/"*.swift \
 "$TASK_ROOT/Tests/Chat/ReadPermissionChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
