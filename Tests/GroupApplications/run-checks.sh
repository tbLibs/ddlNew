#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
swiftc "$localization_source" -parse-as-library "$task_root"/ddlNew/Features/GroupApplications/Models/*.swift \
 "$task_root"/ddlNew/Features/GroupApplications/Services/*.swift \
 "$task_root/Tests/GroupApplications/StoreChecks.swift" -o "$task_temp/checks"
"$task_temp/checks"
