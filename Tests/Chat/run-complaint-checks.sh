#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
swiftc -parse-as-library "$task_root/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$task_root/ddlNew/Features/Chat/Models/"*.swift \
 "$task_root/ddlNew/Features/Safety/Models/"*.swift \
 "$task_root/ddlNew/Features/Safety/Services/"*.swift \
 "$task_root/ddlNew/Features/Safety/Media/"*.swift \
 "$task_root/Tests/Chat/ComplaintChecks.swift" -o "$task_temp/checks"
"$task_temp/checks"
