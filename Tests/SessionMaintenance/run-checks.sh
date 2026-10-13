#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-maintenance-checks.XXXXXX)"
trap 'rm -r -- "$task_output"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library \
 "$task_root/ddlNew/Network/Session/SessionMaintenanceEngine.swift" \
 "$task_root/Tests/SessionMaintenance/MaintenanceChecks.swift" -o "$task_output/checks"
"$task_output/checks"

task_mapper_sources="${CONTACTS_OBJECTMAPPER_SOURCES:-}"
if [[ -z "$task_mapper_sources" ]]; then
  task_mapper_revision="$(/usr/bin/ruby -rjson -e 'pin = JSON.parse(File.read(ARGV[0])).fetch("pins").find { |item| item["identity"] == "objectmapper" }; puts pin.fetch("state").fetch("revision")' "$task_root/ddlNew.xcworkspace/xcshareddata/swiftpm/Package.resolved")"
  for task_candidate in "$HOME"/Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/ObjectMapper/Sources; do
    if [[ -d "$task_candidate" ]] && [[ "$(git -C "$task_candidate/.." rev-parse HEAD)" == "$task_mapper_revision" ]]; then
      task_mapper_sources="$task_candidate"
      break
    fi
  done
fi
if [[ ! -f "$task_mapper_sources/Mappable.swift" ]]; then
  echo "未找到 ObjectMapper；请先由 Xcode 解析依赖，或设置 CONTACTS_OBJECTMAPPER_SOURCES。" >&2
  exit 1
fi
swiftc -swift-version 5 -emit-library -emit-module -module-name ObjectMapper \
  "$task_mapper_sources"/*.swift -o "$task_output/libObjectMapper.dylib" \
  -emit-module-path "$task_output/ObjectMapper.swiftmodule"
xcrun swiftc -swift-version 6 -parse-as-library -I "$task_output" -L "$task_output" -lObjectMapper \
 "$task_root/ddlNew/Common/User/UserRoleAuthority.swift" \
 "$task_root/ddlNew/Common/User/UserInfo.swift" \
 "$task_root/Tests/SessionMaintenance/RoleProfileChecks.swift" -o "$task_output/role-checks"
DYLD_LIBRARY_PATH="$task_output" "$task_output/role-checks"

xcrun clang -fobjc-arc -framework Foundation "$task_root/Tests/SessionMaintenance/SDKRequestFenceChecks.m" -o "$task_output/sdk-fence-checks"
"$task_output/sdk-fence-checks"
