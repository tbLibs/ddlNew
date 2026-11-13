#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for OPT in -Onone -O; do
 xcrun swiftc "$OPT" -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$ROOT/ddlNew/Features/Vlog/VlogRecord.swift" "$ROOT/ddlNew/Features/Vlog/VlogRepository.swift" \
 "$ROOT/ddlNew/Common/Localization/L10n.swift" "$ROOT/ddlNew/Features/Vlog/VlogStore.swift" "$ROOT/Tests/Vlog/Checks.swift" -o "$TMP/checks"
 "$TMP/checks"
done
