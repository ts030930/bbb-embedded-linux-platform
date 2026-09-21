import re

dts_file = "/mnt/d/BBB/kernel/linux-6.6.50/arch/arm/boot/dts/ti/omap/am335x-boneblack.dts"

with open(dts_file, "r", encoding="utf-8") as f:
    content = f.read()

# Remove any previously injected bbb_ai_ctrl node
content = re.sub(r"\t/\* BeagleBone Black Edge AI Custom Node.*?\t\};\n", "", content, flags=re.DOTALL)

custom_node = """
\t/* BeagleBone Black Edge AI Custom Node - Taesun Park */
\tbbb_ai_ctrl: bbb-ai-ctrl {
\t\tcompatible = "taesun,bbb-ai-ctrl";
\t\tstatus = "okay";
\t\tinterrupt-parent = <&gpio1>;
\t\tinterrupts = <16 2>; /* GPIO1_16 (P9_15), IRQ_TYPE_EDGE_FALLING */
\t\tai-engine = "tflite-micro-armv7";
\t\tbuffer-size = <4096>;
\t\tfirmware-version = "v1.0-edge-ai";
\t};
"""

# Inject AFTER compatible = "ti,am335x-bone-black", ...; so properties precede subnodes
pattern = r'(compatible = "ti,am335x-bone-black"[^;]+;)'
if re.search(pattern, content):
    content = re.sub(pattern, r"\1\n" + custom_node, content, count=1)
    with open(dts_file, "w", encoding="utf-8") as f:
        f.write(content)
    print("Successfully patched am335x-boneblack.dts (subnode placed after properties)!")
else:
    print("Could not find pattern in am335x-boneblack.dts")
