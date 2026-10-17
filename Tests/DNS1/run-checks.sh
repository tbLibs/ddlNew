#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$root/ddlNew/Network/DNS1/DNS1Payload.swift" \
 "$root/ddlNew/Network/DNS1/DNS1SourceRace.swift" \
 "$root/ddlNew/Network/DNS1/DNS1CallbackWaiter.swift" \
 "$root/Tests/DNS1/DNS1Checks.swift" -o "$tmp/checks"
"$tmp/checks"
