#!/bin/sh
set -eu
call_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
call_temp=$(mktemp -d)
trap 'rm -rf "$call_temp"' EXIT
python3 - "$call_root" "$call_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Network/IM/Calls/ZegoCallEngine.swift').read_text()
start = source.index('@MainActor final class')
fields = source[start:source.index('    func connect(')]
fields = fields.replace('NSObject, CallMediaEngine, ZegoEventHandler', 'NSObject, CallMediaEngine')
methods = source[source.index('    func attach('):source.index('    nonisolated func onRemoteMicStateUpdate(')]
harness = '''
    func prepareForChecks(video: Bool = true) {
        active = true; roomID = "room"; localID = "self"; kind = video ? .video : .audio
        engine = ZegoExpressEngine(); Self.owner = self
    }
'''
(out/'Zego.swift').write_text('import Foundation\n' + fields.replace('private ', '') + harness + methods + '\n}\n')
source = (root/'ddlNew/Features/Calls/Components/CallVideoSurface.swift').read_text()
(out/'Surface.swift').write_text('import Foundation\nimport CoreGraphics\n@MainActor ' + source[source.index('final class CallVideoContainer:'):])
PY
swiftc -swift-version 5 -parse-as-library "$call_temp/"*.swift "$call_root/Tests/Calls/VideoChecks.swift" -o "$call_temp/checks"
"$call_temp/checks"
