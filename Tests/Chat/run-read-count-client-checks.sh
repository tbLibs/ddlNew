#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
def method(marker):
 start=s.index(marker); opening=s.index('{',start); depth=1; i=opening+1
 while depth:
  if s[i]=='{': depth+=1
  if s[i]=='}': depth-=1
  i+=1
 return s[start:i]
parts=[method('    func validate('),method('    func read('),method('    private func flushReadTransitions('),method('    private func clearManualReadTag('),method('    func stop(')]
production='''import Foundation
import ObjectiveC
@MainActor final class ProductionReadClient {
 private let sdk: ReadCountSDK
 private var context: ChatContext?
 private let validSession: @MainActor (ChatContext) -> Bool
 private var generation = UUID(); private var groupRefreshRevision = UUID(); private var muteExpiryRevision = UUID()
 private var muteExpiryTask: Task<Void,Never>?; private var muteExpiryState = ChatGroupMuteExpiryState()
 private var waiting: [UUID: () -> Void] = [:]; private var delegate: NSObject?
 private var groupDetail: [String: Any]?; private var groupMute: [String: Any]?; private var eventHandler: ((ChatEvent) -> Void)?
 init(context: ChatContext,sdk: ReadCountSDK,validSession: @escaping @MainActor (ChatContext)->Bool) { self.context=context;self.sdk=sdk;self.validSession=validSession }
'''+ '\n'.join(parts)+'\n}'
(tmp/'Production.swift').write_text(production)
stubs=(root/'Tests/Chat/RuntimeDepartureChecks.swift').read_text()
(tmp/'Dependencies.swift').write_text(stubs[:stubs.index('@main struct RuntimeDepartureChecks')])
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatSettingsStore.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Services/ChatRuntime.swift" \
 "$TMP_DIR/Dependencies.swift" "$TMP_DIR/Production.swift" "$ROOT_DIR/Tests/Chat/ReadCountClientChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
