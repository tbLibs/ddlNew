#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
license="${1:?Pass a test invitation code for read-only DNS/BIN checks}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
umask 077
rg '^nonisolated let dns1' "$root/ddlNew/Configuration/Const.swift" > "$tmp/Constants.swift"
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
 "$tmp/Constants.swift" \
 "$root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$root/ddlNew/Network/DNS1/DNS1Payload.swift" \
 "$root/ddlNew/Network/DNS1/DNS1DoHClient.swift" \
 "$root/Tests/DNS1/DNS1LiveChecks.swift" -o "$tmp/live-checks"
"$tmp/live-checks" "$license"
