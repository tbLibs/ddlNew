#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
swiftc "$localization_source" -parse-as-library "$task_root"/ddlNew/Features/Search/Models/*.swift \
 "$task_root"/ddlNew/Features/Search/Services/*.swift \
 "$task_root/Tests/Search/SearchChecks.swift" -o "$task_temp/search-checks"
"$task_temp/search-checks"
