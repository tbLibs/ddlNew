#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$(mktemp -d /tmp/ddlNew-recovery.XXXXXX)"
trap 'rm -rf "$dir"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library "$root/ddlNew/Features/Message/Services/MessageSessionRecovery.swift" "$root/Tests/SessionRestore/MessageRecoveryChecks.swift" -o "$dir/checks"
"$dir/checks"
