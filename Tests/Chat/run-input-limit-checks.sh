#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc ddlNew/Features/Chat/Models/ChatEmojiCatalog.swift \
  ddlNew/Features/Chat/Models/ChatInputLimit.swift Tests/Chat/InputLimitChecks.swift -o "$tmp/check"
"$tmp/check"
