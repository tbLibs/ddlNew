#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -eu
cd "$(dirname "$0")/../.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc "$localization_source" ddlNew/Features/MiniApps/Browser/MiniAppWebPolicy.swift Tests/MiniApps/WebPolicyChecks.swift -o "$out/checks"
"$out/checks"
