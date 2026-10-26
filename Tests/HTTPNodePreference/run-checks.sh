#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-http-preference.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$repo_root/ddlNew/Network/IM/IMHTTPNodePreferenceEngine.swift" \
 "$repo_root/ddlNew/Network/IM/IMHTTPNodePreferenceProbe.swift" \
 "$repo_root/Tests/HTTPNodePreference/HTTPNodePreferenceChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
