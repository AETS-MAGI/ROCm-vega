#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat <<'USAGE'
Usage:
  build_miopen_debug_local.sh <miopen-source-dir>

Optional environment variables:
  MIOPEN_BUILD_ROOT=/tmp/miopen-debug-build
  MIOPEN_PREFIX=$HOME/local/miopen-debug
  HALF_INCLUDE_DIR=/usr/include
  ROCM_PATH=/opt/rocm
  ROCMLIR_PREFIX=$HOME/local/rocmlir
  rocMLIR_DIR=<path-to-rocMLIRConfig.cmake-directory>
  MIOPEN_USE_MLIR=On
  MIOPEN_USE_COMPOSABLEKERNEL=Off
  MIOPEN_USE_HIPBLASLT=Off
  MIOPEN_USE_ROCBLAS=On
  CMAKE_BUILD_TYPE=Debug
  CMAKE_GENERATOR=Ninja
  EXTRA_CMAKE_ARGS="..."

Example:
  MIOPEN_PREFIX=$HOME/local/miopen-debug \
  bash ./tools/build_miopen_debug_local.sh \
  /path/to/rocm-libraries/projects/miopen
USAGE
  exit 1
fi

SRC_DIR="$1"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: source dir not found: $SRC_DIR" >&2
  exit 1
fi

ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
WD_BLACK_ROOT="${WD_BLACK_ROOT:-/home/limonene/ROCm-project/WD-Black}"
if [[ -z "${MIOPEN_BUILD_ROOT:-}" ]]; then
  if mountpoint -q "$WD_BLACK_ROOT" && [[ -w "$WD_BLACK_ROOT" ]]; then
    MIOPEN_BUILD_ROOT="$WD_BLACK_ROOT/rocm-builds/miopen-debug-build"
  else
    MIOPEN_BUILD_ROOT="/tmp/miopen-debug-build"
  fi
fi
if [[ -z "${MIOPEN_PREFIX:-}" ]]; then
  if mountpoint -q "$WD_BLACK_ROOT" && [[ -w "$WD_BLACK_ROOT" ]]; then
    MIOPEN_PREFIX="$WD_BLACK_ROOT/rocm-builds/miopen-debug-prefix"
  else
    MIOPEN_PREFIX="$HOME/local/miopen-debug"
  fi
fi
HALF_INCLUDE_DIR="${HALF_INCLUDE_DIR:-}"
ROCMLIR_PREFIX="${ROCMLIR_PREFIX:-}"
MIOPEN_USE_MLIR="${MIOPEN_USE_MLIR:-On}"
MIOPEN_USE_COMPOSABLEKERNEL="${MIOPEN_USE_COMPOSABLEKERNEL:-Off}"
MIOPEN_USE_HIPBLASLT="${MIOPEN_USE_HIPBLASLT:-Off}"
MIOPEN_USE_ROCBLAS="${MIOPEN_USE_ROCBLAS:-On}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Debug}"
CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"
EXTRA_CMAKE_ARGS="${EXTRA_CMAKE_ARGS:-}"

if [[ -z "$HALF_INCLUDE_DIR" ]]; then
  for _half_base in \
    "/usr/include" \
    "/usr/local/include" \
    "$ROCM_PATH/include"; do
    if [[ -f "$_half_base/half/half.hpp" ]]; then
      HALF_INCLUDE_DIR="$_half_base"
      break
    fi
  done
fi

if [[ -z "$HALF_INCLUDE_DIR" ]]; then
  echo "warning: half/half.hpp was not found automatically; cmake may fail with HALF_INCLUDE_DIR-NOTFOUND" >&2
fi

if [[ -z "${rocMLIR_DIR:-}" && -n "$ROCMLIR_PREFIX" ]]; then
  for _rocmlir_cmake_dir in \
    "$ROCMLIR_PREFIX/lib/cmake/rocMLIR" \
    "$ROCMLIR_PREFIX/lib/cmake/rocmlir"; do
    if [[ -d "$_rocmlir_cmake_dir" ]]; then
      rocMLIR_DIR="$_rocmlir_cmake_dir"
      break
    fi
  done
fi

if [[ -x "$ROCM_PATH/llvm/bin/clang++" ]]; then
  export CXX="$ROCM_PATH/llvm/bin/clang++"
fi

mkdir -p "$MIOPEN_BUILD_ROOT" "$MIOPEN_PREFIX"
cd "$MIOPEN_BUILD_ROOT"

cmake -G "$CMAKE_GENERATOR" \
  -DMIOPEN_BACKEND=HIP \
  -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
  -DCMAKE_INSTALL_PREFIX="$MIOPEN_PREFIX" \
  -DCMAKE_PREFIX_PATH="$ROCM_PATH;$ROCM_PATH/hip;$MIOPEN_PREFIX${ROCMLIR_PREFIX:+;$ROCMLIR_PREFIX}" \
  -DMIOPEN_USE_MLIR="$MIOPEN_USE_MLIR" \
  -DMIOPEN_USE_COMPOSABLEKERNEL="$MIOPEN_USE_COMPOSABLEKERNEL" \
  -DMIOPEN_USE_HIPBLASLT="$MIOPEN_USE_HIPBLASLT" \
  -DMIOPEN_USE_ROCBLAS="$MIOPEN_USE_ROCBLAS" \
  -DBUILD_DEV=On \
  ${HALF_INCLUDE_DIR:+-DHALF_INCLUDE_DIR=$HALF_INCLUDE_DIR} \
  ${rocMLIR_DIR:+-DrocMLIR_DIR=$rocMLIR_DIR} \
  $EXTRA_CMAKE_ARGS \
  "$SRC_DIR"

cmake --build . --target MIOpen MIOpenDriver -j"$(nproc)"
cmake --build . --target install

echo "done: local debug MIOpen installed"
echo "  build:  $MIOPEN_BUILD_ROOT"
echo "  prefix: $MIOPEN_PREFIX"
echo "  HALF_INCLUDE_DIR: ${HALF_INCLUDE_DIR:-<auto-not-found>}"
echo "  rocMLIR_DIR: ${rocMLIR_DIR:-<auto-not-found>}"
echo "  driver: $MIOPEN_BUILD_ROOT/bin/MIOpenDriver"
