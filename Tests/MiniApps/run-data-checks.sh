#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/miniapp-data.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc "$root/ddlNew/Features/MiniApps/Models/MiniAppRecord.swift" "$root/ddlNew/Features/MiniApps/Browser/MiniAppWebPolicy.swift" "$root/Tests/MiniApps/DataModelChecks.swift" -o "$out/model"
"$out/model"
swiftc -swift-version 5 -parse-as-library "$root/ddlNew/Features/MiniApps/Models/MiniAppRecord.swift" "$root/ddlNew/Features/MiniApps/Browser/MiniAppWebPolicy.swift" "$root/ddlNew/Features/MiniApps/Services/MiniAppClient.swift" "$root/ddlNew/Features/MiniApps/Services/MiniAppsStore.swift" "$root/Tests/MiniApps/StoreChecks.swift" -o "$out/store"
"$out/store"
