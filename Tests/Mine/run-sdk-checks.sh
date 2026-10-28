#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-mine-sdk.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
sed '/^import NoaChatCore$/d' "$task_root/ddlNew/Network/IM/SDKOwnProfileClient.swift" > "$task_output/SDKOwnProfileClient.swift"
swiftc -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Features/Mine/Models/OwnProfileChange.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatContext.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatRoute.swift" \
 "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatAttachment.swift" \
 "$task_root/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" \
 "$task_output/SDKOwnProfileClient.swift" "$task_root/Tests/Mine/SDKOwnProfileChecks.swift" -o "$task_output/checks"
"$task_output/checks"
