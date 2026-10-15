#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatEmojiCatalog.swift" "$ROOT_DIR/Tests/Chat/EmojiChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks" "$ROOT_DIR/ddlNew/Resources/ChatEmojiCatalog.plist"
