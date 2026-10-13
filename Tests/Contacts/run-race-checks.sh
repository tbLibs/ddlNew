#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/ddlNew-contact-business-checks.XXXXXX)"
trap 'rm -rf "$out"' EXIT
rg '^let contactsApplicationStateKey ' "$root/ddlNew/Configuration/Const.swift" > "$out/Constants.swift"
swiftc -swift-version 5 "$out/Constants.swift" "$root/ddlNew/Network/Core/RemoteAvatarURL.swift" "$root/ddlNew/Features/Contacts/Models/ContactRecord.swift" "$root/ddlNew/Features/Contacts/Models/ContactSection.swift" "$root/ddlNew/Features/Contacts/Services/ContactSorter.swift" "$root/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" "$root/ddlNew/Features/Contacts/Models/FriendApplicationRecord.swift" "$root/ddlNew/Features/Contacts/Models/FriendBusinessGroup.swift" "$root/ddlNew/Features/Contacts/Models/ContactBusinessOperation.swift" "$root/ddlNew/Features/Contacts/Models/ContactBusinessResponse.swift" "$root/ddlNew/Features/Contacts/Services/ContactBusinessClient.swift" "$root/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" "$root/ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift" "$root/Tests/Contacts/ContactsRaceChecks.swift" -o "$out/checks"
if [[ $# -gt 0 ]]; then
  "$out/checks" "$1"
else
  for scenario in reload pagination unread friend search groupNickname; do
    "$out/checks" "$scenario"
  done
fi
