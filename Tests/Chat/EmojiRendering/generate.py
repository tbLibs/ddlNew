"""Build a native iOS test host around the unchanged production emoji renderer."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
assets = out / "Assets.xcassets"
assets.mkdir(exist_ok=True)
for name in ["e_01_smile", "e_02_joy"]:
    shutil.copytree(root / f"ddlNew/Resources/Assets.xcassets/emoji/{name}.imageset", assets / f"{name}.imageset", dirs_exist_ok=True)
production = [root / "ddlNew/Features/Chat/Components/ChatEmojiText.swift", root / "ddlNew/Features/Chat/Models/ChatEmojiCatalog.swift"]
base = {"CODE_SIGNING_ALLOWED": "NO", "SWIFT_VERSION": "5.0", "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1", "ASSETCATALOG_COMPILER_APPICON_NAME": ""}
project = {"name": "EmojiRendering", "options": {"deploymentTarget": {"iOS": "16.0"}}, "settings": {"base": base}, "targets": {
    "EmojiHost": {"type": "application", "platform": "iOS", "sources": [str(root / "Tests/Chat/EmojiRendering/Host.swift"), str(root / "ddlNew/Resources/ChatEmojiCatalog.plist"), str(assets)], "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "invalid.anonymous.emoji.host", "ASSETCATALOG_COMPILER_APPICON_NAME": "", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES"}}},
    "EmojiTests": {"type": "bundle.unit-test", "platform": "iOS", "sources": [str(p) for p in production] + [str(root / "Tests/Chat/EmojiRendering/RenderingTests.swift")], "dependencies": [{"target": "EmojiHost"}], "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "invalid.anonymous.emoji.tests"}}}
}, "schemes": {"EmojiRendering": {"build": {"targets": {"EmojiHost": "all", "EmojiTests": ["test"]}}, "test": {"targets": ["EmojiTests"]}}}}
(out / "project.json").write_text(json.dumps(project, indent=2))
subprocess.run(["xcodegen", "generate", "--spec", str(out / "project.json")], check=True)
