#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TASK_TMP=$(mktemp -d /tmp/ddlNew-conversation-online.XXXXXX)
trap 'rm -rf "$TASK_TMP"' EXIT
python3 - "$TASK_ROOT" "$TASK_TMP" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
def block(source, marker):
 start=source.index(marker); end=source.index('{',start)+1; depth=1
 while depth:
  depth+=(source[end]=='{')-(source[end]=='}'); end+=1
 return source[start:end]
source=(root/'ddlNew/Network/IM/Conversations/SDKConversationsClient.swift').read_text()
load=block(source,'    func loadConversations(')
title=block(source,'    nonisolated static func displayTitle(')
kinds=block(source,'private extension ConversationKind')
view=(root/'ddlNew/Features/Message/Views/MessageView.swift').read_text()
label=block(view,'    private func accessibilityLabel(').replace('private func','func')
(out/'Production.swift').write_text('''import Foundation
@MainActor final class ProductionClient: ConversationsClient {
 var changed: ((ConversationsChange) -> Void)?
 func observe(for userUID: String, _ onChange: @escaping @MainActor (ConversationsChange) -> Void) { changed = onChange }
 func stopObserving() { changed = nil }
LOAD
TITLE
}
KINDS
struct ProductionRow {
LABEL
 static func displayTime(_ date: Date) -> String { "12:00" }
}
'''.replace('LOAD',load).replace('TITLE',title).replace('KINDS',kinds).replace('LABEL',label))
PY
swiftc -parse-as-library "$TASK_ROOT/ddlNew/Features/Message/Models/"*.swift \
 "$TASK_ROOT/ddlNew/Features/Message/Services/ConversationsStore.swift" \
 "$TASK_ROOT/ddlNew/Features/Message/Services/ConversationOperationsClient.swift" \
 "$TASK_TMP/Production.swift" "$TASK_ROOT/Tests/Conversations/OnlineChecks.swift" -o "$TASK_TMP/checks"
"$TASK_TMP/checks"
