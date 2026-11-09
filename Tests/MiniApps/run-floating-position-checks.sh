#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d /tmp/miniapp-floating.XXXXXX)"
trap 'rm -rf "$out"' EXIT
swiftc "$root/ddlNew/Features/MiniApps/Models/MiniAppFloatingPosition.swift" "$root/Tests/MiniApps/FloatingPositionChecks.swift" -o "$out/checks"
"$out/checks"
