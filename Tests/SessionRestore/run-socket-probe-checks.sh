#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
dir="$(mktemp -d /tmp/ddlNew-socket-probe.XXXXXX)"
trap 'rm -rf "$dir"' EXIT
sed -n '/^- (void)reconnectIfCurrentSocket:/,/^}/p' NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/Socket/TcpManager/NoaIMSocketManager.m > "$dir/Probe.inc"
xcrun clang -fobjc-arc -framework Foundation -I"$dir" Tests/SessionRestore/MessageSocketProbeChecks.m -o "$dir/checks"
"$dir/checks"
