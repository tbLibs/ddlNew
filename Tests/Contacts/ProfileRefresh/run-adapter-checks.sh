#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
out=$(mktemp -d /tmp/ddlNew-profile-adapter.XXXXXX)
trap 'rm -rf "$out"' EXIT
python3 - "$out" <<'PY'
from pathlib import Path
import sys
source=Path('ddlNew/Network/IM/Contacts/SDKContactsClient.swift').read_text()
def block(marker):
 start=source.index(marker); end=source.index('{', start)+1; depth=1
 while depth:
  depth+=(source[end]=='{')-(source[end]=='}'); end+=1
 return source[start:end]
prefix=source[:source.index('    /// AUTH前注册')].replace('import NoaChatCore','').replace(': ContactsClient','')
Path(sys.argv[1], 'Adapter.swift').write_text(prefix+block('    func refreshProfile(')+'\n'+block('    func stopObserving(')+'\n}\n')
PY
mapper=""
for candidate in "$HOME"/Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/ObjectMapper/Sources; do
 if [[ -f "$candidate/Mappable.swift" ]]; then mapper="$candidate"; break; fi
done
[[ -n "$mapper" ]]
swiftc -swift-version 5 -emit-library -emit-module -module-name ObjectMapper "$mapper"/*.swift -o "$out/libObjectMapper.dylib" -emit-module-path "$out/ObjectMapper.swiftmodule" > "$out/mapper.log" 2>&1
swiftc -swift-version 5 -I "$out" -L "$out" -lObjectMapper \
 ddlNew/Common/Localization/L10n.swift ddlNew/Network/Core/RemoteAvatarURL.swift \
 ddlNew/Features/Contacts/Models/ContactRecord.swift ddlNew/Features/Contacts/Models/ContactSection.swift \
 ddlNew/Features/Contacts/Services/ContactSorter.swift ddlNew/Features/Contacts/Services/ContactRequestVersions.swift \
 ddlNew/Features/Contacts/Services/ContactProfileRequestGate.swift ddlNew/Features/Contacts/Services/ContactsClientError.swift \
 ddlNew/Features/Contacts/Services/ContactBusinessError.swift ddlNew/Network/IM/Contacts/ContactProfilePayload.swift \
 ddlNew/Network/IM/Contacts/ContactBusinessRequestWaiter.swift "$out/Adapter.swift" Tests/Contacts/ProfileRefresh/AdapterChecks.swift -o "$out/checks"
DYLD_LIBRARY_PATH="$out" "$out/checks"
