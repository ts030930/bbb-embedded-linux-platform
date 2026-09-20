#!/bin/bash
# ==============================================================================
# BeagleBone Black Baseline System Audit Script
# Run this script directly on the BeagleBone Black (debian@BeagleBone:~$)
# ==============================================================================

OUTPUT_DIR="/tmp/bbb_baseline_audit"
ARCHIVE="/tmp/bbb_baseline_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "[*] Starting BBB System Audit..."
mkdir -p "$OUTPUT_DIR"

# 1. OS and Kernel Info
uname -a > "$OUTPUT_DIR/uname.txt"
cat /etc/os-release > "$OUTPUT_DIR/os_release.txt" 2>/dev/null || true
cat /proc/version > "$OUTPUT_DIR/proc_version.txt"

# 2. Hardware & Memory
cat /proc/cpuinfo > "$OUTPUT_DIR/cpuinfo.txt"
cat /proc/meminfo > "$OUTPUT_DIR/meminfo.txt"
lscpu > "$OUTPUT_DIR/lscpu.txt" 2>/dev/null || true
free -h > "$OUTPUT_DIR/free.txt"

# 3. Storage & Partitions (Verify eMMC vs SD card)
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL > "$OUTPUT_DIR/lsblk.txt"
df -h > "$OUTPUT_DIR/df.txt"
cat /proc/partitions > "$OUTPUT_DIR/partitions.txt"

# 4. Kernel Modules & Interrupts
lsmod > "$OUTPUT_DIR/lsmod.txt"
cat /proc/interrupts > "$OUTPUT_DIR/interrupts.txt"

# 5. Device Nodes & sysfs
ls -l /dev > "$OUTPUT_DIR/dev_nodes.txt"
ls -l /sys/class > "$OUTPUT_DIR/sys_class.txt"
ls -l /sys/bus > "$OUTPUT_DIR/sys_bus.txt"
i2cdetect -l > "$OUTPUT_DIR/i2c_buses.txt" 2>/dev/null || true

# 6. Device Tree Model & Compatible
if [ -d /sys/firmware/devicetree/base ]; then
    cat /sys/firmware/devicetree/base/model > "$OUTPUT_DIR/dt_model.txt" 2>/dev/null || true
    cat /sys/firmware/devicetree/base/compatible > "$OUTPUT_DIR/dt_compatible.txt" 2>/dev/null || true
fi

# 7. Boot dmesg log
dmesg > "$OUTPUT_DIR/dmesg.txt"

# 8. Boot args & U-Boot environment if accessible
cat /proc/cmdline > "$OUTPUT_DIR/cmdline.txt"

tar -czf "$ARCHIVE" -C "/tmp" bbb_baseline_audit

echo "[+] Audit completed!"
echo "    Directory : $OUTPUT_DIR"
echo "    Archive   : $ARCHIVE"
echo "================================================="
echo "Summary:"
echo " Kernel     : $(cat $OUTPUT_DIR/uname.txt)"
echo " Board Model: $(cat $OUTPUT_DIR/dt_model.txt 2>/dev/null || echo 'Unknown')"
echo " Boot Cmdline: $(cat $OUTPUT_DIR/cmdline.txt)"
echo " Mounts     :"
cat "$OUTPUT_DIR/lsblk.txt"
echo "================================================="
