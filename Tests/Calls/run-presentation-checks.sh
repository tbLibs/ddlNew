#!/bin/sh
set -eu
call_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
call_temp=$(mktemp -d)
trap 'rm -rf "$call_temp"' EXIT
# Execute production floating-window methods against a UIKit containment boundary.
python3 - "$call_root" "$call_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Calls/Components/CallPresentation.swift').read_text()
start = source.index('    private func syncBubble()')
end = source.index('\n}\n', start)
methods = source[start:end].replace('private func', 'func').replace('@objc ', '')
methods = methods.replace('#selector(dragBubble(_:))', '"dragBubble:"')
(out/'Presentation.swift').write_text('''import Foundation
import CoreGraphics
@MainActor final class CallPresentationHarness: UIViewController {
    var attached = true
    var floating = true
    var coordinator: CallCoordinator? = CallCoordinator()
    var sceneWindow: UIWindow?
    var bubble: UIHostingController<CallFloatingView>?
''' + methods + '\n}\n')
PY
swiftc -parse-as-library "$call_temp/Presentation.swift" "$call_root/Tests/Calls/PresentationChecks.swift" -o "$call_temp/checks"
"$call_temp/checks"
