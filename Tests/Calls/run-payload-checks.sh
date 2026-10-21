#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
python3 - "$tmp_dir" <<'PY'
import pathlib,sys
source=pathlib.Path('ddlNew/Network/IM/Calls/SDKCallPayload.swift').read_text()
source=source[:source.index('    nonisolated static func liveKit(')]+'}\n'
source=source.replace('import NoaChatCore','')
pathlib.Path(sys.argv[1], 'Payload.swift').write_text(source)
PY
swiftc ddlNew/Features/Calls/Models/CallContract.swift ddlNew/Features/Calls/Models/CallSession.swift "$tmp_dir/Payload.swift" Tests/Calls/PayloadChecks.swift -o "$tmp_dir/checks"
"$tmp_dir/checks"
