#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/ddlNew-code-checks.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$root/ddlNew/Configuration/LocalAccountPolicy.swift" \
 "$root/ddlNew/Features/Login/Models/AccountIdentity.swift" \
 "$root/ddlNew/Features/Login/Models/AccountLoginContext.swift" \
 "$root/ddlNew/Features/Login/Models/AccountLoginError.swift" \
 "$root/ddlNew/Features/Login/Models/LoginSecurityNotice.swift" \
 "$root/ddlNew/Features/Login/Models/LoginVerification.swift" \
 "$root/ddlNew/Features/Login/Services/AccountCodeService.swift" \
 "$root/ddlNew/Features/Login/ViewModels/AccountCodeViewModel.swift" \
 "$root/Tests/Login/AccountCodeChecks.swift" -o "$out/checks"
"$out/checks"
