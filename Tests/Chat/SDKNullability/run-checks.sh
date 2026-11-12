#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import re,sys
root,out=map(Path,sys.argv[1:])
h=(root/'NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMSDKManager+ChatMessage.h').read_text()
names=['toolGetOneChatMessageWithMessageID','toolGetOneChatMessageWithServiceMessageID','toolGetOneChatMessageWithServiceMessageIDExcludeDeleted']
methods=[re.search(r'^- .*'+n+r':.*;',h,re.M).group() for n in names]
(out/'Bridge.h').write_text('#import <Foundation/Foundation.h>\nNS_ASSUME_NONNULL_BEGIN\n@interface NoaIMChatMessageModel: NSObject\n@property NSInteger messageStatus;\n@end\n@interface NoaIMSDKManager: NSObject\n'+'\n'.join(methods)+'\n@end\nNS_ASSUME_NONNULL_END\n')
(out/'Bridge.m').write_text('#import "Bridge.h"\n@implementation NoaIMChatMessageModel\n@end\n@implementation NoaIMSDKManager\n'+'\n'.join(re.sub(r'nullable\s+', '', m[:-1])+' { return nil; }' for m in methods)+'\n@end\n')
PY
xcrun clang -fobjc-arc -c "$TMP_DIR/Bridge.m" -o "$TMP_DIR/Bridge.o"
for optimization in -Onone -O; do
 xcrun swiftc "$optimization" -parse-as-library -import-objc-header "$TMP_DIR/Bridge.h" "$ROOT_DIR/Tests/Chat/SDKNullability/Checks.swift" "$TMP_DIR/Bridge.o" -o "$TMP_DIR/checks"
 "$TMP_DIR/checks"
done
