#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
python3 "$ROOT_DIR/Tests/Chat/SDKPushRejectionChecks.py"
python3 "$ROOT_DIR/Tests/Chat/SDKPushTransportChecks.py"
python3 "$ROOT_DIR/Tests/Chat/SDKPushRequestChecks.py"
