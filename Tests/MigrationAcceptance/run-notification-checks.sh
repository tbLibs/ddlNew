#!/bin/sh
# 从真实SDK源提取单个生产方法，替代SDK形状仅存在独立测试目标。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_OUT=$(mktemp -d /tmp/ddlNew-qa-notification.XXXXXX)
trap 'rm -rf "$QA_OUT"' EXIT
python3 - "$QA_ROOT" "$QA_OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
source=(root/'ddlNew/Network/IM/GroupApplications/SDKGroupApplicationsClient.swift').read_text()
method=source[source.index('    func markNotificationsRead('):source.index('    /// 当前账号及本地群角色')]
load=source[source.index('    func load('):source.index('    /// 返回每条真实处理结果')]
request=source[source.index('    private func request('):source.rfind('\n}')].replace('private func request(', 'func request(', 1)
prefix='import Foundation\nimport ObjectiveC\nimport ObjectMapper\n@MainActor final class ProductionNotificationRead {\n'
suffix='\n/// 离线形状仅验证身份，原已读方法其余代码原样保留。\nprivate func validate(userUID: String, groupID: String?) throws { guard NoaIMSDKManager.shared.myUserID() == userUID else { throw CancellationError() } }\n}\n'
(out/'ProductionNotificationRead.swift').write_text(prefix+load+method+request+suffix)
PY
QA_MAPPER=/Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay/SourcePackages/checkouts/ObjectMapper/Sources
swiftc -parse-as-library -emit-library -emit-module -module-name ObjectMapper "$QA_MAPPER/"*.swift -emit-module-path "$QA_OUT/ObjectMapper.swiftmodule" -o "$QA_OUT/libObjectMapper.dylib" 2> "$QA_OUT/mapper.log"
swiftc -parse-as-library -I "$QA_OUT" -L "$QA_OUT" -lObjectMapper -Xlinker -rpath -Xlinker "$QA_OUT" "$QA_ROOT/ddlNew/Features/Chat/Models/ChatFailureReason.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/SDKChatRequestWaiter.swift" "$QA_ROOT/ddlNew/Features/GroupApplications/Models/"*.swift "$QA_ROOT/ddlNew/Network/IM/GroupApplications/GroupApplicationPayload.swift" "$QA_ROOT/ddlNew/Network/IM/GroupApplications/GroupApplicationsPayload.swift" "$QA_OUT/ProductionNotificationRead.swift" "$QA_ROOT/Tests/MigrationAcceptance/NotificationReadChecks.swift" -o "$QA_OUT/checks"
"$QA_OUT/checks"
