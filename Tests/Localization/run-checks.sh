#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-localization.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library \
 "$repo_root/ddlNew/Common/Localization/L10n.swift" \
 "$repo_root/Tests/Localization/LocalizationChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
