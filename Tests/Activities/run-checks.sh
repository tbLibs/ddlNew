#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# The model uses a test translation boundary; the real localization runtime has its own suite.
swiftc -parse-as-library "$repo_root/ddlNew/Features/Activities/Models/ClubActivity.swift" \
 "$repo_root/Tests/Activities/SampleLocalizationChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
