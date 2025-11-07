#!/usr/bin/env bash
# Reset the repo to the minimal skeleton:
#   Keep: docker-compose.yml, .env, .zephyr-build.env, .gitignore, README.md,
#         manifest/ (entire dir), scripts/ (entire dir), .github/ (by default), .git (always)
#   Remove: everything else, including app/, build/, var/, zephyr/, modules/, tools/,
#           bootloader/, .west*, twister-out*, .meta, etc.
#
# Usage:
#   scripts/unbootstrap_hard.sh [--yes|-y] [--dry-run] [--remove-ci]
#     --remove-ci  also remove .github
#     --yes|-y     no prompt
#     --dry-run    show what would be removed (no changes)
#

set -Eeuo pipefail
IFS=$'\n\t'

YES=0
DRY=0
REMOVE_CI=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-ci) REMOVE_CI=1 ;;
    --yes|-y)    YES=1 ;;
    --dry-run)   DRY=1 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^#\s\{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# Resolve repo root (parent of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Portable canonicalizer that accepts non-existent paths.
canon() {
  local p="$1"
  case "$p" in /*) ;; *) p="${PWD}/$p" ;; esac
  local IFS='/' comp
  local out=()  # simple stack (bash 3.2 compatible)
  for comp in $p; do
    case "$comp" in
      ''|'.') : ;;
      '..')   [[ ${#out[@]} -gt 0 ]] && unset 'out[${#out[@]}-1]' ;;
      *)      out+=("$comp") ;;
    esac
  done
  if [[ ${#out[@]} -eq 0 ]]; then
    printf '/\n'
  else
    printf '/%s\n' "$(IFS=/; echo "${out[*]}")"
  fi
}

# Basic sanity: looks like our project?
[[ -d "${ROOT}/scripts" && -f "${ROOT}/docker-compose.yml" && -d "${ROOT}/manifest" ]] || {
  echo "Error: not at project root: ${ROOT}" >&2; exit 1; }

# Keep list (absolute)
KEEP=(
  "${ROOT}/docker-compose.yml"
  "${ROOT}/.env"
  "${ROOT}/.zephyr-build.env"
  "${ROOT}/.gitignore"
  "${ROOT}/README.md"
  "${ROOT}/manifest"
  "${ROOT}/scripts"
  "${ROOT}/.git"        # NEVER removed
)
[[ "${REMOVE_CI}" -eq 0 ]] && KEEP+=("${ROOT}/.github")

# Normalize keep paths
KEEP_NORM=()
for p in "${KEEP[@]}"; do
  KEEP_NORM+=( "$(canon "${p}")" )
done

# Helper: is path under any kept path?
is_kept() {
  local rp="$(canon "$1")"
  local k
  for k in "${KEEP_NORM[@]}"; do
    [[ "$rp" == "$k" || "$rp" == "$k/"* ]] && return 0
  done
  return 1
}

# List top-level entries (include dotfiles; skip . and ..)
shopt -s dotglob nullglob
TOP=( "${ROOT}/"* "${ROOT}"/.* )
TMP=()
for e in "${TOP[@]}"; do
  base="$(basename "$e")"
  [[ "$base" == "." || "$base" == ".." ]] && continue
  TMP+=( "$e" )
done
TOP=( "${TMP[@]}" )

# Start with everything top-level that's not kept
TO_RM=()
for p in "${TOP[@]}"; do
  is_kept "$p" || TO_RM+=( "$p" )
done

# Add common fetched/generated paths explicitly
EXTRA_RM=(
  "${ROOT}/app"
  "${ROOT}/build"
  "${ROOT}/.meta"
  "${ROOT}/var"
  "${ROOT}/zephyr"
  "${ROOT}/modules"
  "${ROOT}/tools"
  "${ROOT}/bootloader"
  "${ROOT}/.west"
  "${ROOT}/.west_modules"
  "${ROOT}/twister-out"
  "${ROOT}/twister-out"*
)
for p in "${EXTRA_RM[@]}"; do
  for g in $p; do
    [[ -e "$g" ]] || continue
    is_kept "$g" || TO_RM+=( "$g" )
  done
done

# De-duplicate without associative arrays (portable for bash 3.2)
TO_RM_UNIQ=()
SEEN=""  # accumulate canonical paths sep by |
for p in "${TO_RM[@]}"; do
  rp="$(canon "$p")"
  case "|$SEEN|" in
    *"|$rp|"*) : ;;
    *) SEEN="${SEEN}|${rp}"; TO_RM_UNIQ+=( "$p" ) ;;
  esac
done
TO_RM=( "${TO_RM_UNIQ[@]}" )

if [[ ${#TO_RM[@]} -eq 0 ]]; then
  echo "[unbootstrap-hard] Nothing to remove. Already minimal."
  exit 0
fi

echo "[unbootstrap-hard] Will remove:"
for p in "${TO_RM[@]}"; do
  echo "  - ${p#${ROOT}/}"
done

[[ "${DRY}" -eq 1 ]] && { echo "[unbootstrap-hard] (dry-run) No changes made."; exit 0; }

if [[ "${YES}" -ne 1 ]]; then
  read -r -p "Proceed? [y/N] " ans
  case "$ans" in [yY]|[yY][eE][sS]) ;; *) echo "Aborted."; exit 1 ;; esac
fi

# Remove (BSD/GNU compatible), with hard guard for .git
for p in "${TO_RM[@]}"; do
  rp="$(canon "$p")"

  # NEVER remove the Git repository itself
  case "$rp" in
    "${ROOT}/.git"| "${ROOT}/.git/"*)
      echo "[unbootstrap-hard] refusing to remove .git"
      continue
      ;;
  esac

  # Extra safety
  [[ "$rp" == "${ROOT}" || "$rp" == "/" ]] && { echo "Skipping suspicious path: $p" >&2; continue; }

  case "$rp" in
    "${ROOT}"/*)
      rm -rf --one-file-system -- "$p" 2>/dev/null || rm -rf -- "$p"
      echo "[unbootstrap-hard] removed ${p#${ROOT}/}"
      ;;
    *)
      echo "Skipping outside-root path: $p" >&2
      ;;
  esac
done

echo "[unbootstrap-hard] Done. Remaining skeleton:"
printf "  - %s\n" \
  "docker-compose.yml" ".env" ".zephyr-build.env" ".gitignore" "README.md" \
  "manifest/" "scripts/" ".git$( [[ ${REMOVE_CI} -eq 0 ]] && echo ', .github/' )"
echo "[unbootstrap-hard] To re-initialize:  docker compose run --rm bootstrap"
