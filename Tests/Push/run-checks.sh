#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
cd "$(dirname "$0")/../.."
folder=$(mktemp -d /tmp/ddlNew-push-checks.XXXXXX)
trap 'rm -rf "$folder"' EXIT
swiftc "$localization_source" -swift-version 5 ddlNew/Features/Notifications/PushModels.swift Tests/Push/PushPolicyChecks.swift -o "$folder/policy"
"$folder/policy"
swiftc "$localization_source" -swift-version 5 ddlNew/Features/Notifications/PushModels.swift ddlNew/Features/Notifications/PushCoordinator.swift Tests/Push/PushCoordinatorChecks.swift -o "$folder/coordinator"
"$folder/coordinator"

swiftc "$localization_source" -swift-version 5 ddlNew/Features/Notifications/PushRequestLane.swift Tests/Push/PushTransportChecks.swift -o "$folder/transport"
"$folder/transport"
