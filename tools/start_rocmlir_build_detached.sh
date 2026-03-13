#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat <<'USAGE'
Usage:
  start_rocmlir_build_detached.sh <rocmlir-source-dir>

Optional environment variables:
  ROCMLIR_BUILD_ROOT=<path>
  ROCMLIR_PREFIX=<path>
  CMAKE_GENERATOR=Ninja|Unix Makefiles
  EXTRA_CMAKE_ARGS="..."

This launcher starts build_rocmlir_local.sh with nohup and prints:
- PID
- LOG file path
USAGE
  exit 1
fi

SRC_DIR="$1"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y%m%d_%H%M%S)"

ROCMLIR_BUILD_ROOT="${ROCMLIR_BUILD_ROOT:-/tmp/rocmlir-build-detached-$TS}"
ROCMLIR_PREFIX="${ROCMLIR_PREFIX:-$BASE_DIR/tmp/rocmlir-prefix-detached-$TS}"
CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"
LOG_FILE="$BASE_DIR/tmp/rocmlir_build_detached_$TS.log"

mkdir -p "$ROCMLIR_BUILD_ROOT" "$ROCMLIR_PREFIX" "$BASE_DIR/tmp"

nohup env \
  ROCMLIR_BUILD_ROOT="$ROCMLIR_BUILD_ROOT" \
  ROCMLIR_PREFIX="$ROCMLIR_PREFIX" \
  CMAKE_GENERATOR="$CMAKE_GENERATOR" \
  EXTRA_CMAKE_ARGS="${EXTRA_CMAKE_ARGS:-}" \
  bash "$BASE_DIR/tools/build_rocmlir_local.sh" "$SRC_DIR" \
  >"$LOG_FILE" 2>&1 &

PID=$!
echo "PID=$PID"
echo "LOG=$LOG_FILE"
echo "ROCMLIR_PREFIX=$ROCMLIR_PREFIX"
