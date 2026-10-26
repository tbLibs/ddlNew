#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-account-lifecycle-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library \
  "$repo_root/ddlNew/Configuration/LocalAccountPolicy.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountRegistration.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginError.swift" \
  "$repo_root/ddlNew/Features/Login/Models/LoginSecurityNotice.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginPhase.swift" \
  "$repo_root/ddlNew/Features/Login/Services/LoginSessionServicing.swift" \
  "$repo_root/ddlNew/Features/Login/Services/AccountRegistrationService.swift" \
  "$repo_root/ddlNew/Features/Login/ViewModels/AccountRegistrationViewModel.swift" \
  "$repo_root/ddlNew/Network/IM/SDK/AccountRegistrationSDKDriving.swift" \
  "$repo_root/Tests/AccountLifecycle/AccountRegistrationChecks.swift" \
  -o "$test_dir/checks"
"$test_dir/checks"
