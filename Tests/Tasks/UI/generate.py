"""Anonymous host compiles production task UI, storage, theme and toast; no SDK/login."""
import json, subprocess, sys
from pathlib import Path
root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve(); out.mkdir(parents=True, exist_ok=True)
alert = next(Path.home().glob('Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/AlertToast'))
sources = [root/'Tests/Tasks/UI/Host.swift', root/'ddlNew/Features/Tasks', root/'ddlNew/Common/Localization/L10n.swift', root/'ddlNew/Resources/Localization/Localizable.xcstrings']
sources += [root/f'ddlNew/Common/{name}' for name in ['Design/HomeTheme.swift', 'Design/MessagingTheme.swift', 'Design/Color+ClubHex.swift', 'Components/MessagingStatusToast.swift']]
base = {'CODE_SIGNING_ALLOWED':'NO','SWIFT_VERSION':'5.0','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2'}
project = {'name':'PersonalTasks', 'packages':{'AlertToast':{'path':str(alert)}}, 'options':{'deploymentTarget':{'iOS':'16.0'}}, 'settings':{'base':base}, 'targets':{
'Host':{'type':'application','platform':'iOS','sources':[str(p) for p in sources], 'dependencies':[{'package':'AlertToast'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.personaltasks.host','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
'TaskUITests':{'type':'bundle.ui-testing','platform':'iOS','sources':[str(root/'Tests/Tasks/UI/TaskUITests.swift')], 'dependencies':[{'target':'Host'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.personaltasks.tests'}}}},
'schemes':{'PersonalTasks':{'build':{'targets':{'Host':'all','TaskUITests':['test']}},'test':{'targets':['TaskUITests']}}}}
(out/'project.json').write_text(json.dumps(project))
subprocess.run(['xcodegen','generate','--spec',str(out/'project.json')],check=True)
