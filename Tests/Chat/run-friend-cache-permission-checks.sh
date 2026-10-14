#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 实际生产单聊判断在匿名Swift宿主运行；正常WCDB好友行的非持久化status默认0。
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PYQA'
from pathlib import Path
import sys
root, target = map(Path, sys.argv[1:])
source = (root / 'ddlNew/Network/IM/Chat/SDKChatClient.swift').read_text()
start = source.index('                let friend: LingIMFriendModel? = sdk.toolCheckMyFriend(with: context.route.id)')
condition = source[source.index('                value.canSend = ', start):source.index('                if !value.canSend', start)]
swift = 'struct Friend { let status: Int; let disableStatus: Int }\nstruct Permission { var canSend = false }\n'
swift += '/// 复用生产判断验证数据库缓存的可发送资格。\nfunc canSend(_ friend: Friend?) -> Bool { var value = Permission()\n' + condition + '\nreturn value.canSend }\n'
swift += 'precondition(canSend(Friend(status: 0, disableStatus: 0)), "正常WCDB好友行不能因非持久化status默认0被禁止")\n'
swift += 'precondition(canSend(Friend(status: 1, disableStatus: 0)))\n'
swift += 'precondition(!canSend(nil), "已物理移除的好友不能发")\n'
swift += 'precondition(!canSend(Friend(status: 0, disableStatus: 4)), "注销用户不能发")\n'
swift += 'precondition(!canSend(Friend(status: 2, disableStatus: 0)))\n'
swift += 'precondition(!canSend(Friend(status: -1, disableStatus: 0)))\n'
swift += 'print("Single friend cache permission: 6 passed")\n'
(target / 'checks.swift').write_text(swift)
PYQA
swiftc "$TMP_DIR/checks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
