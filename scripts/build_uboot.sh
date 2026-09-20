#!/bin/bash
# ==============================================================================
# BeagleBone Black U-Boot Automated Build Script
# Usage: ./scripts/build_uboot.sh
# ==============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTLOADER_DIR="$PROJECT_ROOT/bootloader"
UBOOT_SRC="$BOOTLOADER_DIR/u-boot"
ARTIFACTS_DIR="$BOOTLOADER_DIR/artifacts"
UBOOT_TAG="v2024.01"

echo "=========================================================="
echo " [Phase 2] Building U-Boot for BeagleBone Black (AM335x)"
echo " Project Root : $PROJECT_ROOT"
echo " U-Boot Branch: $UBOOT_TAG"
echo "=========================================================="

mkdir -p "$BOOTLOADER_DIR" "$ARTIFACTS_DIR"

# 1. Clone U-Boot if not present
if [ ! -d "$UBOOT_SRC/.git" ]; then
    echo "[1/4] Cloning U-Boot repository (shallow clone: $UBOOT_TAG)..."
    git clone --depth 1 https://github.com/u-boot/u-boot.git -b "$UBOOT_TAG" "$UBOOT_SRC"
else
    echo "[1/4] U-Boot source already exists at $UBOOT_SRC"
fi

cd "$UBOOT_SRC"

# 2. Setup Cross-Compile Environment
echo "[2/4] Setting up Cross-Compilation environment..."
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# 3. Apply AM335x EVM Defconfig
echo "[3/4] Applying am335x_evm_defconfig..."
make am335x_evm_defconfig

# 4. Compile U-Boot (SPL and U-Boot proper)
echo "[4/4] Compiling U-Boot with $(nproc) cores..."
make -j$(nproc)

# 5. Verify & Copy Artifacts
if [ -f "MLO" ] && [ -f "u-boot.img" ]; then
    cp MLO "$ARTIFACTS_DIR/MLO"
    cp u-boot.img "$ARTIFACTS_DIR/u-boot.img"
    
    echo "=========================================================="
    echo " [SUCCESS] U-Boot build completed successfully!"
    echo " Artifacts saved in: $ARTIFACTS_DIR"
    echo " ---------------------------------------------------------"
    ls -lh "$ARTIFACTS_DIR/MLO" "$ARTIFACTS_DIR/u-boot.img"
    echo " ---------------------------------------------------------"
    echo " MLO Size: $(stat -c%s "$ARTIFACTS_DIR/MLO") bytes (Must be < 109KB for SRAM)"
    echo "=========================================================="
else
    echo "[ERROR] Build finished but MLO or u-boot.img was not generated!"
    exit 1
fi
