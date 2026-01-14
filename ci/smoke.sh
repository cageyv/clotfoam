#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source_openfoam() {
  if command -v foamVersion >/dev/null 2>&1; then
    return 0
  fi

  # OpenFOAM bashrc scripts are not always compatible with `set -u` (nounset).
  # In particular, OpenFOAM v2412 references WM_PROJECT_SITE unguarded.
  # We temporarily disable nounset while sourcing.
  local had_nounset=0
  case "$-" in
    *u*) had_nounset=1 ;;
  esac

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
      set +u
      source "$f"
      if [[ "$had_nounset" == "1" ]]; then
        set -u
      fi
      return 0
    fi
  done

  echo "ERROR: Could not find an OpenFOAM bashrc to source." >&2
  return 1
}

source_openfoam

echo "OpenFOAM: $(foamVersion 2>/dev/null || true)"

if [[ ! -x "$repo_root/ci/build.sh" ]]; then
  echo "ERROR: ci/build.sh not found or not executable" >&2
  exit 1
fi

bash "$repo_root/ci/build.sh"

case_src="$repo_root/tutorials/rectangle2D"
if [[ ! -d "$case_src" ]]; then
  echo "ERROR: Expected tutorial case at $case_src" >&2
  exit 1
fi

artifacts_dir="${CI_ARTIFACTS_DIR:-$repo_root/.ci-artifacts}"
tmp_case="$artifacts_dir/case-rectangle2D"
rm -rf "$tmp_case"
mkdir -p "$tmp_case"

if [[ "${KEEP_CI_CASE:-0}" != "1" && "${CI:-0}" != "1" ]]; then
  trap 'rm -rf "$tmp_case"' EXIT
fi

cp -a "$case_src/." "$tmp_case/"

cd "$tmp_case"

# Make the case tiny and CI-stable
if command -v foamDictionary >/dev/null 2>&1; then
  foamDictionary -entry endTime -set 1e-4 system/controlDict >/dev/null
  foamDictionary -entry deltaT -set 1e-5 system/controlDict >/dev/null
  foamDictionary -entry writeControl -set timeStep system/controlDict >/dev/null
  foamDictionary -entry writeInterval -set 10 system/controlDict >/dev/null
  foamDictionary -entry functions -remove system/controlDict >/dev/null || true
fi

blockMesh > log.blockMesh 2>&1

clotFoam > log.clotFoam 2>&1

echo "Smoke run complete; latest time:"
ls -1d [0-9]* 2>/dev/null | tail -n 1 || true

