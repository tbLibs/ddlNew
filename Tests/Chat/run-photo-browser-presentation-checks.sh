#!/bin/sh
set -eu
browser_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
browser_temp=$(mktemp -d)
trap 'rm -rf "$browser_temp"' EXIT
# 编译实际呈现控制器，UIKit 边界可手动完成转场，以覆盖关闭/快速重开竞态。
python3 - "$browser_root" "$browser_temp" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'ddlNew/Features/Chat/Media/PhotoBrowser/ChatPhotoBrowserPresentation.swift').read_text()
(out/'Presentation.swift').write_text(s[s.index('@MainActor final class ChatPhotoBrowserPresentationController'):])
start = s.index('    func updateUIViewController(')
end = s.index('    static func dismantleUIViewController', start)
harness = """@MainActor final class PresentationBridgeHarness {
    struct Context {}
    var item: ChatPhotoBrowserRequest? = .init(id: "photo")
    var chatContext: ChatContext? = .init(id: 1)
    var scenePhase = ScenePhase.active
    var allowSharing = true
    var includeCachedHistory = true
"""
# 测试用 class 承载 Binding 的可写状态，显式捕获 self；方法体逻辑不变。
method = s[start:end].replace('context: chatContext)) {', 'context: chatContext)) { [self] in')
(out/'Bridge.swift').write_text(harness + method + '\n}\n')
PY
swiftc -parse-as-library "$browser_temp/"*.swift "$browser_root/Tests/Chat/PhotoBrowserPresentationChecks.swift" -o "$browser_temp/checks"
"$browser_temp/checks"
