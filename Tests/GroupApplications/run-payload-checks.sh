#!/bin/bash
# 编译生产群申请映射与状态层，验证混合字段、整页校验和未读保护。
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-group-applications-checks.XXXXXX)"
trap 'if [[ "$task_output" == /tmp/ddlNew-group-applications-checks.* ]]; then rm -r -- "$task_output"; fi' EXIT
# 复用 Xcode 已检出的 ObjectMapper 源码，测试无需网络和 iOS 二进制依赖。
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
swiftc -swift-version 5 -parse-as-library -I "$task_output" -L "$task_output" -lObjectMapper \
  "$task_root/ddlNew/Features/GroupApplications/Models/"*.swift \
  "$task_root/ddlNew/Features/GroupApplications/Services/"*.swift \
  "$task_root/ddlNew/Network/IM/GroupApplications/GroupApplicationPayload.swift" \
  "$task_root/ddlNew/Network/IM/GroupApplications/GroupApplicationsPayload.swift" \
  "$task_root/Tests/GroupApplications/PayloadChecks.swift" -o "$task_output/checks"
DYLD_LIBRARY_PATH="$task_output${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$task_output/checks"
