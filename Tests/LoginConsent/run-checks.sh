#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-login-consent.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$repo_root/ddlNew/Features/Login/Models/AccountIdentity.swift" \
 "$repo_root/ddlNew/Features/Login/Models/AccountLoginPhase.swift" \
 "$repo_root/ddlNew/Features/Login/Services/AccountLoginServicing.swift" \
 "$repo_root/ddlNew/Features/Login/Services/LoginSessionServicing.swift" \
 "$repo_root/ddlNew/Features/Login/ViewModels/LoginViewModel.swift" \
 "$repo_root/Tests/LoginConsent/LoginConsentChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
