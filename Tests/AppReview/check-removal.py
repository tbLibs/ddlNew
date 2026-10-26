#!/usr/bin/env python3
"""Guard against reintroducing removed IP collection and system-config entry points.

With an .app argument, also scan every Mach-O in the built bundle. This checks
known removed functionality, not general App Store compliance or runtime traffic.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REMOVED = re.compile(
    r"(?:get|Get)SystemConfig|SystemConfig(?:Service|Crypto|Record|Store)|"
    r"HostNodeRaceManager|DNSPayloadDecoder|DNSHostNormalizer|DNSUDPResolver|AliDoHTXTDecoder|"
    r"OSSAuthTCPClient|OSSAuthRequestBuilder|OSSHTTPConfigurationClient|OSSLegacyConfigurationParser|"
    r"tencentDoHAAAA|cloudflareDoHTXT|cloudflareDoHAAAA|aliDoHTXT|primarySources|"
    r"nav\.ziyouyi\.com|jndnav\.jiguanged\.com|nav\.rnzkzw\.com|"
    r"PublicIPResolver|publicIPLookupURLs|getDevicePublicNetworkIP|"
    r"getIPAddresses|getIPAddress:|DNSGetLocalIP|getCurentLocalIP|AlicloudPDNS|pdns-sdk-ios|TBBasicLib|"
    r"(?:imSdk)?UploadDNSinfoWith|/biz/dns/report|"
    r"ipinfo\.io|checkip\.amazonaws\.com|api\.ipify\.org|"
    r"LiveKit|WebRTC|ZegoExpressEngine|NoaIMCallManager|NoaIMZGCall|LingIMCallOptionsManager|"
    r"NoaIMMediaCallDelegate|imSdkCallRoom|/biz/call/|/phone/(?:group/|\w+Call)|"
    r"client-sdk-swift|express-video-ios|webrtc-sdk|"
    r"/biz/system/getRoleConfig|/biz/user/getUserRoleAuthorityList|"
    r"/biz/group/activity/config/get|/biz/signInRecord/signConfig|"
    r"/biz/translate/channelConfig|/biz/userTranslate/(?:all|uploadConfig)|"
    r"/auth/account/getLoginTypes|syncAppUserAndSessionTranslateInfoServer"
)
REPORTING = re.compile(r"\.(?:loginIp|clientIp)\s*=(?!=)|\bset(?:LoginIp|ClientIp):")
INTERFACE_COLLECTION = re.compile(r"\bgetifaddrs\s*\(")
failures = []
for name in (
    "Podfile", "Podfile.lock", "ddlNew.xcodeproj/project.pbxproj",
    "NoaChatSDKCore/CandyTalkPro.xcodeproj/project.pbxproj",
    "ddlNew.xcworkspace/xcshareddata/swiftpm/Package.resolved",
):
    if REMOVED.search((ROOT / name).read_text()):
        failures.append(f"{name}: removed dependency is still configured")
for directory in (ROOT / "ddlNew", ROOT / "NoaChatSDKCore"):
    for path in directory.rglob("*"):
        if path.suffix not in {".swift", ".m", ".mm", ".h"}:
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            # Generated protocol definitions retain their wire numbers; they
            # are not collection or reporting. Production assignments are not allowed.
            match = REMOVED.search(line) or INTERFACE_COLLECTION.search(line) or (
                None if ".pb." in path.name or ".pbobjc." in path.name else REPORTING.search(line)
            )
            if match:
                failures.append(f"{path.relative_to(ROOT)}:{number}: {match.group()}")

if len(sys.argv) > 1:
    bundle = Path(sys.argv[1]).resolve()
    if not bundle.is_dir() or bundle.suffix != ".app":
        sys.exit("Expected a built .app directory")
    binaries = 0
    for path in bundle.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        kind = subprocess.check_output(["file", "-b", str(path)], text=True)
        if "Mach-O" not in kind:
            continue
        binaries += 1
        strings = subprocess.check_output(["strings", "-a", str(path)], text=True, errors="replace")
        for value in sorted(set(REMOVED.findall(strings))):
            failures.append(f"{path.relative_to(bundle)}: {value}")
        symbols = subprocess.run(["nm", "-u", str(path)], capture_output=True, text=True, check=True)
        if re.search(r"\b_getifaddrs\b", symbols.stdout):
            print(f"REVIEW: retained network-interface API in {path.relative_to(bundle)}")
    if not binaries:
        sys.exit("No Mach-O binaries found in bundle")
    print(f"Scanned {binaries} Mach-O binaries")

if failures:
    print("FAIL: removed functionality remains\n" + "\n".join(failures))
    sys.exit(1)
print("PASS: no removed IP collection/reporting, calling SDKs or configuration entry points")
