#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
python3 "$ROOT/Tests/Tasks/check-localization.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for OPT in -Onone -O; do
    xcrun swiftc "$OPT" -swift-version 5 -default-isolation MainActor -parse-as-library \
      "$ROOT/ddlNew/Common/Localization/L10n.swift" \
      "$ROOT/ddlNew/Features/Tasks/TaskRecord.swift" \
      "$ROOT/ddlNew/Features/Tasks/TaskRepository.swift" \
      "$ROOT/ddlNew/Features/Tasks/PersonalTaskStore.swift" \
      "$ROOT/Tests/Tasks/Checks.swift" -o "$TMP/checks"
    "$TMP/checks"
done
