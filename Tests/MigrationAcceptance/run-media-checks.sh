#!/bin/sh
# 验证原媒体Store取消和重复，不实际读取附件或请求上传。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-media.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
swiftc -parse-as-library "$QA_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/"*.swift "$QA_ROOT/ddlNew/Features/Chat/Media/ChatMediaStore.swift" "$QA_ROOT/Tests/MigrationAcceptance/MediaAdversarialChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
