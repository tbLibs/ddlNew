#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-mine-upload.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
python3 - "$task_root" "$task_output" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
s=(root/'ddlNew/Network/IM/Chat/SDKChatMediaClient.swift').read_text()
methods=[]
for marker in ['    private func bucketName(', '    private func checkPermission(']:
    start=s.index(marker); end=s.index('{', start)+1; depth=1
    while depth:
        depth+=(s[end]=='{')-(s[end]=='}');end+=1
    methods.append(s[start:end].replace('private func ', 'func '))
(out/'Production.swift').write_text('import Foundation\n@MainActor final class Policy {\n'+'\n'.join(methods)+'\n}')
PY
swiftc -swift-version 5 -parse-as-library "$task_root/ddlNew/Features/Chat/Models/ChatAttachment.swift" "$task_output/Production.swift" "$task_root/Tests/Mine/AvatarUploadPolicyChecks.swift" -o "$task_output/checks"
"$task_output/checks"
