#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  cat <<'USAGE'
Usage:
  run_case_with_local_miopen.sh <miopen-prefix> <case_id> -- <command...>

Example:
  ./tools/run_case_with_local_miopen.sh $HOME/local/miopen-debug vega64_int8_local_dbg -- \
    MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 \
    -S ConvMlirIgemmFwd -F 1 -t 1
USAGE
  exit 1
fi

MIOPEN_PREFIX="$1"
CASE_ID="$2"
shift 2

if [[ "$1" != "--" ]]; then
  echo "error: expected '--' before command" >&2
  exit 1
fi
shift

if [[ $# -eq 0 ]]; then
  echo "error: missing command after '--'" >&2
  exit 1
fi

if [[ ! -d "$MIOPEN_PREFIX/lib" ]]; then
  echo "error: not found: $MIOPEN_PREFIX/lib" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Prefer local MIOpen while keeping ROCm default libs reachable.
export LD_LIBRARY_PATH="$MIOPEN_PREFIX/lib:${LD_LIBRARY_PATH:-}:/opt/rocm/lib:/opt/rocm/lib64"

# Keep cache and user db in local tree so repeated runs stay reproducible.
export MIOPEN_CACHE_DIR="${MIOPEN_CACHE_DIR:-$ROOT_DIR/tmp/miopen_cache}"
export MIOPEN_USER_DB_PATH="${MIOPEN_USER_DB_PATH:-$ROOT_DIR/tmp/miopen_userdb}"
mkdir -p "$MIOPEN_CACHE_DIR" "$MIOPEN_USER_DB_PATH"

# Help disambiguate which runtime was used in logs.
export MIOPEN_ENABLE_LOGGING="${MIOPEN_ENABLE_LOGGING:-1}"
export MIOPEN_ENABLE_LOGGING_CMD="${MIOPEN_ENABLE_LOGGING_CMD:-1}"
export MIOPEN_LOG_LEVEL="${MIOPEN_LOG_LEVEL:-6}"

echo "[local-miopen] prefix=$MIOPEN_PREFIX"
echo "[local-miopen] LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

bash "$ROOT_DIR/run_vega_path_case.sh" "$CASE_ID" -- "$@"
