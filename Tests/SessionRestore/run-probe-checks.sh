#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$(mktemp -d /tmp/ddlNew-probe.XXXXXX)"
trap 'rm -rf "$dir"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library "$root/ddlNew/Network/IM/MessageConnectivityProbe.swift" "$root/Tests/SessionRestore/MessageProbeChecks.swift" -o "$dir/checks"
"$dir/checks"
