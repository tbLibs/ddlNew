#!/bin/sh
# 编译真实好友行展示身份，复验备注恢复不会沿用旧标签。
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-contact-row.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactSection.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Services/ContactSorter.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactRowPresentationIdentity.swift" \
 "$TASK_ROOT/Tests/Contacts/RowPresentationChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
