#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-connection-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$localization_source" -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$repo_root/ddlNew/Configuration/LocalSDKSettings.swift" \
 "$repo_root/ddlNew/Network/IM/IMConnectionCoordinator.swift" \
 "$repo_root/ddlNew/Network/IM/IMSDKConnectionDriving.swift" \
 "$repo_root/ddlNew/Network/IM/IMConnectionPhase.swift" \
 "$repo_root/ddlNew/Network/IM/IMConnectionError.swift" \
 "$repo_root/Tests/Connection/ConnectionReadinessChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
