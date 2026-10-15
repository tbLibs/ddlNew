#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
sed -n '/^let contactsApplicationStateKey = /p' "$task_root/ddlNew/Configuration/Const.swift" > "$task_temp/Constants.swift"
swiftc -swift-version 5 "$task_temp/Constants.swift" "$task_root/ddlNew/Network/Core/RemoteAvatarURL.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/ContactRecord.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/ContactSection.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/FriendApplicationRecord.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/FriendBusinessGroup.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/ContactBusinessOperation.swift" \
 "$task_root/ddlNew/Features/Contacts/Models/ContactBusinessResponse.swift" \
 "$task_root/ddlNew/Features/Contacts/Services/ContactSorter.swift" \
 "$task_root/ddlNew/Features/Contacts/Services/ContactBusinessClient.swift" \
 "$task_root/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" \
 "$task_root/ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift" \
 "$task_root/Tests/Contacts/BlacklistChecks.swift" -o "$task_temp/checks"
"$task_temp/checks"
