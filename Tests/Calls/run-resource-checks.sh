#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
python3 - "$tmp_dir" <<'PY'
import pathlib,sys
source=pathlib.Path('ddlNew/Features/Calls/Services/CallSystemResources.swift').read_text()
source=source[:source.index('    static func requestPermission(')]+'}\n'
source=source.replace('import AVFoundation','import Foundation').replace('import AudioToolbox','').replace('import UIKit','')
pathlib.Path(sys.argv[1], 'Resources.swift').write_text(source)
PY
swiftc -swift-version 5 "$tmp_dir/Resources.swift" Tests/Calls/ResourceChecks.swift -o "$tmp_dir/checks"
"$tmp_dir/checks"
