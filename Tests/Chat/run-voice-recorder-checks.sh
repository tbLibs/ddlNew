#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
# 生产录音器原样编译，仅替换系统麦克风和认证边界，不申请实际录音权限。
sed -e '/^import AVFoundation$/d' -e 's/, AVAudioRecorderDelegate//g' \
 "$ROOT_DIR/ddlNew/Features/Chat/Media/ChatVoiceRecorder.swift" > "$TMP_DIR/Recorder.swift"
swiftc -parse-as-library "$TMP_DIR/Recorder.swift" "$ROOT_DIR/ddlNew/Features/Chat/Models/ChatVoicePressState.swift" "$ROOT_DIR/Tests/Chat/VoiceRecorderChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
