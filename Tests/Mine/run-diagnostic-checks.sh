#!/bin/bash
localization_source="$(cd "$(dirname "$0")/../.." && pwd)/ddlNew/Common/Localization/L10n.swift"
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_output="$(mktemp -d /tmp/ddlNew-diagnostics.XXXXXX)"
trap 'rm -rf "$task_output"' EXIT
swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Network/DNS1/DNS1Payload.swift" \
 "$task_root/ddlNew/Network/DNS1/DNS1SourceRace.swift" \
 "$task_root/ddlNew/Features/Mine/Diagnostics/NetworkDiagnosticRunner.swift" \
 "$task_root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$task_root/Tests/Mine/NetworkDiagnosticChecks.swift" -o "$task_output/checks"
"$task_output/checks"
swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Common/Crypto/AesEncryptUtils.swift" \
 "$task_root/ddlNew/Network/DNS1/DNS1Payload.swift" \
 "$task_root/ddlNew/Network/DNS1/DNS1SourceRace.swift" \
 "$task_root/ddlNew/Network/DNS1/DNS1CallbackWaiter.swift" \
 "$task_root/ddlNew/Features/Mine/Diagnostics/NetworkDiagnosticRunner.swift" \
 "$task_root/ddlNew/Features/Mine/Diagnostics/InternetConnectivityCheck.swift" \
 "$task_root/ddlNew/Features/Mine/Diagnostics/NetworkDiagnosticStore.swift" \
 "$task_root/Tests/Mine/NetworkDiagnosticStoreChecks.swift" -o "$task_output/store-checks"
"$task_output/store-checks"

swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Features/Mine/Diagnostics/InternetConnectivityCheck.swift" \
 "$task_root/Tests/Mine/InternetConnectivityChecks.swift" -o "$task_output/internet-checks"
"$task_output/internet-checks"

swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Features/Mine/Components/NetworkDiagnosticStepState.swift" \
 "$task_root/Tests/Mine/NetworkDiagnosticPresentationChecks.swift" -o "$task_output/presentation-checks"
"$task_output/presentation-checks"

swiftc "$localization_source" -swift-version 5 -parse-as-library \
 "$task_root/ddlNew/Features/Mine/Components/NetworkDiagnosticAddress.swift" \
 "$task_root/Tests/Mine/NetworkDiagnosticAddressChecks.swift" -o "$task_output/address-checks"
"$task_output/address-checks"
