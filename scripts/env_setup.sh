#!/bin/bash
# ==============================================================================
# BeagleBone Black Cross-Compile Environment Setup
# Source this file in WSL: source scripts/env_setup.sh
# ==============================================================================

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export BBB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================="
echo " BBB Cross-Compile Environment Configured"
echo "================================================="
echo "ARCH           : $ARCH"
echo "CROSS_COMPILE  : $CROSS_COMPILE"
echo "PROJECT ROOT   : $BBB_DIR"
echo "Compiler Check :"

if command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
    ${CROSS_COMPILE}gcc --version | head -n 1
    echo "[OK] Cross-compiler is ready."
else
    echo "[FAIL] Cross-compiler not found in PATH."
    echo "       Run: sudo apt install gcc-arm-linux-gnueabihf"
fi
echo "================================================="
