"""Compile the real month selector in a List, matching both history screens."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
pages = '--pages' in sys.argv
source = (root / 'ddlNew/Features/DailySignIn/DailySignInView.swift').read_text()
start = source.index('private struct DailySignInMonthSelector: View')
end = source.index('private struct DailySignInCalendar: View', start)
(out / 'MonthSelector.swift').write_text('import SwiftUI\n' + source[start:end].replace('private struct DailySignInMonthSelector', 'struct DailySignInMonthSelector', 1))
paths = ['Common/Localization/L10n.swift', 'Features/DailySignIn/DailySignInModels.swift', 'Features/DailySignIn/DailySignInStore.swift', 'Features/Chat/Models/ChatContext.swift', 'Features/Chat/Models/ChatRoute.swift', 'Features/Message/Models/ConversationRecord.swift']
host_sources = [str(out / 'MonthSelector.swift'), str(root / 'Tests/DailySignIn/MonthNavigation/Host.swift')]
test_file = 'NavigationTests.swift'
if pages:
    host_sources = [str(root / 'ddlNew/Features/DailySignIn/DailySignInView.swift'), str(root / 'Tests/DailySignIn/MonthNavigation/PageHost.swift')]
    test_file = 'PageTests.swift'
base = {'CODE_SIGNING_ALLOWED': 'NO', 'SWIFT_VERSION': '5.0', 'GENERATE_INFOPLIST_FILE': 'YES', 'TARGETED_DEVICE_FAMILY': '1', 'ASSETCATALOG_COMPILER_APPICON_NAME': ''}
project = {'name': 'MonthNavigation', 'options': {'deploymentTarget': {'iOS': '16.0'}}, 'settings': {'base': base}, 'targets': {
    'MonthHost': {'type': 'application', 'platform': 'iOS', 'sources': [str(root / 'ddlNew' / p) for p in paths] + host_sources, 'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'invalid.anonymous.signin.months', 'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES'}}},
    'MonthTests': {'type': 'bundle.ui-testing', 'platform': 'iOS', 'sources': [str(root / 'Tests/DailySignIn/MonthNavigation' / test_file)], 'dependencies': [{'target': 'MonthHost'}], 'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'invalid.anonymous.signin.months.tests', 'TEST_TARGET_NAME': 'MonthHost'}}}
}, 'schemes': {'MonthNavigation': {'build': {'targets': {'MonthHost': 'all', 'MonthTests': ['test']}}, 'test': {'targets': ['MonthTests']}}}}
(out / 'project.json').write_text(json.dumps(project, indent=2))
subprocess.run(['xcodegen', 'generate', '--spec', str(out / 'project.json')], check=True)
