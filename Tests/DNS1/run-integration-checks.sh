#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
packages="${DNS1_PACKAGES:-/Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay/SourcePackages/checkouts}"
xcrun swiftc -parse-as-library -emit-library -emit-module -module-name ObjectMapper "$packages/ObjectMapper/Sources/"*.swift -emit-module-path "$tmp/ObjectMapper.swiftmodule" -o "$tmp/libObjectMapper.dylib" 2> "$tmp/mapper.log"
xcrun swiftc -parse-as-library -emit-library -emit-module -module-name SwiftProtobuf -package-name SwiftProtobuf "$packages/swift-protobuf/Sources/SwiftProtobuf/"*.swift -emit-module-path "$tmp/SwiftProtobuf.swiftmodule" -o "$tmp/libSwiftProtobuf.dylib" 2> "$tmp/protobuf.log" || { cat "$tmp/protobuf.log"; exit 1; }
sed '/^import NoaChatCore$/d' "$root/ddlNew/Network/DNS1/DNS1NodeRaceCoordinator.swift" > "$tmp/DNS1NodeRaceCoordinator.swift"
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
 -I "$tmp" -L "$tmp" -lObjectMapper -lSwiftProtobuf -Xlinker -rpath -Xlinker "$tmp" \
 "$root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$root/ddlNew/Protocols/Nav/Nav.pb.swift" \
 "$root/ddlNew/Network/DNS/DNSHostSource.swift" \
 "$root/ddlNew/Network/DNS1/DNS1Payload.swift" \
 "$root/ddlNew/Network/DNS1/DNS1SourceRace.swift" \
 "$root/ddlNew/Network/DNS1/DNS1CallbackWaiter.swift" "$tmp/DNS1NodeRaceCoordinator.swift" \
 "$root/ddlNew/Network/OSS/OSSNodeRaceCoordinator.swift" \
 "$root/ddlNew/Network/IM/IMNetworkNode.swift" \
 "$root/ddlNew/Network/OSS/OSSAuthResponseDecoder.swift" \
 "$root/ddlNew/Network/OSS/OSSNavigationRecord.swift" \
 "$root/ddlNew/Network/OSS/OSSNavigationStore.swift" \
 "$root/ddlNew/Network/OSS/OSSConnectionBootstrap.swift" \
 "$root/Tests/DNS1/DNS1IntegrationChecks.swift" -o "$tmp/checks"
"$tmp/checks"
