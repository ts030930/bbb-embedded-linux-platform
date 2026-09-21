import re

main_c = "/mnt/d/BBB/kernel/linux-6.6.50/init/main.c"

with open(main_c, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if 'pr_info("====================================================' in line:
        skip = True
        continue
    if skip:
        if 'pr_info("====================================================' in line:
            skip = False
            continue
        # Also skip any broken continuation lines
        if line.strip().endswith('");') or 'pr_info(' in line:
            continue
        else:
            skip = False

    if 'pr_notice("%s", linux_banner);' in line:
        new_lines.append(line)
        new_lines.append('\tpr_info("====================================================\\n");\n')
        new_lines.append('\tpr_info(" BeagleBone Black Edge AI Custom Kernel Booted!\\n");\n')
        new_lines.append('\tpr_info(" Engineer : Taesun Park (ts030930)\\n");\n')
        new_lines.append('\tpr_info(" Build Ver: Phase 3 Linux 6.6 LTS\\n");\n')
        new_lines.append('\tpr_info("====================================================\\n");\n')
    else:
        new_lines.append(line)

with open(main_c, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("init/main.c successfully updated!")
