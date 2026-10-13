#!/bin/sh
# 编译原媒体codec、云签名及STS模型，所有输入均为虚构离线fixture。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_TEMP=$(mktemp -d /tmp/ddlNew-qa-transport.XXXXXX)
trap 'rm -rf "$QA_TEMP"' EXIT
QA_MAPPER=/Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay/SourcePackages/checkouts/ObjectMapper/Sources
swiftc -parse-as-library -emit-library -emit-module -module-name ObjectMapper "$QA_MAPPER/"*.swift -emit-module-path "$QA_TEMP/ObjectMapper.swiftmodule" -o "$QA_TEMP/libObjectMapper.dylib" 2> "$QA_TEMP/mapper.log"
swiftc -parse-as-library -I "$QA_TEMP" -L "$QA_TEMP" -lObjectMapper -Xlinker -rpath -Xlinker "$QA_TEMP" "$QA_ROOT/ddlNew/Common/Media/LegacyChatMediaCodec.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/Cloud/CloudStorageProvider.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/Cloud/CloudMediaCredentials.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/Cloud/CloudMediaCredentialPayload.swift" "$QA_ROOT/ddlNew/Network/IM/Chat/Cloud/CloudRequestSigner.swift" "$QA_ROOT/Tests/MigrationAcceptance/TransportAdversarialChecks.swift" -o "$QA_TEMP/checks"
"$QA_TEMP/checks"
