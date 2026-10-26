#!/bin/sh
# 从生产Cloud client提取无网络的目录、URL和配额方法，不复制待测逻辑。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_OUT=$(mktemp -d /tmp/ddlNew-qa-cloud-policy.XXXXXX)
trap 'rm -rf "$QA_OUT"' EXIT
python3 - "$QA_ROOT" "$QA_OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
source=(root/'ddlNew/Network/IM/Chat/SDKCloudChatMediaClient.swift').read_text()
methods=source[source.index('    private func objectURL('):source.index('    /// 同UID重新登录')].replace('private func ', 'func ')
key=source[source.index('        let day = DateFormatter()'):source.index('        let bucket = provider')]
routing=source[source.index('        let bucket = provider'):source.index('        let hashTask =')]
body='import Foundation\n@MainActor final class ProductionCloudPolicy {\n'+methods+'\n/// 使用生产目录构造代码，仅提供离线调用入口。\nfunc objectKey(_ attachment: ChatAttachment) -> String {\n'+key+'\nreturn key\n}\n}\n'
body=body.rstrip()[:-1]+'\nfunc configuredURLs(key: String) throws -> (URL, URL) {\nlet provider = CloudStorageProvider(rawValue: LocalMediaSettings.ossConfigType)!\n'+routing+'\nreturn (uploadURL, downloadURL)\n}\n}\n'
(out/'ProductionCloudPolicy.swift').write_text(body)
PY
swiftc -parse-as-library "$QA_ROOT/ddlNew/Configuration/LocalMessagingSettings.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/Cloud/CloudStorageProvider.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/ChatFailureReason.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/ChatAttachment.swift" "$QA_OUT/ProductionCloudPolicy.swift" "$QA_ROOT/Tests/MigrationAcceptance/CloudPolicyChecks.swift" -o "$QA_OUT/checks"
"$QA_OUT/checks"
