#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
swiftc -swift-version 5 ddlNew/Configuration/LocalMessagingSettings.swift ddlNew/Features/Calls/Models/CallContract.swift ddlNew/Features/Calls/Models/CallSession.swift ddlNew/Features/Calls/Services/CallClient.swift ddlNew/Features/Calls/Services/CallConfigurationStore.swift ddlNew/Features/Calls/Services/CallCoordinator.swift Tests/Calls/StateChecks.swift -o "$tmp_dir/checks"
"$tmp_dir/checks"
