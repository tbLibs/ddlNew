#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src=NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/Socket/TcpManager/NoaIMSocketManager.m
# Compile the production callbacks with a controllable key generator and socket.
sed -n '/^- (void)startKeyExchangeProcess {/,/^}/p; /^- (void)handleKeyExchangeFailure/,/^}/p; /^- (void)forceDisconnectSocket {/,/^}/p; /^- (void)startKeyExchangeTimer {/,/^}/p; /^- (void)stopKeyExchangeTimer {/,/^}/p' "$src" > "$tmp/Callbacks.inc"
xcrun clang -fobjc-arc -framework Foundation -framework Security -I"$tmp" Tests/Network/ECDHCallbackChecks.m -o "$tmp/check"
"$tmp/check"
