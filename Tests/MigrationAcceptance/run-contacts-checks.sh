#!/bin/sh
# 编译原业务Store及独立验收，不使用SDK和真实测试凭据。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-contacts.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
# 只抽取业务偏好key，不编译或输出认证网络常量。
sed -n '/^let contactsApplicationStateKey = /p' "$QA_ROOT/ddlNew/Configuration/Const.swift" > "$QA_TEMP/BusinessConstants.swift"
swiftc -swift-version 5 "$QA_TEMP/BusinessConstants.swift" "$QA_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactRecord.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactSection.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactSorter.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/FriendApplicationRecord.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/FriendBusinessGroup.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactBusinessOperation.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactBusinessResponse.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactBusinessClient.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift" "$QA_ROOT/Tests/MigrationAcceptance/ContactsAdversarialChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
