#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sdk=NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule
# Compile the actual endpoint, dispatch and signing method; no account or server access.
sed -n '/^#define Transform_Qrcode_Content_Url /p' "$sdk/HttpRequest/NoaIMHttpManager+Group.h" > "$tmp/Route.inc"
sed -n '/^- (void)getScanQrContentTransformData:/,/^}/p' "$sdk/HttpRequest/NoaIMHttpManager+Group.m" > "$tmp/Dispatch.inc"
sed -n '/^- (NSString \*)getUrlSignature:/,/^}/p' "$sdk/HttpToTcpRequest/LingIMTcpRequestModel.m" > "$tmp/Signature.inc"
xcrun clang -fobjc-arc -framework Foundation -I"$tmp" Tests/Contacts/QRRouteChecks.m -o "$tmp/check"
"$tmp/check"
