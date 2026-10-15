#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-profile-navigation.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import re, sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
marker = '    private func openChatFromProfile('
if marker in s:
    start=s.index(marker); end=s.index('{', start)+1; depth=1
    while depth:
        depth+=(s[end]=='{')-(s[end]=='}'); end+=1
    method=s[start:end].replace('private ', '')
else:
    # 旧资料页NavigationLink(value: ChatRoute)的边界动作是追加外层实际路径。
    profile=(root/'ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift').read_text()
    assert 'NavigationLink(value: ChatRoute(' in profile
    method='func openChatFromProfile(_ target: ChatRoute) { navigation.open(target) }'
enum_file=root/'ddlNew/Features/Chat/Components/ChatDetailDestination.swift'
if enum_file.exists(): enum_source=enum_file.read_text()
else: enum_source='enum ChatDetailDestination: Equatable { case settings, profile(ContactsRoute), chat(ChatRoute) }'
profile=(root/'ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift').read_text()
start=profile.index('    private func sendMessage('); end=profile.index('{', start)+1; depth=1
while depth:
    depth+=(profile[end]=='{')-(profile[end]=='}'); end+=1
send_method=profile[start:end].replace('private ', '')
returned=re.search(r'set: \{ (if !\$0 \{ requestedChat = nil \}) \}', profile).group(1).replace('$0', 'isPresented')
(out/'Production.swift').write_text('''import SwiftUI
ENUM
@MainActor final class ProductionProfileNavigation {
    let route: ChatRoute
    let navigation = ActivityNavigation()
    var detailDestination: ChatDetailDestination?
    var conversationClosed = false
    init(route: ChatRoute) { self.route = route; navigation.open(route) }
METHOD
}
@MainActor final class ProductionContactChat {
    var sourceGroupID: String? = "group"
    var contactChatNavigation: ContactChatNavigationAction?
    var requestedChat: ChatRoute?
SEND_METHOD
    func destinationVisibilityChanged(_ isPresented: Bool) { RETURNED }
}
'''.replace('RETURNED',returned).replace('ENUM',enum_source).replace('SEND_METHOD',send_method).replace('METHOD',method))
PY
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Features/Home/Navigation/ActivityNavigation.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Components/ContactChatNavigationAction.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Models/ChatRoute.swift" \
 "$TASK_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactsRoute.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Models/ContactSection.swift" \
 "$TASK_ROOT/ddlNew/Features/Contacts/Services/ContactSorter.swift" \
 "$TASK_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" \
 "$TASK_TMP/Production.swift" "$TASK_ROOT/Tests/Chat/ProfileNavigationChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
