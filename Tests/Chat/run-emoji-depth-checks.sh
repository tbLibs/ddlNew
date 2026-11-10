#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp" <<'PY'
from pathlib import Path
import sys
source = Path('ddlNew/Features/Chat/Components/ChatEmojiText.swift').read_text()
start = source.index('    private var rendered: Text {')
end = source.index('\n}\n', start)
body = source[start:end].replace('private var rendered:', 'var rendered:')
Path(sys.argv[1], 'Renderer.swift').write_text('struct Renderer { let value: String; let size = 22\n' + body + '\n}\n')
PY
xcrun swiftc "$tmp/Renderer.swift" Tests/Chat/EmojiDepthChecks.swift -o "$tmp/check"
"$tmp/check"
