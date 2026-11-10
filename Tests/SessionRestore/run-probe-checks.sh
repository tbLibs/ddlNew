#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$(mktemp -d /tmp/ddlNew-probe.XXXXXX)"
trap 'rm -rf "$dir"' EXIT
xcrun swiftc "$localization_source" -swift-version 5 -parse-as-library "$root/ddlNew/Network/IM/MessageConnectivityProbe.swift" "$root/Tests/SessionRestore/MessageProbeChecks.swift" -o "$dir/checks"
"$dir/checks"
