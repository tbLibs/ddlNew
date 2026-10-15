#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import re, sys
root,out=map(Path,sys.argv[1:])
def block(s, marker):
 start=s.index(marker); a=s.index('{',start); b=a+1; depth=1
 while depth:
  depth+=(s[b]=='{')-(s[b]=='}');b+=1
 return s[start:b]
mapper=(root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
a=mapper.index('        let sdk = NoaIMSDKManager.sharedTool()');b=mapper.index('        return record',a)
metadata=mapper[a:b]
s=(root/'ddlNew/Network/IM/Conversations/SDKConversationsClient.swift').read_text()
if 'nonisolated static func displayTitle(' in s:
 title=block(s,'    nonisolated static func displayTitle(')
else:
 expr=re.search(r'id: id, title: (.*),\n',s).group(1)
 title='static func displayTitle(_ model: LingIMSessionModel, id: String, kind: ConversationKind, sdk: NoaIMSDKManager) -> String { '+expr+' }'
a=s.index('        var senderName =');b=s.index('        let mentions =',a)
preview=s[a:b]
delegate=(root/'ddlNew/Network/IM/Chat/SDKChatDelegate.swift').read_text()
marker='    func cimToolUserFriendChange('
changed=block(delegate,marker) if marker in delegate else 'func cimToolUserFriendChange(_ message: LingIMFriendModel) {}'
view=(root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
titleView=block(view,'    private var chatTitle:') if '    private var chatTitle:' in view else 'var chatTitle: String { route.title }'
code='''import Foundation
struct ProductionNames {
 static func metadata(_ input: ChatMessageRecord, userUID: String, group: Bool = false) -> ChatMessageRecord {
 var record = input
 let model = MessageKind(chatType: Kind(rawValue: group ? 1 : 0))
METADATA
 return record
 }
TITLE
 static func previewName(_ message: NoaIMChatMessageModel, kind: ConversationKind, sdk: NoaIMSDKManager) -> String {
PREVIEW
 return senderName
 }
}
struct ProductionNameDelegate {
 let userUID: String
 let conversationID: String
 let isGroup: Bool
 let changed: (ChatEvent) -> Void
CHANGED
}
struct NameRoute { var id = "peer"; var kind = ConversationKind.single; var title = "旧路由名" }
struct NameContact { var id = "peer"; var displayName = "新备注" }
struct NameContacts { var contacts = [NameContact()] }
struct ProductionChatTitle {
 var route = NameRoute()
 var contacts = NameContacts()
VIEW
}
'''.replace('METADATA',metadata).replace('TITLE',title).replace('PREVIEW',preview).replace('CHANGED',changed).replace('VIEW',titleView.replace('private var','var'))
(out/'Production.swift').write_text(code)
# 复用真实SDK边界的匿名形状；业务分支仍执行以上生产源码。
f=(root/'Tests/Chat/AvatarChecks.swift').read_text().split('@main struct AvatarChecks')[0]
f=f.replace('var showName: String? = "好友"','var friendUserUID: String? = "peer"\n    var userName: String? = "account"\n    var showName: String? = "好友"')
f=f.replace('var role = 0','var userUid: String? = "peer"\n    var showName: String?\n    var role = 0')
f=f.replace('func myUserID()', 'func imSdkInsertOrUpdateGroupMember(_ value: LingIMGroupMemberModel, groupID: String) -> Bool { member = value; return true }\n    func myUserID()')
f += '\nfinal class LingIMSessionModel { var sessionName: String? = "旧会话名" }\nfinal class NoaIMChatMessageModel { var fromID: String? = "peer"; var fromNickname: String? = "消息原昵称"; var toID: String? = "group" }\n'
(out/'Boundary.swift').write_text(f)
f=(root/'Tests/Chat/LocationChecks.swift').read_text().split('@main struct LocationChecks')[0]
(out/'Client.swift').write_text(f)
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatStore.swift" \
 "$TMP_DIR/Production.swift" "$TMP_DIR/Boundary.swift" "$TMP_DIR/Client.swift" \
 "$ROOT_DIR/Tests/Chat/ContactNameChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
