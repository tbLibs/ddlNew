from pathlib import Path
import json, subprocess, sys
root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
source = (root/'ddlNew/Features/Chat/Views/ChatRoomView.swift').read_text()
start = source.index('.contextMenu {', source.index('private func messageRow('))
end = source.index('{', start) + 1; depth = 1
while depth:
    depth += (source[end] == '{') - (source[end] == '}'); end += 1
host = (root/'Tests/Chat/ContextMenuFocus/Host.swift').read_text().replace('// PRODUCTION_CONTEXT_MENU', source[start:end])
dismissal = source.index('.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))')
dismissal_end = source.index('{', dismissal) + 1; depth = 1
while depth:
    depth += (source[dismissal_end] == '{') - (source[dismissal_end] == '}'); dismissal_end += 1
host = host.replace('// PRODUCTION_KEYBOARD_DISMISSAL', source[dismissal:dismissal_end])
(out/'Host.swift').write_text(host)
files = ['Components/ChatComposerTextInput.swift','Models/ChatComposerMode.swift','Models/ChatEmojiCatalog.swift','Models/ChatInputLimit.swift']
production = [str(root/'ddlNew/Features/Chat'/f) for f in files] + [str(root/'ddlNew/Common/Localization/L10n.swift')]
settings = {'CODE_SIGNING_ALLOWED':'NO','SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1'}
project={'name':'ContextMenuFocus','options':{'deploymentTarget':{'iOS':'16.0'}},'settings':{'base':settings},'targets':{
 'FocusHost':{'type':'application','platform':'iOS','sources':[str(out/'Host.swift')]+production+[str(root/'ddlNew/Resources/ChatEmojiCatalog.plist')],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.contextfocus','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
 'FocusTests':{'type':'bundle.ui-testing','platform':'iOS','sources':[str(root/'Tests/Chat/ContextMenuFocus/FocusTests.swift')],'dependencies':[{'target':'FocusHost'}],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.contextfocus.tests'}}}
 },'schemes':{'ContextMenuFocus':{'build':{'targets':{'FocusHost':'all','FocusTests':['test']}},'test':{'targets':['FocusTests']}}}}
(out/'project.json').write_text(json.dumps(project))
subprocess.run(['xcodegen','generate','--spec',str(out/'project.json')],check=True)
