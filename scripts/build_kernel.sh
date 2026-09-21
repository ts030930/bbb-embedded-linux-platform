#!/bin/bash
# ==============================================================================
# BeagleBone Black Linux Kernel Automated Build Script
# Usage: ./scripts/build_kernel.sh
# ==============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="$PROJECT_ROOT/kernel"
KERNEL_VERSION="6.6.50"
KERNEL_SRC="$KERNEL_DIR/linux-$KERNEL_VERSION"
TARBALL="$KERNEL_DIR/linux-$KERNEL_VERSION.tar.xz"
ARTIFACTS_DIR="$KERNEL_DIR/artifacts"
TARBALL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"

echo "=========================================================="
echo " [Phase 3] Building Linux Kernel for BeagleBone Black"
echo " Project Root   : $PROJECT_ROOT"
echo " Kernel Version : $KERNEL_VERSION (LTS)"
echo "=========================================================="

mkdir -p "$KERNEL_DIR" "$ARTIFACTS_DIR"

# 1. Download Kernel Source Tarball if not present
if [ ! -d "$KERNEL_SRC" ]; then
    if [ ! -f "$TARBALL" ]; then
        echo "[1/5] Downloading Linux Kernel $KERNEL_VERSION tarball..."
        curl -L --progress-bar -o "$TARBALL" "$TARBALL_URL"
    else
        echo "[1/5] Kernel tarball already exists at $TARBALL"
    fi

    echo "[1/5] Extracting kernel source..."
    tar -xf "$TARBALL" -C "$KERNEL_DIR"
    echo "      Extraction complete: $KERNEL_SRC"
else
    echo "[1/5] Kernel source directory already exists: $KERNEL_SRC"
fi

cd "$KERNEL_SRC"

# 2. Inject Custom Identification Log into init/main.c
echo "[2/5] Injecting custom verification banner into init/main.c..."
python3 "$PROJECT_ROOT/scripts/fix_main_c.py"

# 3. Setup Cross-Compile Environment & Apply Defconfig
echo "[3/5] Setting up Cross-Compilation & applying omap2plus_defconfig..."
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make omap2plus_defconfig

# 4. Compile Kernel Image (zImage) and Device Tree Blobs (dtbs)
echo "[4/5] Compiling zImage and DTBs with $(nproc) CPU cores..."
make -j$(nproc) zImage
make -j$(nproc) dtbs

# 5. Verify and Copy Artifacts
echo "[5/5] Collecting build artifacts..."
DTB_PATH=""
if [ -f "arch/arm/boot/dts/ti/omap/am335x-boneblack.dtb" ]; then
    DTB_PATH="arch/arm/boot/dts/ti/omap/am335x-boneblack.dtb"
elif [ -f "arch/arm/boot/dts/am335x-boneblack.dtb" ]; then
    DTB_PATH="arch/arm/boot/dts/am335x-boneblack.dtb"
fi

if [ -f "arch/arm/boot/zImage" ] && [ -n "$DTB_PATH" ]; then
    cp arch/arm/boot/zImage "$ARTIFACTS_DIR/zImage"
    cp "$DTB_PATH" "$ARTIFACTS_DIR/am335x-boneblack.dtb"
    
    cd "$ARTIFACTS_DIR"
    sha256sum zImage am335x-boneblack.dtb > checksums.sha256
    
    echo "=========================================================="
    echo " [SUCCESS] Linux Kernel build completed successfully!"
    echo " Artifacts saved in: $ARTIFACTS_DIR"
    echo " ---------------------------------------------------------"
    ls -lh "$ARTIFACTS_DIR/zImage" "$ARTIFACTS_DIR/am335x-boneblack.dtb"
    echo " ---------------------------------------------------------"
    cat checksums.sha256
    echo "=========================================================="
else
    echo "[ERROR] Build completed but zImage or am335x-boneblack.dtb not found!"
    exit 1
fi
