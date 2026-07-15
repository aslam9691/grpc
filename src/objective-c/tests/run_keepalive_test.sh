#!/bin/bash
# Copyright 2026 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

# --- begin runfiles.bash initialization ---
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

INTEROP_SERVER=$(rlocation "$RLOCATIONPATH_INTEROP_SERVER")
MACTESTS_ZIP=$(rlocation "$RLOCATIONPATH_MACTESTS_ZIP")

PORT_PLAIN=5252
PORT_TLS=5253

echo "Starting interop_server with --ack_pings=false on ports $PORT_PLAIN and $PORT_TLS..."
"$INTEROP_SERVER" --port=$PORT_PLAIN --max_send_message_size=8388608 --ack_pings=false &
PID1=$!
"$INTEROP_SERVER" --port=$PORT_TLS --max_send_message_size=8388608 --use_tls --ack_pings=false &
PID2=$!

cleanup() {
  echo "Stopping interop_server PIDs: $PID1 $PID2"
  kill -9 $PID1 $PID2 2>/dev/null || true
}
trap cleanup EXIT

sleep 1

TMPDIR=$(mktemp -d)
unzip -qq -o "$MACTESTS_ZIP" -d "$TMPDIR"
chmod -R 755 "$TMPDIR/MacTests.xctest"

export HOST_PORT_LOCAL="localhost:$PORT_PLAIN"
export HOST_PORT_LOCALSSL="localhost:$PORT_TLS"
export GRPC_RUN_KEEPALIVE_TEST="true"

XCTEST=$(xcrun --find xctest || echo "/Applications/Xcode.app/Contents/Developer/usr/bin/xctest")
"$XCTEST" \
  -XCTest "InteropTestsLocalCleartext/testKeepaliveWithV2API" \
  "$TMPDIR/MacTests.xctest"
