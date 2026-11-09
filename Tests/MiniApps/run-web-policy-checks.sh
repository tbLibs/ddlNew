#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc ddlNew/Features/MiniApps/Browser/MiniAppWebPolicy.swift Tests/MiniApps/WebPolicyChecks.swift -o "$out/checks"
"$out/checks"
