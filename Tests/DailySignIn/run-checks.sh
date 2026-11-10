#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-daily-sign-in.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
swiftc -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Common/Localization/L10n.swift" \
 "$task_root/ddlNew/Features/DailySignIn/DailySignInModels.swift" \
 "$task_root/ddlNew/Features/DailySignIn/DailySignInStore.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatContext.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatRoute.swift" \
 "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/Tests/DailySignIn/Checks.swift" -o "$task_output/checks"
"$task_output/checks"
# 编译生产适配器，只替换NoaChatCore网络／数据库边界。
sed '/^import NoaChatCore$/d' "$task_root/ddlNew/Network/IM/DailySignIn/SDKDailySignInClient.swift" > "$task_output/SDKClient.swift"
swiftc -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Common/Localization/L10n.swift" \
 "$task_root/ddlNew/Features/DailySignIn/DailySignInModels.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatContext.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatRoute.swift" \
 "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" \
 "$task_output/SDKClient.swift" "$task_root/Tests/DailySignIn/SDKChecks.swift" -o "$task_output/sdk-checks"
"$task_output/sdk-checks"
