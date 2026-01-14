#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source_openfoam() {
  if command -v foamVersion >/dev/null 2>&1; then
    return 0
  fi

  # OpenFOAM bashrc scripts are not always compatible with strict bash flags.
  # Temporarily relax flags while sourcing.

  local candidates=(
    "/opt/openfoam-dev/etc/bashrc"
    "/usr/lib/openfoam/openfoam-dev/etc/bashrc"
    "/opt/openfoam2412/etc/bashrc"
    "/usr/lib/openfoam/openfoam2412/etc/bashrc"
    "/opt/openfoam12/etc/bashrc"
    "/usr/lib/openfoam/openfoam12/etc/bashrc"
    "/opt/openfoam/etc/bashrc"
    "$HOME/OpenFOAM/OpenFOAM-v2412/etc/bashrc"
    "$HOME/OpenFOAM/OpenFOAM-v12/etc/bashrc"
  )

  for f in "${candidates[@]}"; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      set +e +u +o pipefail
      source "$f"
      local rc=$?
      set -euo pipefail
      if [[ "$rc" != "0" ]]; then
        echo "ERROR: Failed to source OpenFOAM bashrc: $f" >&2
        return 1
      fi
      # Sanity check: in some environments a bashrc may exist but point to an
      # incomplete/non-existent OpenFOAM tree (e.g. missing headers under
      # $FOAM_SRC), causing wmake include paths like /opt/openfoam12/src/... that
      # don't resolve.
      if command -v foamVersion >/dev/null 2>&1; then
        local fv_cfd_h=""
        if [[ -n "${FOAM_SRC:-}" ]]; then
          if [[ -f "$FOAM_SRC/finiteVolume/lnInclude/fvCFD.H" ]]; then
            fv_cfd_h="$FOAM_SRC/finiteVolume/lnInclude/fvCFD.H"
          elif [[ -f "$FOAM_SRC/OpenFOAM/lnInclude/fvCFD.H" ]]; then
            fv_cfd_h="$FOAM_SRC/OpenFOAM/lnInclude/fvCFD.H"
          fi
        fi

        if [[ -n "$fv_cfd_h" ]]; then
          return 0
        fi
      fi

      echo "WARN: Sourced OpenFOAM bashrc but headers not found (skipping): $f" >&2
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

