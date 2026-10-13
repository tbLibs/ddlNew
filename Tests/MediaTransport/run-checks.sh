#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
swiftc -parse-as-library "$task_root/ddlNew/Common/Media/LegacyChatMediaCodec.swift" \
 "$task_root/Tests/MediaTransport/CodecChecks.swift" -o "$task_temp/codec"
"$task_temp/codec"
swiftc -parse-as-library "$task_root/ddlNew/Network/IM/Chat/Cloud/CloudStorageProvider.swift" \
 "$task_root/ddlNew/Network/IM/Chat/Cloud/CloudMediaCredentials.swift" \
 "$task_root/ddlNew/Network/IM/Chat/Cloud/CloudRequestSigner.swift" \
 "$task_root/Tests/MediaTransport/SigningChecks.swift" -o "$task_temp/signing"
"$task_temp/signing"
