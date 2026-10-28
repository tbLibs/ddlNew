#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-mine-checks.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
if [[ ! -f "$task_root/ddlNew/Features/Mine/Services/OwnProfileStore.swift" ]]; then
  echo 'FAIL: 我的页面尚无个人资料提交状态层'; exit 1
fi
swiftc -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Features/Mine/Models/OwnProfileChange.swift" \
 "$task_root/ddlNew/Features/Mine/Services/OwnProfileStore.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatContext.swift" \
 "$task_root/ddlNew/Features/Chat/Models/ChatRoute.swift" \
 "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/Tests/Mine/OwnProfileChecks.swift" -o "$task_output/checks"
"$task_output/checks"
