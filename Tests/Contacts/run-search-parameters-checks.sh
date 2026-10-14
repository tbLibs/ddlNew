#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 提取生产params构造送入Swift，期望合同独立来自旧NoaAddFriendVC只传userName。
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PYQA'
from pathlib import Path
import sys
root, target = map(Path, sys.argv[1:])
source = (root / 'ddlNew/Network/IM/Contacts/SDKContactsBusinessClient.swift').read_text()
start = source.index('        let params: NSMutableDictionary = ')
setup = source[start:source.index('        var response = ', start)]
start = source.index('        case .search(let text):') + len('        case .search(let text):')
branch = source[start:source.index('            let data = ', start)]
swift = 'import Foundation\nstruct Identity { let userUID: String }\n'
swift += '/// 原样运行生产搜索参数构造，不访问账号或服务器。\nfunc searchParameters(text: String, identity: Identity) -> NSMutableDictionary {\n' + setup + branch + '\nreturn params\n}\n'
swift += 'let sent = searchParameters(text: "qa-peer", identity: Identity(userUID: "qa-own"))\n'
swift += 'precondition(sent["userName"] as? String == "qa-peer", "搜索目标必须为输入账号")\n'
swift += 'precondition(sent.count == 1 && sent["userUid"] == nil, "精确搜索不得额外用当前UID过滤目标")\n'
swift += 'print("Search request contract: 2 passed")\n'
(target / 'checks.swift').write_text(swift)
PYQA
swiftc "$TMP_DIR/checks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
