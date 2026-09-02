#!/usr/bin/env bash
set -euo pipefail

: "${SLURM_VERSION:?SLURM_VERSION is required}"
: "${SLURM_SOURCE_BASE_URL:?SLURM_SOURCE_BASE_URL is required}"
: "${SLURM_SHA256:?SLURM_SHA256 is required}"
: "${SLURM_ARTIFACT_ROOT:?SLURM_ARTIFACT_ROOT is required}"
: "${SLURM_BUILD_ROOT:?SLURM_BUILD_ROOT is required}"

SLURM_SOURCE_URL="${SLURM_SOURCE_BASE_URL}/slurm-${SLURM_VERSION}.tar.bz2"
SLURM_ARTIFACT_DIR="${SLURM_ARTIFACT_ROOT}/${SLURM_VERSION}"
BUILD_VERSION_DIR="${SLURM_BUILD_ROOT}/${SLURM_VERSION}"
TARBALL_NAME="slurm-${SLURM_VERSION}.tar.bz2"
TARBALL_PATH="${BUILD_VERSION_DIR}/${TARBALL_NAME}"
SOURCE_DIR="${BUILD_VERSION_DIR}/slurm-${SLURM_VERSION}"
COMPLETE_MARKER="${SLURM_ARTIFACT_DIR}/.complete"

rm -rf "${BUILD_VERSION_DIR}"
rm -rf "${SLURM_ARTIFACT_DIR}"
mkdir -p "${BUILD_VERSION_DIR}"
mkdir -p "${SLURM_ARTIFACT_DIR}"

curl --fail --location --retry 3 --retry-delay 2 --output "${TARBALL_PATH}" "${SLURM_SOURCE_URL}"
SHA256_ACTUAL="$(sha256sum "${TARBALL_PATH}" | awk '{print $1}')"
if [ "${SHA256_ACTUAL}" != "${SLURM_SHA256}" ]; then
  echo "SHA256 mismatch for ${TARBALL_NAME}: expected ${SLURM_SHA256}, got ${SHA256_ACTUAL}" >&2
  exit 1
fi

tar -xjf "${TARBALL_PATH}" -C "${BUILD_VERSION_DIR}"

cd "${SOURCE_DIR}"

DEBIAN_FRONTEND=noninteractive mk-build-deps -i debian/control --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y'

debuild -b -uc -us -j"$(nproc)"

find "${BUILD_VERSION_DIR}" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.changes' -o -name '*.buildinfo' \) -exec cp {} "${SLURM_ARTIFACT_DIR}/" \;

required_packages=(
  slurm-smd
  slurm-smd-slurmctld
  slurm-smd-slurmd
  slurm-smd-slurmdbd
)

for required in "${required_packages[@]}"; do
  if ! ls "${SLURM_ARTIFACT_DIR}"/${required}_*.deb >/dev/null 2>&1; then
    echo "Required package not found: ${required}" >&2
    exit 1
  fi
done

(
  cd "${SLURM_ARTIFACT_DIR}"
  sha256sum -- *.deb > SHA256SUMS
)

: > "${COMPLETE_MARKER}"
