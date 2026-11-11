#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
out=$(mktemp -d /tmp/ddlNew-profile-refresh.XXXXXX)
trap 'rm -rf "$out"' EXIT
python3 - "$out" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1])
source=Path('ddlNew/Network/IM/Conversations/SDKConversationsClient.swift').read_text()
# 编译真实观察注册／解除方法，只有会话持久化与SDK由夹具替代。
source=source[:source.index('    /// 在数据库锁内读取')]+ '}\n'
source=source.replace('import NoaChatCore','').replace(': ConversationsClient', '')
(out/'Client.swift').write_text(source)
source=Path('ddlNew/Network/IM/Contacts/SDKContactsDelegate.swift').read_text().replace('import NoaChatCore','')
(out/'Delegate.swift').write_text(source)
PY
swiftc -swift-version 5 ddlNew/Common/Localization/L10n.swift ddlNew/Features/Contacts/Services/ContactsChange.swift "$out/Client.swift" "$out/Delegate.swift" Tests/Contacts/ProfileRefresh/ObservationChecks.swift -o "$out/checks"
"$out/checks"
swiftc -swift-version 5 ddlNew/Common/Localization/L10n.swift \
 ddlNew/Network/Core/RemoteAvatarURL.swift ddlNew/Features/Contacts/Models/ContactRecord.swift \
 ddlNew/Features/Contacts/Models/ContactSection.swift ddlNew/Features/Contacts/Services/ContactSorter.swift \
 ddlNew/Features/Contacts/Services/ContactsChange.swift ddlNew/Features/Contacts/Services/ContactsClient.swift \
 ddlNew/Features/Contacts/Services/ContactsStore.swift ddlNew/Features/Contacts/Services/ContactRequestVersions.swift \
 Tests/Contacts/MockContactsClient.swift Tests/Contacts/ProfileRefresh/StoreChecks.swift -o "$out/store-checks"
"$out/store-checks"
