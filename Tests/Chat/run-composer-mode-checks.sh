#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 运行真实输入模式状态机，不启动设备、网络或录音权限。
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatComposerMode.swift" "$ROOT_DIR/Tests/Chat/ComposerModeChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
