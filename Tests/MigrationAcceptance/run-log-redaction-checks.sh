#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TASK_TMP_DIR"' EXIT
# 原样提取生产日志调用与HTTP日志方法；仅替代SDK数据形状和输出端，不连接后端。
python3 "$ROOT_DIR/Tests/MigrationAcceptance/LogRedactionChecks.py" "$ROOT_DIR" "$TASK_TMP_DIR"
clang -fobjc-arc -fblocks -framework Foundation -Wall -Werror \
  -Wno-unused-variable "$TASK_TMP_DIR/LogRedactionChecks.m" -o "$TASK_TMP_DIR/checks"
"$TASK_TMP_DIR/checks"
