#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
node Tests/Localization/captcha-language-checks.js
python3 Tests/Localization/check_launch_resources.py
