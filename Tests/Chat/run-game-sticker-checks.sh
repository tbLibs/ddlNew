#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-game-sticker.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
# SDK真实编码分支与接收映射使用匿名消息形状运行，防止只画图却漏发type/result。
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PYWIRE'
from pathlib import Path
import sys
root,target=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
start=s.index('    func makeModel(')
end=s.index('        return model',start)
method=s[start:end]
needle='        if message.type == 21 {'
body=''
if needle in method:
 begin=method.index(needle); cursor=method.index('{',begin)+1; depth=1
 while depth:
  depth += (method[cursor]=='{')-(method[cursor]=='}'); cursor+=1
 body=method[begin:cursor]
mapper=(root/'ddlNew/Network/IM/Chat/SDKChatMessageMapper.swift').read_text()
branch=next(line for line in mapper.splitlines() if 'case 21: record.text' in line)
code='''import Foundation
struct GameWireModel {
    var gameSticekersType: Int32 = 0
    var gameStickersResut: String?
    var gameStickersExt: String?
    var isGameAnimationed = false
}
func productionGameEncode(_ message: ChatMessageRecord) -> GameWireModel {
    var model = GameWireModel()
BODY
    return model
}
func productionGameDecode(_ model: GameWireModel) -> ChatMessageRecord {
    var record = ChatMessageRecord(localID: "m", conversationID: "g", senderID: "u", senderName: "", type: 21, timestamp: 1)
    switch 21 {
BRANCH
    default: break
    }
    return record
}
'''.replace('BODY',body).replace('BRANCH',branch)
(target/'ProductionGameWire.swift').write_text(code)
PYWIRE
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$TASK_ROOT/ddlNew/Features/Chat/Models/"*.swift "$TASK_ROOT/Tests/Chat/GameStickerChecks.swift" "$TASK_TMP/ProductionGameWire.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
