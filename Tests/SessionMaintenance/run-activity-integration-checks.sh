#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_tmp="$(mktemp -d /tmp/ddlNew-activity-integration.XXXXXX)"
trap 'rm -rf "$task_tmp"' EXIT
# 编译完整生产协调器，只替换 NoaChatCore / 会话单例边界；不接触真实账号和数据库。
sed '/^import NoaChatCore$/d' "$task_root/ddlNew/Network/IM/Chat/SDKGroupActivitySyncCoordinator.swift" > "$task_tmp/Coordinator.swift"
xcrun swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Configuration/GroupActivitySyncPolicy.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatGroupMemberPage.swift" \
 "$task_root/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" \
 "$task_tmp/Coordinator.swift" "$task_root/Tests/SessionMaintenance/GroupActivityIntegrationChecks.swift" -o "$task_tmp/checks"
"$task_tmp/checks"
