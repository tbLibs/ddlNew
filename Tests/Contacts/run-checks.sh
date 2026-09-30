#!/bin/bash
# 编译生产通讯录模型和状态层，使用离线客户端验证账号隔离与列表规则。
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-contacts-checks.XXXXXX)"
trap 'if [[ "$task_output" == /tmp/ddlNew-contacts-checks.* ]]; then rm -r -- "$task_output"; fi' EXIT
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
swiftc -swift-version 6 \
  -I "$task_output" -L "$task_output" -lObjectMapper \
  "$task_root/ddlNew/Features/Contacts/Models/ContactRecord.swift" \
  "$task_root/ddlNew/Features/Contacts/Models/ContactSection.swift" \
  "$task_root/ddlNew/Features/Contacts/Services/ContactSorter.swift" \
  "$task_root/ddlNew/Features/Contacts/Services/ContactsChange.swift" \
  "$task_root/ddlNew/Features/Contacts/Services/ContactsClient.swift" \
  "$task_root/ddlNew/Features/Contacts/Services/ContactsStore.swift" \
  "$task_root/ddlNew/Features/Contacts/Services/ContactRequestVersions.swift" \
  "$task_root/ddlNew/Network/IM/Contacts/ContactProfilePayload.swift" \
  "$task_root/Tests/Contacts/MockContactsClient.swift" \
  "$task_root/Tests/Contacts/ContactsIntegrationChecks.swift" \
  -o "$task_output/ContactsChecks"
DYLD_LIBRARY_PATH="$task_output" "$task_output/ContactsChecks"
xcrun clang -fobjc-arc -framework Foundation \
  "$task_root/Tests/Contacts/SDKContactsSyncChecks.m" -o "$task_output/SDKContactsChecks"
"$task_output/SDKContactsChecks"
