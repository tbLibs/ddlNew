#!/bin/sh
set -eu
playback_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
playback_temp=$(mktemp -d)
trap 'rm -rf "$playback_temp"' EXIT
# 编译真实播放管理器，仅将系统播放器/音频会话替换为可计数边界。
sed 's/import AVFoundation/import Foundation/' "$playback_root/ddlNew/Features/Chat/Media/PhotoBrowser/ChatPhotoBrowserPlayback.swift" > "$playback_temp/Playback.swift"
swiftc -parse-as-library "$playback_temp/Playback.swift" "$playback_root/Tests/Chat/PhotoBrowserPlaybackChecks.swift" -o "$playback_temp/checks"
"$playback_temp/checks"
