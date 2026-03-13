#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<'USAGE'
Usage:
  run_vega_path_case.sh CASE_ID -- <command...>

Example:
  run_vega_path_case.sh fp32_nchw_3x3_fwd_n32 -- \
    miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1

Optional environment variables:
  LOG_ROOT=~/vega_path_check_logs
  TARGET_HSACO=/path/to/kernel.hsaco
  LLVM_OBJDUMP=llvm-objdump
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

LOG_ROOT="${LOG_ROOT:-$HOME/vega_path_check_logs}"
mkdir -p "$LOG_ROOT"

log_file="$LOG_ROOT/${case_id}.log"
trace_extract="$LOG_ROOT/${case_id}.trace_extract.log"
solver_extract="$LOG_ROOT/${case_id}.solver_extract.log"
meta_file="$LOG_ROOT/${case_id}.meta.txt"
trace_map="$LOG_ROOT/${case_id}.trace_map.md"

# Fixed logging knobs for MIOpen path tracing.
export MIOPEN_ENABLE_LOGGING="${MIOPEN_ENABLE_LOGGING:-1}"
export MIOPEN_ENABLE_LOGGING_CMD="${MIOPEN_ENABLE_LOGGING_CMD:-1}"
export MIOPEN_LOG_LEVEL="${MIOPEN_LOG_LEVEL:-6}"

{
  echo "timestamp=$(date -Iseconds)"
  echo "hostname=$(hostname)"
  echo "pwd=$(pwd)"
  echo "case_id=$case_id"
  echo "command=$*"
  echo "MIOPEN_ENABLE_LOGGING=$MIOPEN_ENABLE_LOGGING"
  echo "MIOPEN_ENABLE_LOGGING_CMD=$MIOPEN_ENABLE_LOGGING_CMD"
  echo "MIOPEN_LOG_LEVEL=$MIOPEN_LOG_LEVEL"
} | tee "$meta_file"

# Run the target command and keep full output.
"$@" 2>&1 | tee "$log_file"

# Generic fallback/path extraction.
rg -n "Not applicable|Skipped \(non-dynamic\)|ConvMlirIgemm|ConvAsmImplicitGemm|ConvCkIgemm|Dlops|Xdlops|hipBlasLT failed, falling back to tensile|fall back to FP32|rocblas_gemm_tensile_backend|rocblas_gemm_hipblaslt_backend" "$log_file" \
  | tee "$trace_extract" || true

# Solver-focused extraction.
rg -n "ConvAsmImplicitGemm|ConvCkIgemm|ConvMlirIgemm|Dlops|Xdlops|Solver|FindSolution|Applicable|Success" "$log_file" \
  | tee "$solver_extract" || true

# Optional ISA check for dot4 traces.
if [[ -n "${TARGET_HSACO:-}" ]]; then
  objdump_bin="${LLVM_OBJDUMP:-llvm-objdump}"
  hsaco_s="$LOG_ROOT/${case_id}.hsaco.s"
  if command -v "$objdump_bin" >/dev/null 2>&1; then
    "$objdump_bin" -d "$TARGET_HSACO" > "$hsaco_s"
    rg -n "v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4" "$hsaco_s" \
      | tee "$LOG_ROOT/${case_id}.dot4_extract.log" || true
  else
    echo "warning: $objdump_bin not found; skipped hsaco disassembly" | tee -a "$meta_file"
  fi
fi

cat > "$trace_map" <<'EOF'
# TRACE MAP TEMPLATE

- case_id: CASE_ID_PLACEHOLDER
- status: fallback_confirmed / fallback_not_confirmed / need_more_cases

## 1. Observed Lines

- log: LOG_FILE_PLACEHOLDER
- extract: TRACE_EXTRACT_PLACEHOLDER

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| ConvMlirIgemm*: Not applicable |  | conv_mlir_igemm_fwd.cpp / bwd.cpp / wrw.cpp | 188 / 68 / 69 | gfx900 exclusion |
| ConvAsmImplicitGemm*: Not applicable |  | conv_asm_implicit_gemm_*_v4r1_dynamic.cpp | 293 / 343 / 142 / 306 | constraints not met, next solver tried |
| hipBlasLT failed, falling back to tensile |  | rocblas/library/src/tensile_host.cpp | 1232 | runtime fallback to Tensile |
| No Tensile solution found for XF32, fall back to FP32 |  | rocblas/library/src/tensile_host.cpp | 1161 | xF32 -> FP32 fallback |
| Skipped (non-dynamic) |  | include/miopen/find_solution.hpp | 324 / 449 | dynamic-only filter skip |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [ ] need_more_cases

## 4. Notes

- solver selected:
- kernel selected:
- dot4 instruction present:
- additional comments:
EOF

# Fill placeholders.
sed -i "s|CASE_ID_PLACEHOLDER|$case_id|g" "$trace_map"
sed -i "s|LOG_FILE_PLACEHOLDER|$log_file|g" "$trace_map"
sed -i "s|TRACE_EXTRACT_PLACEHOLDER|$trace_extract|g" "$trace_map"

echo "done:"
echo "  log:          $log_file"
echo "  trace:        $trace_extract"
echo "  solver:       $solver_extract"
echo "  trace_map:    $trace_map"
echo "  meta:         $meta_file"
