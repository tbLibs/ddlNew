#!/bin/bash
set -euo pipefail
checks_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$checks_dir/run-data-checks.sh"
bash "$checks_dir/run-web-policy-checks.sh"
bash "$checks_dir/run-feature-checks.sh"
bash "$checks_dir/run-floating-position-checks.sh"
