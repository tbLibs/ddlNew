#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-session-restore.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library \
  "$repo_root/ddlNew/Features/Login/Models/AccountLoginPhase.swift" \
  "$repo_root/ddlNew/Features/Login/Services/LoginSessionServicing.swift" \
  "$repo_root/ddlNew/Features/Login/Services/LoginSessionService.swift" \
  "$repo_root/ddlNew/Common/User/UserSessionError.swift" \
  "$repo_root/ddlNew/Features/Login/Models/LoginSecurityNotice.swift" \
  "$repo_root/ddlNew/App/Startup/AppStartupCoordinator.swift" \
  "$repo_root/Tests/SessionRestore/SessionRestoreChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
