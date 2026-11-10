#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
cd "$(dirname "$0")/../.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
sed '/^import WebKit$/d' ddlNew/Features/MiniApps/Browser/MiniAppsFeature.swift > "$out/Feature.swift"
swiftc "$localization_source" -swift-version 5 ddlNew/Features/MiniApps/Models/*.swift ddlNew/Features/MiniApps/Services/*.swift ddlNew/Features/MiniApps/Browser/MiniAppWebPolicy.swift "$out/Feature.swift" Tests/MiniApps/FeatureChecks.swift -o "$out/checks"
"$out/checks"
