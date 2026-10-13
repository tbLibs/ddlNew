#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/ddlNew-group-checks.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc -swift-version 5 "$root/ddlNew/Network/Core/RemoteAvatarURL.swift" "$root/ddlNew/Features/Contacts/Models/ContactRecord.swift" "$root/ddlNew/Features/Contacts/Models/ContactSection.swift" "$root/ddlNew/Features/Contacts/Services/ContactSorter.swift" "$root/ddlNew/Features/Groups/Models/GroupRole.swift" "$root/ddlNew/Features/Groups/Models/GroupRecord.swift" "$root/ddlNew/Features/Groups/Models/GroupMemberSelection.swift" "$root/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" "$root/ddlNew/Features/Groups/Services/GroupsClient.swift" "$root/ddlNew/Features/Groups/Services/GroupsStore.swift" "$root/ddlNew/Features/Groups/Services/GroupCreationError.swift" "$root/Tests/Groups/GroupsChecks.swift" -o "$out/checks"
"$out/checks"
