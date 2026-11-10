#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/miniapp-floating.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc "$localization_source" "$root/ddlNew/Features/MiniApps/Models/MiniAppFloatingPosition.swift" "$root/Tests/MiniApps/FloatingPositionChecks.swift" -o "$out/checks"
"$out/checks"
