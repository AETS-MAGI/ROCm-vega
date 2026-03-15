#!/usr/bin/env bash
set -euo pipefail

DST_ROOT="${DST_ROOT:-/home/limonene/ROCm-project/WD-Black/ROCm-repos}"
if [[ -z "${SRC_ROOT:-}" ]]; then
  for _src_candidate in \
    "/mnt/tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo" \
    "/home/limonene/ROCm-project/tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo"; do
    if [[ -d "$_src_candidate" ]]; then
      SRC_ROOT="$_src_candidate"
      break
    fi
  done
fi
SRC_ROOT="${SRC_ROOT:-/home/limonene/ROCm-project/tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo}"
BRANCH="${BRANCH:-main}"
PARALLEL="${PARALLEL:-4}"
DRY_RUN=0
ALL_FROM_SOURCE=0

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
  --all-from-source Build repo list from top-level directories under SRC_ROOT.
  --branch <name>   Clone branch/tag (default: main)
  --parallel <N>    Parallel clone jobs (default: 4)
  --dry-run         Print planned commands only
  -h, --help        Show help

Environment variables:
  SRC_ROOT          Source root to read top-level repo names when --all-from-source
  DST_ROOT          Destination root (default: /home/limonene/ROCm-project/WD-Black/ROCm-repos)
  BRANCH            Same as --branch
  PARALLEL          Same as --parallel

Examples:
  bash ./bootstrap_rocm_repos_wdblack.sh
  bash ./bootstrap_rocm_repos_wdblack.sh --all-from-source
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
    --all-from-source)
      ALL_FROM_SOURCE=1
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

if [[ "$ALL_FROM_SOURCE" -eq 1 && ${#CUSTOM_REPOS[@]} -gt 0 ]]; then
  echo "error: --all-from-source and --repo cannot be used together" >&2
  exit 2
fi

if [[ "$ALL_FROM_SOURCE" -eq 1 ]]; then
  if [[ ! -d "$SRC_ROOT" ]]; then
    echo "error: source root not found: $SRC_ROOT" >&2
    exit 1
  fi
  REPOS=()
  mapfile -t _TOP_LEVEL_DIRS < <(find "$SRC_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  for top in "${_TOP_LEVEL_DIRS[@]}"; do
    top_path="$SRC_ROOT/$top"
    if git -C "$top_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      REPOS+=("$top")
      continue
    fi

    # Some entries (e.g., 00_DEPRECATED/00_RETIRED) are buckets containing nested repos.
    mapfile -t _NESTED_REPOS < <(find "$top_path" -mindepth 2 -maxdepth 2 -type d -name .git -printf '%h\n' | sed "s#^$SRC_ROOT/##" | sort)
    if [[ ${#_NESTED_REPOS[@]} -gt 0 ]]; then
      REPOS+=("${_NESTED_REPOS[@]}")
    fi
  done
elif [[ ${#CUSTOM_REPOS[@]} -gt 0 ]]; then
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
  local default_url="https://github.com/ROCm/${repo}.git"
  local url="$default_url"
  local dst="$DST_ROOT/$repo"
  local local_src="$SRC_ROOT/$repo"
  local local_git_repo=0
  local has_path=0

  if [[ "$repo" == */* ]]; then
    has_path=1
  fi

  if [[ -d "$local_src" ]] && git -C "$local_src" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local_git_repo=1
    # Prefer origin URL when available (supports non-standard repo names such as 00_DEPRECATED).
    local origin_url
    origin_url="$(git -C "$local_src" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$origin_url" ]]; then
      url="$origin_url"
    fi
  fi

  if [[ -d "$dst/.git" ]]; then
    echo "[skip] $repo already exists: $dst"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ "$has_path" -eq 1 ]]; then
    if [[ "$local_git_repo" -ne 1 ]]; then
      echo "[warn] nested repo path is not a git repo: $repo" >&2
      return 1
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] local:   git clone --single-branch --branch $BRANCH $local_src $dst"
      return 0
    fi
    echo "[clone-local] $repo"
    if git clone --single-branch --branch "$BRANCH" "$local_src" "$dst"; then
      return 0
    fi
    if git clone "$local_src" "$dst"; then
      return 0
    fi
    echo "[warn] clone skipped: $repo" >&2
    return 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] primary: git clone --depth 1 --filter=blob:none --branch $BRANCH $url $dst"
    if [[ "$local_git_repo" -eq 1 ]]; then
      echo "[dry-run] fallback: git clone --single-branch --branch $BRANCH $local_src $dst"
    fi
    return 0
  fi

  echo "[clone] $repo"
  if git clone --depth 1 --filter=blob:none --branch "$BRANCH" "$url" "$dst"; then
    return 0
  fi

  echo "[warn] clone failed: $repo (branch=$BRANCH, url=$url). trying default branch..." >&2
  if git clone --depth 1 --filter=blob:none "$url" "$dst"; then
    return 0
  fi

  if [[ "$local_git_repo" -eq 1 ]]; then
    echo "[warn] remote clone failed for $repo. trying local source clone: $local_src" >&2
    if git clone --single-branch --branch "$BRANCH" "$local_src" "$dst"; then
      return 0
    fi
    if git clone "$local_src" "$dst"; then
      return 0
    fi
  fi

  echo "[warn] clone skipped: $repo" >&2
  return 1
}

FAILED=()
for repo in "${REPOS[@]}"; do
  if ! clone_one "$repo"; then
    FAILED+=("$repo")
  fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "[bootstrap] skipped repos (${#FAILED[@]}): ${FAILED[*]}" >&2
fi

echo "[bootstrap] done"
