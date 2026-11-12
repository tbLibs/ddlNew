from pathlib import Path
import json, subprocess, sys
root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve(); out.mkdir(parents=True, exist_ok=True)
source = Path(sys.argv[2]) if len(sys.argv)>2 else root/'ddlNew/Features/Chat/Views/ChatRoomView.swift'
s = source.read_text()
def block(marker):
    start=s.index(marker); pos=s.index('{', start)+1; depth=1
    while depth:
        depth += (s[pos]=='{')-(s[pos]=='}'); pos+=1
    return s[start:pos]
scroll = block('                ScrollView {')
methods = block('    private var initialMessagesReady:')+'\n'+block('    private func positionInitialMessages(')
host=(root/'Tests/Chat/InitialLayout/Host.swift').read_text().replace('// PRODUCTION_SCROLL',scroll).replace('// PRODUCTION_METHODS', methods)
(out/'Host.swift').write_text(host)
settings={'CODE_SIGNING_ALLOWED':'NO','SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1'}
project={'name':'ChatEntry','options':{'deploymentTarget':{'iOS':'16.0'}},'settings':{'base':settings},'targets':{
'EntryHost':{'type':'application','platform':'iOS','sources':[str(out/'Host.swift'),str(root/'ddlNew/Features/Chat/Components/ChatLatestPreference.swift'),str(root/'ddlNew/Features/Chat/Models/ChatViewportPolicy.swift')],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.chatentry','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
'EntryTests':{'type':'bundle.ui-testing','platform':'iOS','sources':[str(root/'Tests/Chat/InitialLayout/EntryTests.swift')],'dependencies':[{'target':'EntryHost'}],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.chatentry.tests'}}}
},'schemes':{'ChatEntry':{'build':{'targets':{'EntryHost':'all','EntryTests':['test']}},'test':{'targets':['EntryTests']}}}}
(out/'project.json').write_text(json.dumps(project));subprocess.run(['xcodegen','generate','--spec',str(out/'project.json')],check=True)
