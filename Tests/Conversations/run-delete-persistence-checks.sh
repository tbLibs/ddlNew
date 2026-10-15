#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Conversations/SDKConversationsDelegate.swift').read_text().replace('import NoaChatCore','')
(tmp/'Delegate.swift').write_text(s)
s=(root/'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
start=s.index('    func perform('); end=s.index('    /// 草稿',start)
(tmp/'Client.swift').write_text('''import Foundation
import ObjectiveC
@MainActor final class ProductionDeleteClient {
let sdk = NoaIMSDKManager.sharedTool()
func validate(_ context: ChatContext) throws { guard sdk.myUserID() == context.userUID, sdk.isUserDatabaseReady() else { throw ChatClientError.invalidResponse } }
func permissions(context: ChatContext) throws -> ChatPermission { ChatPermission(canDelete: true, canDeleteBoth: true, canRecall: true) }
func request(context: ChatContext, operation: (@escaping (Any?, String?) -> Void, @escaping (Int, String?, String?) -> Void) -> Void) async throws -> [String: Any] {
 var response: [String: Any] = [:]
 operation({ value, _ in response = ["_value": value ?? true] }, { _,_,_ in })
 return response
}
''' + s[start:end] + '\n}')
PY
swiftc -parse-as-library "$ROOT_DIR/ddlNew/Features/Message/Models/ConversationRecord.swift" \
 "$ROOT_DIR/ddlNew/Features/Chat/Models/"*.swift \
 "$TMP_DIR/Delegate.swift" "$TMP_DIR/Client.swift" "$ROOT_DIR/Tests/Conversations/DeletePersistenceChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
