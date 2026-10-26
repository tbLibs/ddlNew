#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddlNew-privacy-wire.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
sdk_pb="$repo_root/NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/MessagePbobjc"
xcrun clang -fno-objc-arc -Wno-deprecated-declarations -framework Foundation \
  -I "$repo_root/Pods/Protobuf/objectivec" -I "$sdk_pb" \
  "$repo_root"/Pods/Protobuf/objectivec/*.m "$sdk_pb/LingImmessage.pbobjc.m" \
  "$repo_root/Tests/AppReview/SDKAuthPrivacyChecks.m" -o "$test_dir/auth-checks"
"$test_dir/auth-checks"
