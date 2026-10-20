#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Features/Chat/Media/ChatMediaPreviewStore.swift').read_text()
def method(name):
    start = source.index('    ' + name)
    cursor = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[cursor] == '{') - (source[cursor] == '}')
        cursor += 1
    return source[start:cursor] + '\n'
prefix = '''import Foundation
@MainActor final class ProductionVoiceAudio {
    var file: URL? = URL(fileURLWithPath: "/tmp/anonymous-voice")
    var player: AVAudioPlayer?
    var playing = false, usesReceiver = false
    var generation = UUID()
    var interruptionObserver: NSObjectProtocol?
    var ownsAudioSession = false
'''
methods = method('func playVoice(') + method('private func configureAudio(') + method('private func observeInterruption(') + method('private func releaseVoiceAudio(')
(out/'ProductionVoiceAudio.swift').write_text(prefix + methods + '}\n')
PY
swiftc -parse-as-library "$TMP_DIR/ProductionVoiceAudio.swift" "$ROOT_DIR/Tests/Chat/VoiceAudioChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
