#!/bin/sh
set -eu
call_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
call_temp=$(mktemp -d)
trap 'rm -rf "$call_temp"' EXIT
python3 - "$call_root" "$call_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Network/IM/Calls/SDKCallClient.swift').read_text()
method = s[s.index('    private func request(context:'):s.rfind('\n}')].replace('private func request', 'func request')
(out/'Request.swift').write_text('''import Foundation
@MainActor final class RequestHarness {
    var valid = true
    func validate(_ context: ChatContext) throws { if !valid { throw CancellationError() } }
''' + method + '\n}\n')
PY
swiftc -swift-version 5 -parse-as-library "$call_temp/Request.swift" \
 "$call_root/ddlNew/Network/IM/SDK/SDKLoginRequestWaiter.swift" \
 "$call_root/ddlNew/Features/Calls/Models/CallContract.swift" \
 "$call_root/Tests/Calls/RequestChecks.swift" -o "$call_temp/checks"
"$call_temp/checks"
