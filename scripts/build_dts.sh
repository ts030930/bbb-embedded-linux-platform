#!/bin/bash
# ==============================================================================
# BeagleBone Black Device Tree Build & Verification Script
# Usage: ./scripts/build_dts.sh
# ==============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_SRC="$PROJECT_ROOT/kernel/linux-6.6.50"
DTS_DIR="$PROJECT_ROOT/dts"
ARTIFACTS_DIR="$PROJECT_ROOT/kernel/artifacts"
BONEBLACK_DTS="$KERNEL_SRC/arch/arm/boot/dts/ti/omap/am335x-boneblack.dts"

echo "=========================================================="
echo " [Phase 4] Building & Verifying Custom Device Tree"
echo " Project Root : $PROJECT_ROOT"
echo " DTS Source   : $DTS_DIR/bbb-ai-overlay.dtso"
echo " Kernel DTS   : $BONEBLACK_DTS"
echo "=========================================================="

mkdir -p "$DTS_DIR" "$ARTIFACTS_DIR"

# 1. Compile Standalone Device Tree Overlay (.dtso -> .dtbo)
echo "[1/4] Compiling Standalone Device Tree Overlay with dtc..."
dtc -@ -I dts -O dtb -o "$DTS_DIR/bbb-ai-overlay.dtbo" "$DTS_DIR/bbb-ai-overlay.dtso"
echo "      Overlay compiled: $DTS_DIR/bbb-ai-overlay.dtbo ($(stat -c%s "$DTS_DIR/bbb-ai-overlay.dtbo") bytes)"

# 2. Inject Custom Node into Kernel am335x-boneblack.dts
echo "[2/4] Injecting custom bbb_ai_ctrl node into kernel DTS..."
python3 "$PROJECT_ROOT/scripts/patch_dts.py"

# 3. Compile am335x-boneblack.dtb via Kernel Build System
echo "[3/4] Compiling am335x-boneblack.dtb with Kernel build system..."
make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- ti/omap/am335x-boneblack.dtb

# Update artifacts
cp "$KERNEL_SRC/arch/arm/boot/dts/ti/omap/am335x-boneblack.dtb" "$ARTIFACTS_DIR/am335x-boneblack.dtb"

# 4. Decompile DTB to verify injection
echo "[4/4] Decompiling DTB binary to verify node injection..."
dtc -I dtb -O dts "$ARTIFACTS_DIR/am335x-boneblack.dtb" -o "$DTS_DIR/decompiled_verify.dts" 2>/dev/null

if grep -q "taesun,bbb-ai-ctrl" "$DTS_DIR/decompiled_verify.dts"; then
    echo "=========================================================="
    echo " [SUCCESS] Custom node confirmed in binary DTB!"
    echo " ---------------------------------------------------------"
    grep -C 5 "taesun,bbb-ai-ctrl" "$DTS_DIR/decompiled_verify.dts"
    echo " ---------------------------------------------------------"
    echo " DTB File : $ARTIFACTS_DIR/am335x-boneblack.dtb"
    echo " DTBO File: $DTS_DIR/bbb-ai-overlay.dtbo"
    echo "=========================================================="
else
    echo "[ERROR] Verification failed: node not found in decompiled DTB!"
    exit 1
fi
