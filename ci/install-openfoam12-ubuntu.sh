#!/usr/bin/env bash
set -euo pipefail

# Installs OpenFOAM v12 using OpenFOAM.org Ubuntu packages
# Ref: https://openfoam.org/download/12-ubuntu/

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
if [[ -z "$codename" ]]; then
  codename="$(lsb_release -cs 2>/dev/null || true)"
fi
if [[ -z "$codename" ]]; then
  echo "ERROR: Cannot determine Ubuntu codename" >&2
  exit 1
fi

$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends ca-certificates gnupg curl lsb-release

# Add OpenFOAM.org repo + key
$SUDO install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://dl.openfoam.org/gpg.key | $SUDO gpg --dearmor -o /etc/apt/keyrings/openfoam.gpg
$SUDO chmod a+r /etc/apt/keyrings/openfoam.gpg

echo "deb [signed-by=/etc/apt/keyrings/openfoam.gpg] https://dl.openfoam.org/ubuntu ${codename} main" | \
  $SUDO tee /etc/apt/sources.list.d/openfoam.list >/dev/null

$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends openfoam12

echo "Installed OpenFOAM v12."

