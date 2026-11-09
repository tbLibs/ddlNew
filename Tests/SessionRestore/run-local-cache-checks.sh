#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
dir="$(mktemp -d /tmp/ddlNew-local-cache.XXXXXX)"
trap 'rm -rf "$dir"' EXIT
sed -n '/^- (BOOL)readLocalUserDatabase:/,/^}/p' NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager.mm > "$dir/LocalDatabase.inc"
xcrun clang -fobjc-arc -framework Foundation -I"$dir" Tests/SessionRestore/LocalConversationDatabaseChecks.m -o "$dir/checks"
"$dir/checks"
sed -n -e '/^- (BOOL)openLocalSnapshotForUserID:/,/^}/p' -e '/^- (void)closeLocalSnapshot/,/^}/p' -e '/^- (BOOL)isTableStateOkWithName:/,/^}/p' NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/DataBaseModule/NoaIMDBTool.mm > "$dir/SnapshotOpen.inc"
xcrun clang -fobjc-arc -framework Foundation -I"$dir" Tests/SessionRestore/LocalDatabaseOpenChecks.m -o "$dir/open-checks"
"$dir/open-checks"
