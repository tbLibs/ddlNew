#!/bin/bash
# Archive/export, then upload. Version overrides do not edit the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA_URL='https://static.xingqitongim.com/ddlnew/ddlNew.ipa'
ICON_URL='https://static.xingqitongim.com/ios/512.png'
TEAM_ID='DGK6VR7P2D'
OUTPUT=''
ARCHIVE=''
ALLOW_UPDATES=0
UPLOAD=1
VERSION=''
BUILD_NUMBER=''

usage() {
    cat <<'EOF'
用法：Scripts/package-adhoc.sh [选项]

  --output DIR                  产物目录（必须尚不存在）
  --archive PATH                复用已有 .xcarchive，仅重新导出
  --version VERSION             本次版本号，例如 1.3.1（不传沿用工程）
  --build-number NUMBER         本次 Build 正整数，例如 2（也可用 --build）
  --allow-provisioning-updates   允许 Xcode 更新签名证书和描述文件
  --no-upload                   只打包，不上传服务器
  -h, --help                    显示参数说明

默认归档 ddlNew.xcworkspace / ddlNew / Release，导出 Ad Hoc 包。
产物：build/adhoc/<唯一目录>/{ddlNew.ipa,manifest.plist,ExportOptions.plist,...}
依赖：Xcode、asc（支持 xcode archive/export）、Python 3、已安装的 CocoaPods 依赖。
签名：Xcode 登录团队 DGK6VR7P2D，测试设备已加入 Ad Hoc 描述文件。
IPA 地址：https://static.xingqitongim.com/ddlnew/ddlNew.ipa
打包成功后自动上传 root@8.210.96.3:22 的 /data/static-site/ddlnew/。
版本参数只影响本次归档，不修改工程；不能与 --archive 同时使用。
归档时不调用项目可选的 sentry-cli 上传阶段。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output|--archive|--version|--build-number|--build)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "$1 缺少参数值"
            case "$1" in
                --output) OUTPUT="$2" ;;
                --archive) ARCHIVE="$2" ;;
                --version) VERSION="$2" ;;
                --build-number|--build) BUILD_NUMBER="$2" ;;
            esac
            shift 2 ;;
        --allow-provisioning-updates) ALLOW_UPDATES=1; shift ;;
        --no-upload) UPLOAD=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$1（使用 --help 查看帮助）" ;;
    esac
done
[[ -z "$VERSION" || "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || die '版本号必须为 1 至 3 段数字，例如 1.3.1'
[[ -z "$BUILD_NUMBER" || "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die 'Build 号必须是正整数'
[[ -z "$ARCHIVE" || ( -z "$VERSION" && -z "$BUILD_NUMBER" ) ]] || die '--archive 不能同时指定版本／Build；请重新归档以更新版本'

ASC="$(command -v asc)" || die '未找到 asc，请先安装 App Store Connect CLI'
PYTHON="$(command -v python3)" || die '未找到 Python 3'
command -v xcodebuild >/dev/null || die '未找到 Xcode 命令行工具'
[[ -d "$ROOT/ddlNew.xcworkspace" ]] || die '未找到 ddlNew.xcworkspace'
if [[ -n "$ARCHIVE" ]]; then
    [[ -d "$ARCHIVE" && -f "$ARCHIVE/Info.plist" ]] || die '归档不存在或缺少 Info.plist'
    ARCHIVE="$(cd "$ARCHIVE" && pwd)"
else
    [[ -f "$ROOT/Pods/Manifest.lock" ]] || die '请先在项目根目录运行 pod install'
    cmp -s "$ROOT/Podfile.lock" "$ROOT/Pods/Manifest.lock" || die 'Pods 与 Podfile.lock 不一致，请先运行 pod install'
fi

if [[ -n "$OUTPUT" ]]; then
    [[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || die "产物目录已存在，不覆盖：$OUTPUT"
    mkdir -p "$(dirname "$OUTPUT")"
    mkdir "$OUTPUT"
else
    mkdir -p "$ROOT/build/adhoc"
    OUTPUT="$(mktemp -d "$ROOT/build/adhoc/$(date +%Y%m%d-%H%M%S).XXXXXX")"
fi
OUTPUT="$(cd "$OUTPUT" && pwd)"
trap 'printf "打包或上传中断，已保留产物与日志：%s\n" "$OUTPUT" >&2' ERR

# Resolve asc/python before restricting the build PATH. The project discovers
# sentry-cli with `which`; local packaging should retain dSYMs without uploading sources.
BUILD_PATH='/usr/bin:/bin:/usr/sbin:/sbin'
# Keep the array nonempty for macOS /bin/bash 3.2 with `set -u`.
ASC_OPTIONS=(--output json)
if [[ "$ALLOW_UPDATES" == 1 ]]; then
    ASC_OPTIONS+=(--xcodebuild-flag=-allowProvisioningUpdates)
fi
if [[ -z "$ARCHIVE" ]]; then
    ARCHIVE="$OUTPUT/ddlNew.xcarchive"
    ARCHIVE_OPTIONS=("${ASC_OPTIONS[@]}")
    if [[ -n "$VERSION" ]]; then
        ARCHIVE_OPTIONS+=("--xcodebuild-flag=MARKETING_VERSION=$VERSION")
    fi
    if [[ -n "$BUILD_NUMBER" ]]; then
        ARCHIVE_OPTIONS+=("--xcodebuild-flag=CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
    fi
    printf '正在归档：%s\n' "$ARCHIVE"
    PATH="$BUILD_PATH" "$ASC" xcode archive \
        --workspace "$ROOT/ddlNew.xcworkspace" --scheme ddlNew \
        --configuration Release --archive-path "$ARCHIVE" \
        --xcodebuild-flag=-destination --xcodebuild-flag=generic/platform=iOS \
        --xcodebuild-flag=-derivedDataPath --xcodebuild-flag="$OUTPUT/DerivedData" \
        "${ARCHIVE_OPTIONS[@]}" 2>&1 | tee "$OUTPUT/archive.log"
fi

"$PYTHON" - "$OUTPUT/ExportOptions.plist" "$TEAM_ID" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'wb') as file:
    plistlib.dump({
        'method': 'release-testing',
        'destination': 'export',
        'teamID': sys.argv[2],
        'signingStyle': 'automatic',
        'stripSwiftSymbols': True,
        'thinning': '<none>',
        'manageAppVersionAndBuildNumber': False,
    }, file)
PY

printf '正在导出 Ad Hoc IPA…\n'
PATH="$BUILD_PATH" "$ASC" xcode export \
    --archive-path "$ARCHIVE" --export-options "$OUTPUT/ExportOptions.plist" \
    --ipa-path "$OUTPUT/ddlNew.ipa" \
    "${ASC_OPTIONS[@]}" 2>&1 | tee "$OUTPUT/export.log"

# Read the exported IPA rather than source build settings, including on re-export.
"$PYTHON" - "$OUTPUT/ddlNew.ipa" "$OUTPUT/manifest.plist" "$IPA_URL" "$ICON_URL" <<'PY'
import plistlib
import re
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as ipa:
    infos = [name for name in ipa.namelist()
             if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', name)]
    if len(infos) != 1:
        raise SystemExit('IPA 必须且只能包含一个主 App Info.plist')
    info = plistlib.loads(ipa.read(infos[0]))

def required(key):
    value = info.get(key)
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f'IPA 缺少有效字段：{key}')
    return value

bundle = required('CFBundleIdentifier')
version = required('CFBundleShortVersionString')
build = required('CFBundleVersion')
title = info.get('CFBundleDisplayName') or required('CFBundleName')
manifest = {'items': [{
    'assets': [
        {'kind': 'software-package', 'url': sys.argv[3]},
        {'kind': 'display-image', 'url': sys.argv[4]},
        {'kind': 'full-size-image', 'url': sys.argv[4]},
    ],
    'metadata': {
        'bundle-identifier': bundle,
        'bundle-version': version,
        'kind': 'software',
        'platform-identifier': 'com.apple.platform.iphoneos',
        'title': title,
        # Optional metadata consumed by the existing download page.
        'build-version': build,
    },
}]}
with open(sys.argv[2], 'wb') as file:
    plistlib.dump(manifest, file, sort_keys=False)
print(f'安装清单：{title} · {bundle} · bundle-version={version} · build={build}')
PY
/usr/bin/plutil -lint "$OUTPUT/ExportOptions.plist" "$OUTPUT/manifest.plist"
printf '\n打包完成：%s\nIPA：%s/ddlNew.ipa\n清单：%s/manifest.plist\n' "$OUTPUT" "$OUTPUT" "$OUTPUT"
if [[ "$UPLOAD" == 1 ]]; then
    "$ROOT/Scripts/upload-adhoc.sh" "$OUTPUT" 2>&1 | tee "$OUTPUT/upload.log"
fi
