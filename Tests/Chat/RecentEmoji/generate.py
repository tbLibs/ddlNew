import json, subprocess, sys
from pathlib import Path
root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve(); out.mkdir(parents=True, exist_ok=True)
adapter = next(Path.home().glob('Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/UIAdapter'))
sources = [root/'Tests/Chat/RecentEmoji/Host.swift', root/'ddlNew/Features/Chat/Components/ChatEmojiPanel.swift', root/'ddlNew/Common/Localization/L10n.swift', root/'ddlNew/Resources/ChatEmojiCatalog.plist']
sources += [root/f'ddlNew/Features/Chat/Models/{name}.swift' for name in ['ChatEmojiCatalog', 'ChatInputLimit', 'ChatGameSticker']]
store = root/'ddlNew/Features/Chat/Services/ChatRecentEmojiHistory.swift'
if store.exists(): sources.append(store)
base = {'CODE_SIGNING_ALLOWED':'NO','SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1'}
project = {'name':'RecentEmoji', 'packages':{'UIAdapter':{'path':str(adapter)}}, 'options':{'deploymentTarget':{'iOS':'16.0'}}, 'settings':{'base':base}, 'targets':{
'Host':{'type':'application','platform':'iOS','sources':[str(p) for p in sources], 'dependencies':[{'package':'UIAdapter'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.recentemoji.host','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
'PanelTests':{'type':'bundle.ui-testing','platform':'iOS','sources':[str(root/'Tests/Chat/RecentEmoji/PanelTests.swift')], 'dependencies':[{'target':'Host'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.recentemoji.tests'}}}},
'schemes':{'RecentEmoji':{'build':{'targets':{'Host':'all','PanelTests':['test']}},'test':{'targets':['PanelTests']}}}}
(out/'project.json').write_text(json.dumps(project))
subprocess.run(['xcodegen','generate','--spec',str(out/'project.json')],check=True)
