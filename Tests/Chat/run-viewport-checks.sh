#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 实际视口模型的匿名几何测试，不访问真实聊天或系统辅助功能设置。
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatViewportPolicy.swift" "$ROOT_DIR/Tests/Chat/ViewportChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
