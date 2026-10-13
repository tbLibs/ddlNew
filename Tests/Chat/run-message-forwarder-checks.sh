#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Network/IM/Chat/SDKChatMessageForwarder.swift" "$ROOT_DIR/Tests/Chat/MessageForwarderChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
