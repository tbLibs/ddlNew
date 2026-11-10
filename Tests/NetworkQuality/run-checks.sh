#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-quality-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$localization_source" -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$repo_root/ddlNew/Network/DNS/DNSHostSource.swift" \
 "$repo_root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$repo_root/ddlNew/Network/IM/IMNetworkNode.swift" \
 "$repo_root/ddlNew/Network/IM/IMNetworkQualityPolicy.swift" \
 "$repo_root/ddlNew/Network/IM/IMNetworkQualityEngine.swift" \
 "$repo_root/Tests/NetworkQuality/NetworkQualityChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
