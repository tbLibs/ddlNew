#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/ddlNew-contacts-waiter-checks.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc -swift-version 5 "$root/ddlNew/Features/Contacts/Services/ContactRequestVersions.swift" "$root/ddlNew/Features/Contacts/Services/ContactProfileRequestGate.swift" "$root/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" "$root/ddlNew/Network/IM/Contacts/ContactBusinessRequestWaiter.swift" "$root/Tests/Contacts/ContactRequestWaiterChecks.swift" -o "$out/checks"
"$out/checks"
