#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
# 独立编译真实请求等待器，验证SDK重回调和退出取消。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-waiter.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
swiftc "$localization_source" -parse-as-library "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/ChatFailureReason.swift" "$QA_ROOT/ddlNew/Network/IM/Contacts/ContactBusinessRequestWaiter.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" "$QA_ROOT/Tests/MigrationAcceptance/WaiterChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
