from pathlib import Path
import json, subprocess, sys
root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve(); out.mkdir(parents=True, exist_ok=True)
source = (root/'ddlNew/Features/Contacts/Views/ContactRecordDetailView.swift').read_text()
a = source.index('    private func detail('); b = source.index('{', a) + 1; depth = 1
while depth:
    depth += (source[b] == '{') - (source[b] == '}'); b += 1
fixture = (root/'Tests/Contacts/ProfileLayout/Fixture.swift').read_text().replace('    // PRODUCTION_DETAIL', source[a:b])
a = source.index('        MessagingScroll {'); b = source.index('{', a) + 1; depth = 1
while depth:
    depth += (source[b] == '{') - (source[b] == '}'); b += 1
fixture = fixture.replace('        // PRODUCTION_PROFILE_CONTENT', source[a:source.index('        .navigationTitle', b)].rstrip())

fixture += '\n' + source[source.index('private struct ContactProfileScrollBehavior: ViewModifier'):]
(out/'Fixture.swift').write_text(fixture)
for name in ['MessagingScroll', 'MessagingCard', 'MessagingRowStyle', 'MessagingActionButtonStyle']:
    text = (root/f'ddlNew/Common/Components/{name}.swift').read_text()
    (out/f'{name}.swift').write_text(text)
adapter = next(Path.home().glob('Library/Developer/Xcode/DerivedData/ddlNew-*/SourcePackages/checkouts/UIAdapter'))
layout_sources = [str(out/'Fixture.swift'),str(out/'MessagingScroll.swift'),str(out/'MessagingCard.swift'),str(out/'MessagingRowStyle.swift'),str(out/'MessagingActionButtonStyle.swift'),str(root/'ddlNew/Common/Localization/L10n.swift')]
base = {'CODE_SIGNING_ALLOWED':'NO', 'SWIFT_VERSION':'5.0', 'GENERATE_INFOPLIST_FILE':'YES', 'TARGETED_DEVICE_FAMILY':'1'}
project = {'name':'ProfileLayout', 'packages':{'UIAdapter':{'path':str(adapter)}}, 'options':{'deploymentTarget':{'iOS':'16.0'}}, 'settings':{'base':base}, 'targets':{
'ProfileHost':{'type':'application','platform':'iOS','sources':[str(root/'Tests/Contacts/ProfileLayout/Host.swift')] + layout_sources, 'dependencies':[{'package':'UIAdapter'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.profile.host','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
'ProfileTests':{'type':'bundle.unit-test','platform':'iOS','sources':[str(out/'Fixture.swift'),str(out/'MessagingScroll.swift'),str(out/'MessagingCard.swift'),str(out/'MessagingRowStyle.swift'),str(out/'MessagingActionButtonStyle.swift'),str(root/'ddlNew/Common/Localization/L10n.swift'),str(root/'Tests/Contacts/ProfileLayout/LayoutTests.swift')],'dependencies':[{'target':'ProfileHost'},{'package':'UIAdapter'}],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.profile.tests'}}}},
'schemes':{'ProfileLayout':{'build':{'targets':{'ProfileHost':'all','ProfileTests':['test']}},'test':{'targets':['ProfileTests']}}}}
project['targets']['GestureTests'] = {'type':'bundle.ui-testing','platform':'iOS','sources':[str(root/'Tests/Contacts/ProfileLayout/GestureTests.swift')],'dependencies':[{'target':'ProfileHost'}],'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'invalid.anonymous.profile.gestures'}}}
project['schemes']['ProfileLayout']['test']['targets'].append('GestureTests')
project['schemes']['ProfileLayout']['build']['targets']['GestureTests'] = ['test']
(out/'project.json').write_text(json.dumps(project))
subprocess.run(['xcodegen','generate','--spec',str(out/'project.json')],check=True)
