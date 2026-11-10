#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-localization.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
for table in Localizable InfoPlist; do
 xcrun xcstringstool generate-symbols --language swift --output-directory "$test_dir" "$repo_root/ddlNew/Resources/Localization/$table.xcstrings"
 xcrun xcstringstool compile "$repo_root/ddlNew/Resources/Localization/$table.xcstrings" --output-directory "$test_dir"
done
python3 "$repo_root/Tests/Localization/check_compiled_resources.py" "$test_dir"
xcrun swiftc -swift-version 5 -parse-as-library \
 "$repo_root/ddlNew/Common/Localization/L10n.swift" \
 "$repo_root/Tests/Localization/LocalizationChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
