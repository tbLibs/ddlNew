#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-login-security.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
task_mapper_sources="${CONTACTS_OBJECTMAPPER_SOURCES:-}"
if [[ -z "$task_mapper_sources" ]]; then
  task_mapper_revision="$(/usr/bin/ruby -rjson -e 'pin = JSON.parse(File.read(ARGV[0])).fetch("pins").find { |item| item["identity"] == "objectmapper" }; puts pin.fetch("state").fetch("revision")' "$repo_root/ddlNew.xcworkspace/xcshareddata/swiftpm/Package.resolved")"
  for task_candidate in "$HOME"/Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/ObjectMapper/Sources; do
    if [[ -d "$task_candidate" ]] && [[ "$(git -C "$task_candidate/.." rev-parse HEAD)" == "$task_mapper_revision" ]]; then task_mapper_sources="$task_candidate"; break; fi
  done
fi
if [[ ! -f "$task_mapper_sources/Mappable.swift" ]]; then echo "未找到已锁定 ObjectMapper；请设置 CONTACTS_OBJECTMAPPER_SOURCES。" >&2; exit 1; fi
xcrun swiftc -swift-version 5 -emit-library -emit-module -module-name ObjectMapper "$task_mapper_sources"/*.swift -o "$test_dir/libObjectMapper.dylib" -emit-module-path "$test_dir/ObjectMapper.swiftmodule"
xcrun swiftc -swift-version 5 -parse-as-library \
  -I "$test_dir" -L "$test_dir" -lObjectMapper \
  "$repo_root/ddlNew/Features/Login/Models/LoginSecurityNotice.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginError.swift" \
  "$repo_root/ddlNew/Common/User/UserSessionError.swift" \
  "$repo_root/ddlNew/Features/Login/Models/PasswordSecurityStatus.swift" \
  "$repo_root/ddlNew/Features/Login/Models/PasswordSecurityRequirement.swift" \
  "$repo_root/ddlNew/Features/Login/Services/PasswordSecurityRequirementStore.swift" \
  "$repo_root/ddlNew/Features/Login/Models/PasswordChangeInput.swift" \
  "$repo_root/ddlNew/Features/Login/Services/PasswordSecurityService.swift" \
  "$repo_root/ddlNew/Features/Login/Services/LoginSecurityCoordinator.swift" \
  "$repo_root/Tests/LoginSecurity/LoginSecurityChecks.swift" -o "$test_dir/checks"
DYLD_LIBRARY_PATH="$test_dir" "$test_dir/checks"
