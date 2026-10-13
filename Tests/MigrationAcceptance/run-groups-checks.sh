#!/bin/sh
# 独立编译生产群Store，不触发SDK或真实群创建。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_OUT=$(mktemp -d /tmp/ddlNew-qa-groups.XXXXXX)
trap 'rm -rf "$QA_OUT"' EXIT
swiftc -swift-version 5 "$QA_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactRecord.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactSection.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactSorter.swift" "$QA_ROOT/ddlNew/Features/Groups/Models/GroupRole.swift" "$QA_ROOT/ddlNew/Features/Groups/Models/GroupRecord.swift" "$QA_ROOT/ddlNew/Features/Groups/Models/GroupMemberSelection.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" "$QA_ROOT/ddlNew/Features/Groups/Services/GroupsClient.swift" "$QA_ROOT/ddlNew/Features/Groups/Services/GroupsStore.swift" "$QA_ROOT/ddlNew/Features/Groups/Services/GroupCreationError.swift" "$QA_ROOT/Tests/MigrationAcceptance/GroupsAdversarialChecks.swift" -o "$QA_OUT/checks"
"$QA_OUT/checks"
