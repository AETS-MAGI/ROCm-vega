#!/usr/bin/env bash
set -euo pipefail

DST_ROOT="${DST_ROOT:-/home/limonene/ROCm-project/WD-Black/ROCm-repos}"
BRANCH="${BRANCH:-main}"
PARALLEL="${PARALLEL:-4}"
DRY_RUN=0

# Default minimal set for current investigation workflow.
REPOS=(
  llvm-project
  rocMLIR
  rocm-libraries
  MIOpen
  rocBLAS
  Tensile
)

usage() {
  cat <<'USAGE'
Usage:
  bootstrap_rocm_repos_wdblack.sh [options]

Description:
  Clone selected ROCm repositories directly to WD-Black using shallow clone.
  Useful when CIFS->WD-Black rsync is too slow for initial setup.

Options:
  --repo <name>     Add repository name under github.com/ROCm/<name>.git
                    Repeatable. If specified, replaces default repo list.
  --branch <name>   Clone branch/tag (default: main)
  --parallel <N>    Parallel clone jobs (default: 4)
  --dry-run         Print planned commands only
  -h, --help        Show help

Environment variables:
  DST_ROOT          Destination root (default: /home/limonene/ROCm-project/WD-Black/ROCm-repos)
  BRANCH            Same as --branch
  PARALLEL          Same as --parallel

Examples:
  bash ./bootstrap_rocm_repos_wdblack.sh
  bash ./bootstrap_rocm_repos_wdblack.sh --repo llvm-project --repo rocm-libraries --repo rocMLIR
  BRANCH=rocm-7.2.0 bash ./bootstrap_rocm_repos_wdblack.sh --repo MIOpen
USAGE
}

CUSTOM_REPOS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      shift
      [[ $# -gt 0 ]] || { echo "error: --repo requires value" >&2; exit 2; }
      CUSTOM_REPOS+=("$1")
      ;;
    --branch)
      shift
      [[ $# -gt 0 ]] || { echo "error: --branch requires value" >&2; exit 2; }
      BRANCH="$1"
      ;;
    --parallel)
      shift
      [[ $# -gt 0 ]] || { echo "error: --parallel requires value" >&2; exit 2; }
      PARALLEL="$1"
      ;;
    --dry-run)
      DRY_RUN=1
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

if [[ ${#CUSTOM_REPOS[@]} -gt 0 ]]; then
  REPOS=("${CUSTOM_REPOS[@]}")
fi

if [[ "$DST_ROOT" != /home/limonene/ROCm-project/WD-Black/* ]]; then
  echo "error: destination must be under /home/limonene/ROCm-project/WD-Black" >&2
  echo "  current: $DST_ROOT" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git not found" >&2
  exit 1
fi

mkdir -p "$DST_ROOT"

echo "[bootstrap] destination: $DST_ROOT"
echo "[bootstrap] branch:      $BRANCH"
echo "[bootstrap] parallel:    $PARALLEL"
echo "[bootstrap] repos:       ${REPOS[*]}"

clone_one() {
  local repo="$1"
  local url="https://github.com/ROCm/${repo}.git"
  local dst="$DST_ROOT/$repo"

  if [[ -d "$dst/.git" ]]; then
    echo "[skip] $repo already exists: $dst"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] git clone --depth 1 --filter=blob:none --branch $BRANCH $url $dst"
    return 0
  fi

  echo "[clone] $repo"
  git clone --depth 1 --filter=blob:none --branch "$BRANCH" "$url" "$dst" || {
    echo "[warn] clone failed: $repo (branch=$BRANCH). trying default branch..." >&2
    git clone --depth 1 --filter=blob:none "$url" "$dst"
  }
}

export DST_ROOT BRANCH DRY_RUN
export -f clone_one

printf '%s\n' "${REPOS[@]}" | xargs -I{} -P "$PARALLEL" bash -lc 'clone_one "$@"' _ {}

echo "[bootstrap] done"
