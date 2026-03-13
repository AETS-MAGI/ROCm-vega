#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  cat <<'USAGE'
Usage:
  run_vega_path_case_miir_trace.sh CASE_ID -- <command...>

Example:
  run_vega_path_case_miir_trace.sh vega64_int8_force_mlir_fwd_trace -- \
    MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -S ConvMlirIgemmFwd -F 1 -t 1
USAGE
  exit 1
fi

case_id="$1"
shift

if [[ "$1" != "--" ]]; then
  echo "error: expected '--' before command" >&2
  exit 1
fi
shift

if [[ $# -eq 0 ]]; then
  echo "error: missing command after '--'" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/miir_trace_build"
PRELOAD_SO="$BUILD_DIR/libmiir_trace.so"
TRACE_SRC="$SCRIPT_DIR/tools/miir_preload_trace.c"

mkdir -p "$BUILD_DIR"
cc -shared -fPIC -O2 -Wall -Wextra -o "$PRELOAD_SO" "$TRACE_SRC" -ldl

echo "[miir-trace] built: $PRELOAD_SO"

echo "[miir-trace] running case: $case_id"
bash "$SCRIPT_DIR/run_vega_path_case.sh" "$case_id" -- env \
  LD_PRELOAD="$PRELOAD_SO${LD_PRELOAD:+:$LD_PRELOAD}" \
  "$@"

LOG_ROOT="${LOG_ROOT:-$HOME/vega_path_check_logs}"
LOG_FILE="$LOG_ROOT/${case_id}.log"

echo "[miir-trace] MIIR trace excerpts from: $LOG_FILE"
rg -n "\[MIIR_TRACE\]" "$LOG_FILE" | head -n 120 || true
