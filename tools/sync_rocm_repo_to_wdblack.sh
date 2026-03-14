#!/usr/bin/env bash
set -euo pipefail

SRC_ROOT="${SRC_ROOT:-/home/limonene/ROCm-project/tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo}"
DST_ROOT="${DST_ROOT:-/home/limonene/ROCm-project/WD-Black/ROCm-repos}"
DELETE_MODE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  sync_rocm_repo_to_wdblack.sh [--dry-run] [--delete]

Description:
  Mirror ROCm_AMD_Repo from CIFS source to WD-Black local storage.
  Recommended for fast rg/git/find operations on local NVMe.

Options:
  --dry-run   Show planned changes without writing.
  --delete    Delete files in destination that are absent in source.
  -h, --help  Show this help.

Environment variables:
  SRC_ROOT    Source repo root (default: tank/docs-ref/.../ROCm_AMD_Repo)
  DST_ROOT    Destination root (default: WD-Black/ROCm-repos)

Examples:
  bash ./tools/sync_rocm_repo_to_wdblack.sh
  bash ./tools/sync_rocm_repo_to_wdblack.sh --delete
  SRC_ROOT=/path/to/src DST_ROOT=/path/to/dst bash ./tools/sync_rocm_repo_to_wdblack.sh --dry-run
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --delete)
      DELETE_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "error: source not found: $SRC_ROOT" >&2
  exit 1
fi

if [[ "$DST_ROOT" != /home/limonene/ROCm-project/WD-Black/* ]]; then
  echo "error: destination must be under /home/limonene/ROCm-project/WD-Black" >&2
  echo "  current: $DST_ROOT" >&2
  exit 1
fi

mkdir -p "$DST_ROOT"

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync not found" >&2
  exit 1
fi

RSYNC_ARGS=(
  -aH
  --numeric-ids
  --info=stats2,progress2
  --human-readable
  --partial
  --mkpath
)

if [[ "$DELETE_MODE" -eq 1 ]]; then
  RSYNC_ARGS+=(--delete --delete-delay)
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_ARGS+=(--dry-run --itemize-changes)
fi

echo "[sync] source:      $SRC_ROOT"
echo "[sync] destination: $DST_ROOT"
echo "[sync] delete:      $DELETE_MODE"
echo "[sync] dry-run:     $DRY_RUN"

# Use trailing slashes to sync directory contents.
rsync "${RSYNC_ARGS[@]}" "$SRC_ROOT/" "$DST_ROOT/"

echo "[sync] done"
