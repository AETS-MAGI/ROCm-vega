#!/usr/bin/env bash
set -euo pipefail

WD_REPO_ROOT="${WD_REPO_ROOT:-/home/limonene/ROCm-project/WD-Black/ROCm-repos}"

usage() {
  cat <<'USAGE'
Usage:
  bash open_wdblack_rocm_shell.sh [--print] [--cmd <command...>]

Description:
  Open a shell at WD-Black ROCm repo root.

Options:
  --print           Print resolved repo root and exit.
  --cmd <command>   Run command in repo root and exit.
  -h, --help        Show this help.

Environment variables:
  WD_REPO_ROOT      Override destination root.
USAGE
}

if [[ ! -d "$WD_REPO_ROOT" ]]; then
  echo "error: WD repo root not found: $WD_REPO_ROOT" >&2
  exit 1
fi

case "${1:-}" in
  --print)
    echo "$WD_REPO_ROOT"
    exit 0
    ;;
  --cmd)
    shift
    if [[ $# -eq 0 ]]; then
      echo "error: --cmd requires command arguments" >&2
      exit 2
    fi
    (
      cd "$WD_REPO_ROOT"
      "$@"
    )
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    cd "$WD_REPO_ROOT"
    echo "[wdblack] entering shell at: $WD_REPO_ROOT"
    exec "${SHELL:-/bin/bash}"
    ;;
  *)
    echo "error: unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
esac
