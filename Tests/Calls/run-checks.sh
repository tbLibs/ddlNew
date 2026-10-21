#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
swiftc ddlNew/Features/Calls/Models/CallContract.swift Tests/Calls/ContractChecks.swift -o "$tmp_dir/checks"
"$tmp_dir/checks"
