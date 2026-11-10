#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
# 编译生产Store及独立对抗用例，所有输出只含匿名离线身份。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-chat.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
swiftc "$localization_source" -parse-as-library "$QA_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/"*.swift "$QA_ROOT/ddlNew/Features/Chat/Services/ChatStore.swift" "$QA_ROOT/Tests/MigrationAcceptance/ChatAdversarialChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
