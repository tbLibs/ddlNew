#!/bin/sh
# 独立验证生产申请与搜索Store，全部账号和群标识匿名。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-applications.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
swiftc -parse-as-library "$QA_ROOT/ddlNew/Features/GroupApplications/Models/"*.swift "$QA_ROOT/ddlNew/Features/GroupApplications/Services/"*.swift "$QA_ROOT/ddlNew/Features/Search/Models/"*.swift "$QA_ROOT/ddlNew/Features/Search/Services/"*.swift "$QA_ROOT/Tests/MigrationAcceptance/ApplicationsSearchChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
