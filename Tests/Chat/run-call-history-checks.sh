#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d /tmp/ddlNew-call-history.XXXXXX)
trap 'rm -rf "$task_temp"' EXIT
xcrun swiftc "$localization_source" -parse-as-library "$task_root/ddlNew/Features/Chat/Models/ChatCallSummary.swift" "$task_root/Tests/Chat/CallHistoryChecks.swift" -o "$task_temp/checks"
"$task_temp/checks"
