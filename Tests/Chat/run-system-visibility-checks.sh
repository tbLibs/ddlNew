#!/bin/sh
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc "$localization_source" -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatSystemEventVisibility.swift" \
 "$ROOT_DIR/Tests/Chat/SystemVisibilityChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
