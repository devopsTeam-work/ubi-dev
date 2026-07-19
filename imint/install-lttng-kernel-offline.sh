#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------------
# install-lttng-kernel-offline.sh
#
# Purpose:
#   Select the correct pre-downloaded kernel-devel RPM based on the
#   host kernel version, install it inside the container, build the
#   LTTng kernel modules from the bundled source archive, install them
#   into /lib/modules/<kernel>, refresh module dependencies, and try
#   to load the main tracer module.
#
# Assumptions:
#   1. The container image already contains:
#        /opt/kernel_rpms/*.rpm
#        /opt/sources/lttng-modules-latest-2.13.tar.bz2
#   2. The container is run with:
#        --privileged
#        --pid=host
#        -v /lib/modules:/lib/modules
#   3. The running host kernel is one of the supported versions below.
#
# Why /lib/modules must be bind-mounted:
#   The container has its own filesystem view, but the kernel is the
#   host kernel. Mounting the host /lib/modules lets modules_install,
#   depmod, and modprobe operate on the host’s module tree.
# --------------------------------------------------------------------

KVER="$(uname -r)"
RPM_DIR="/opt/kernel_rpms"
SRC_ARCHIVE="/opt/sources/lttng-modules-latest-2.13.tar.bz2"

echo "Detected running kernel: ${KVER}"

# Select the matching bundled kernel-devel RPM.
case "${KVER}" in
  5.14.0-570.12.1.el9_6.x86_64)
    KERNEL_RPM="${RPM_DIR}/kernel-devel-5.14.0-570.12.1.el9_6.x86_64.rpm"
    ;;
  5.14.0-362.8.1.el9_3.x86_64)
    KERNEL_RPM="${RPM_DIR}/kernel-devel-5.14.0-362.8.1.el9_3.x86_64.rpm"
    ;;
  5.14.0-284.11.1.el9_2.x86_64)
    KERNEL_RPM="${RPM_DIR}/kernel-devel-5.14.0-284.11.1.el9_2.x86_64.rpm"
    ;;
  *)
    echo "ERROR: Unsupported kernel: ${KVER}"
    echo "Supported kernels:"
    echo "  - 5.14.0-570.12.1.el9_6.x86_64"
    echo "  - 5.14.0-362.8.1.el9_3.x86_64"
    echo "  - 5.14.0-284.11.1.el9_2.x86_64"
    exit 1
    ;;
esac

if [[ ! -f "${KERNEL_RPM}" ]]; then
  echo "ERROR: Missing bundled RPM: ${KERNEL_RPM}"
  exit 1
fi

if [[ ! -f "${SRC_ARCHIVE}" ]]; then
  echo "ERROR: Missing source archive: ${SRC_ARCHIVE}"
  exit 1
fi

echo "Installing matching kernel-devel RPM:"
echo "  ${KERNEL_RPM}"

# Install or upgrade the matching kernel-devel package in the container.
# This provides the build tree used by external kernel modules.
rpm -Uvh --replacepkgs "${KERNEL_RPM}"

BUILD_DIR="/lib/modules/${KVER}/build"
if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "ERROR: Expected build directory not found: ${BUILD_DIR}"
  echo "Check that /lib/modules from the host is mounted into the container."
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

cd "${TMPDIR}"

echo "Extracting LTTng kernel modules source..."
bzip2 -dc "${SRC_ARCHIVE}" | tar -xf -
cd lttng-modules-2.13.*

echo "Building LTTng kernel modules against ${KVER}..."
make -j"$(nproc)"

echo "Installing modules into /lib/modules/${KVER} ..."
make modules_install

echo "Refreshing module dependency metadata..."
depmod -a "${KVER}"

echo "Trying to load LTTng tracer module..."
modprobe lttng_tracer || true

echo "Done."
echo "Quick checks:"
echo "  ls -ld /lib/modules/${KVER}/build"
echo "  lsmod | grep lttng || true"
echo "  lttng list -k || true"