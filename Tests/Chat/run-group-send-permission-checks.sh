#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-group-send-permission.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
# 运行SDK实际群发送判断；仅SDK群表使用匿名形状，消息间隔读取真实本地策略。
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import sys
root, target = map(Path, sys.argv[1:])
source = (root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
method = source.index('    func permissions(')
start = source.index('        if context.route.kind == .group {', method)
cursor = source.index('{', start)+1; depth=1
while depth:
    depth += (source[cursor]=='{')-(source[cursor]=='}'); cursor+=1
body = source[start:cursor]
code = '''import Foundation
struct LingIMGroupModel {
    var groupStatus = 1
    var leaveGroupStatus = 0
    var userGroupRole = 0
    var isPrivateChat = false
    var isGroupChat = false
}
struct GroupSDKShape {
    let group: LingIMGroupModel?
    func toolCheckMyGroup(with: String) -> LingIMGroupModel? { group }
}
func productionGroupPermission(group: LingIMGroupModel?, detail: [String: Any]?, mute: [String: Any]?) -> ChatPermission {
    let context = ChatContext(userUID: "anonymous", tenantID: "test", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "", avatarURL: ""))
    let sdk = GroupSDKShape(group: group)
    let groupDetail = detail, groupMute = mute
    var value = ChatPermission()
BODY
    return value
}
'''.replace('BODY',body)
(target/'ProductionGroupPermission.swift').write_text(code)
PY
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Configuration/LocalMessagingSettings.swift" "$TASK_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Models/"*.swift "$TASK_TMP/ProductionGroupPermission.swift" \
 "$TASK_ROOT/Tests/Chat/GroupSendPermissionChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
