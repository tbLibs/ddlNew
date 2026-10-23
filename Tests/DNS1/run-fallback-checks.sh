#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$root/ddlNew/Network/DNS/DNSHostSource.swift" \
 "$root/ddlNew/Network/OSS/OSSRaceDeadline.swift" \
 "$root/ddlNew/Network/OSS/OSSNodeRaceCoordinator.swift" \
 "$root/Tests/DNS1/DNS1FallbackChecks.swift" -o "$tmp/checks"
"$tmp/checks"
