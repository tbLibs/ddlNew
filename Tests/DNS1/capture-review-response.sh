#!/bin/bash
set -euo pipefail
umask 077
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="${1:?Pass output JSON file path; invitation code is read from standard input}"
if [[ -e "$output" ]]; then
  echo 'Output exists; choose a new capture filename.' >&2
  exit 1
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rg '^nonisolated let dns1' "$root/ddlNew/Configuration/Const.swift" > "$tmp/Constants.swift"
if ! xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
  "$tmp/Constants.swift" \
  "$root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
  "$root/ddlNew/Network/DNS1/DNS1Payload.swift" \
  "$root/ddlNew/Network/DNS1/DNS1DoHClient.swift" \
  "$root/Tests/DNS1/DNS1ReviewCapture.swift" -o "$tmp/capture" > "$tmp/compiler.log" 2>&1; then
  echo 'Capture tool compilation failed; compiler output withheld because it may contain configuration values.' >&2
  exit 1
fi
if [[ -t 0 ]]; then
  read -r -s -p 'Review invitation code: ' review_invitation
  printf '\n' >&2
  printf '%s\n' "$review_invitation" | "$tmp/capture" > "$tmp/result.json"
  unset review_invitation
else
  "$tmp/capture" > "$tmp/result.json"
fi
python3 - "$root" "$tmp/result.json" "$output" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root, source, output = map(pathlib.Path, sys.argv[1:])
data = json.loads(source.read_text())
data['source_revision'] = subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
names = ['ddlNew/Network/DNS1/DNS1Payload.swift', 'ddlNew/Network/DNS1/DNS1DoHClient.swift',
         'ddlNew/Common/Crypto/AesEncryptUtils.swift', 'Tests/DNS1/DNS1ReviewCapture.swift',
         'Tests/DNS1/capture-review-response.sh']
data['source_sha256'] = {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in names}
data['submitted_version_developer_confirmed'] = '1.0.0 (1)'
data['binary_mapping'] = 'Not independently verified against the submitted IPA.'
with output.open('x') as f:
    json.dump(data,f,indent=2,ensure_ascii=False)
    f.write('\n')
print('Saved sanitized live capture. No raw response or lookup credentials persisted.')
PY
