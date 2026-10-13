#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root/'ddlNew/Network/SystemConfig/SystemConfigService.swift').read_text()
for module in ['Moya', 'RxMoya', 'RxSwift']:
    source = source.replace('import ' + module + '\n', '')
(out/'SystemConfigService.swift').write_text(source)
PY
MAPPER=/Users/taobotaobo/Library/Developer/Xcode/DerivedData/ddlNew-gouvoiamsobqkuevngdfnxdlbzay/SourcePackages/checkouts/ObjectMapper/Sources
swiftc -parse-as-library -emit-library -emit-module -module-name ObjectMapper "$MAPPER/"*.swift -emit-module-path "$TMP_DIR/ObjectMapper.swiftmodule" -o "$TMP_DIR/libObjectMapper.dylib" 2> "$TMP_DIR/mapper.log"
swiftc -parse-as-library -I "$TMP_DIR" -L "$TMP_DIR" -lObjectMapper -Xlinker -rpath -Xlinker "$TMP_DIR" \
 "$ROOT_DIR/ddlNew/Network/SystemConfig/SystemConfigRecord.swift" "$TMP_DIR/SystemConfigService.swift" \
 "$ROOT_DIR/Tests/Network/SystemConfigTransportChecks.swift" -o "$TMP_DIR/checks"
"$TMP_DIR/checks"
