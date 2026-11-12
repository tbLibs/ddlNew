#!/usr/bin/env python3
"""Build an anonymous UI harness using production views and ViewModels; no network/Keychain writes."""
from pathlib import Path
import json, subprocess, sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
source = (root / "ddlNew/Features/Login/Views/LoginView.swift").read_text().replace("#Preview { LoginView() }", "")
source = source.replace("@State private var kind = AccountIdentity.Kind.account", '@State private var kind = mode.contains("phone") ? AccountIdentity.Kind.phone : .account')
source = source.replace("@State private var usesCode = false", '@State private var usesCode = mode.contains("code")')
(out / "LoginView.swift").write_text(source)
files = ['Common/Localization/L10n.swift', 'Common/Localization/AppLanguageStore.swift', 'Common/Localization/LanguageSettingsView.swift', 'Features/Login/ViewModels/LoginViewModel.swift', 'Features/Login/ViewModels/AccountRegistrationViewModel.swift', 'Features/Login/Services/AccountLoginServicing.swift', 'Features/Login/Services/LoginSessionServicing.swift', 'Common/Design/HomeTheme.swift', 'Features/Login/Components/LoginPalette.swift', 'Features/Login/Components/LoginBackground.swift', 'Features/Login/Components/LoginButtonStyle.swift', 'Features/Login/Components/LegalConsentRow.swift', 'Features/Login/Components/AuthenticationFields.swift', 'Features/Login/Views/AccountRegistrationView.swift', 'Features/Login/Views/LoginVerificationSheet.swift', 'Features/Login/Models/AccountIdentity.swift', 'Features/Login/Models/AccountRegistration.swift', 'Features/Login/Models/AccountLoginError.swift', 'Features/Login/Models/LoginSecurityNotice.swift', 'Features/Login/Models/AccountLoginPhase.swift', 'Features/Login/Models/LoginVerification.swift', 'Features/Login/Models/CallingCode.swift', 'Features/Login/Services/LoginVerificationCoordinator.swift', 'Features/Login/ViewModels/AccountCodeViewModel.swift']
sources = [str(root / "ddlNew" / f) for f in files] + [str(out / "LoginView.swift"), str(root / "Tests/LoginUI/Host.swift")]
settings = {"CODE_SIGNING_ALLOWED": "NO", "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1"}
project = {"name": "AuthAudit", "options": {"deploymentTarget": {"iOS": "17.0"}}, "settings": {"base": settings}, "targets": {
 "AuthPreview": {"type": "application", "platform": "iOS", "sources": [{"path": p} for p in sources + [str(root / "ddlNew/Features/Login/Resources/CallingCodes.json"), str(root / "ddlNew/Resources/Localization")]], "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "invalid.anonymous.auth.preview", "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait"}}},
 "AuthUITests": {"type": "bundle.ui-testing", "platform": "iOS", "sources": [{"path": str(root / "Tests/LoginUI/AuthUITests.swift")}], "dependencies": [{"target": "AuthPreview"}], "settings": {"base": {"GENERATE_INFOPLIST_FILE": "YES", "PRODUCT_BUNDLE_IDENTIFIER": "invalid.anonymous.auth.uitests", "TEST_TARGET_NAME": "AuthPreview"}}}
}, "schemes": {"AuthAudit": {"build": {"targets": {"AuthPreview": "all", "AuthUITests": ["test"]}}, "test": {"targets": ["AuthUITests"]}}}}
(out / "project.json").write_text(json.dumps(project, ensure_ascii=False, indent=2))
subprocess.run(["xcodegen", "generate", "--spec", str(out / "project.json")], check=True)
