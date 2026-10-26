#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-login-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

xcrun swiftc -swift-version 5 -parse-as-library \
  "$repo_root/ddlNew/Configuration/LocalAccountPolicy.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginContext.swift" \
  "$repo_root/ddlNew/Features/Login/Models/LoginVerification.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginError.swift" \
  "$repo_root/ddlNew/Features/Login/Models/LoginSecurityNotice.swift" \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginPhase.swift" \
  "$repo_root/ddlNew/Features/Login/Services/AccountLoginServicing.swift" \
  "$repo_root/ddlNew/Features/Login/Services/AccountLoginService.swift" \
  "$repo_root/ddlNew/Network/IM/SDK/AccountLoginSDKDriving.swift" \
  "$repo_root/Tests/Login/AccountLoginPrecheckChecks.swift" \
  -o "$test_dir/checks"
"$test_dir/checks"
