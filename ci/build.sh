#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source_openfoam() {
  if command -v foamVersion >/dev/null 2>&1; then
    return 0
  fi

  local candidates=(
    "/opt/openfoam2412/etc/bashrc"
    "/usr/lib/openfoam/openfoam2412/etc/bashrc"
    "/opt/openfoam12/etc/bashrc"
    "/usr/lib/openfoam/openfoam12/etc/bashrc"
    "/usr/lib/openfoam/openfoam12/etc/bashrc"
    "/opt/openfoam/etc/bashrc"
    "$HOME/OpenFOAM/OpenFOAM-v2412/etc/bashrc"
    "$HOME/OpenFOAM/OpenFOAM-v12/etc/bashrc"
  )

  for f in "${candidates[@]}"; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      source "$f"
      return 0
    fi
  done

  echo "ERROR: Could not find an OpenFOAM bashrc to source." >&2
  return 1
}

source_openfoam

echo "OpenFOAM: $(foamVersion 2>/dev/null || true)"

cd "$repo_root/clotFoam"

if command -v wclean >/dev/null 2>&1; then
  wclean
fi

# wmake uses WM_NCOMPPROCS for parallelism (if supported)
export WM_NCOMPPROCS="${WM_NCOMPPROCS:-2}"
wmake

