#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-mine-refresh.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
sed '/^import ObjectMapper$/d' "$task_root/ddlNew/Network/Session/SessionMaintenanceCoordinator.swift" > "$task_output/Coordinator.swift"
swiftc -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Network/Session/SessionMaintenanceEngine.swift" \
 "$task_output/Coordinator.swift" "$task_root/Tests/Mine/ProfileRefreshChecks.swift" -o "$task_output/checks"
"$task_output/checks"
