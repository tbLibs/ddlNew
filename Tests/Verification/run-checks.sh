#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-verification-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

xcrun swiftc -swift-version 5 -parse-as-library \
  "$repo_root/ddlNew/Features/Login/Models/LoginVerification.swift" \
  "$repo_root/ddlNew/Features/Login/Services/LoginVerificationCoordinator.swift" \
  "$repo_root/Tests/Verification/LoginVerificationChecks.swift" \
  -o "$test_dir/checks"
"$test_dir/checks"
