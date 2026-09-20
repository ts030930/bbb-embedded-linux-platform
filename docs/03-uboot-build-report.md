# [Phase 2] U-Boot 빌드 결과 및 아티팩트 분석 보고서

## 1. 빌드 환경 요약
- **호스트 환경**: Windows 11 + WSL2 Ubuntu 24.04 LTS (x86_64)
- **타깃 보드**: BeagleBone Black (TI AM3358 Cortex-A8, ARMv7-A)
- **크로스 컴파일러**: `arm-linux-gnueabihf-gcc` (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
- **U-Boot 버전**: `v2024.01` (Stable)
- **적용 Defconfig**: `am335x_evm_defconfig`
- **빌드 스크립트**: `scripts/build_uboot.sh`

---

## 2. 생성된 핵심 산출물 (Artifacts)

| 파일명 | 크기 | 저장 경로 | 역할 | SHA256 체크섬 |
| :--- | :--- | :--- | :--- | :--- |
| **`MLO`** | **110,012 bytes** (~107.4 KB) | `bootloader/artifacts/MLO` | SPL (Secondary Program Loader) | `c4e8fd3f9346b792eeb9fd07fbac5cf246bb89add350eb3a22eb3b7ebac865bd` |
| **`u-boot.img`** | **1,417,476 bytes** (~1.35 MB) | `bootloader/artifacts/u-boot.img` | FIT 형태 U-Boot 본체 | `be35fd2e56ff0a43a01c2235d02fc002b12aeb82f7e8236c2795094f4c810988` |

---

## 3. 핵심 아키텍처 분석

### (1) MLO 크기 검증 (SRAM 한계 제약)
- AM335x SoC의 내부 SRAM 크기는 **약 109 KB** (L3 ROM 및 스택 영역 제외 가용 공간 약 111,616 바이트)입니다.
- 빌드된 `MLO`의 크기는 **110,012 바이트**로, SRAM 가용 용량 한계선 바로 아래에 정밀하게 맞춰져 있습니다.
- Boot ROM은 파일 헤더(8바이트 GP Header)를 파싱하여 내부 SRAM `0x402F0400`에 적재한 뒤 실행합니다.

### (2) `u-boot.img`의 FIT (Flattened Image Tree) 구조
현대 U-Boot(`v2024.01`)는 단순 바이너리가 아닌 **FIT (Flattened Image Tree)** 이미지 포맷을 사용합니다. `mkimage -l`로 분석한 내부 구조는 다음과 같습니다:

1. **U-Boot Firmware Image (`firmware-1`)**:
   - 용량: 580.41 KiB
   - Load Address: `0x80800000` (DDR3 SDRAM 물리 주소)
   - Architecture: ARM 32-bit
2. **다중 디바이스 트리 (FDT) 번들**:
   - `fdt-1`: am335x-evm
   - `fdt-2`: am335x-bone (White)
   - **`fdt-6`: am335x-boneblack** (우리가 사용하는 타깃!)
   - `fdt-8`: am335x-bonegreen
   - `fdt-10`: am335x-pocketbeagle
3. **자동 하드웨어 감지 (Board Detection)**:
   - SPL이 실행될 때 I2C0 버스에 연결된 온보드 EEPROM(주소 `0x50`)을 읽습니다.
   - EEPROM의 헤더 문자열 `A335BNLT` (BeagleBone Black 식별 코드)를 파싱하여 자동으로 **`Configuration 5 (am335x-boneblack)`**을 선택하여 부팅합니다.

---

## 4. microSD 카드 적용 방법 (배포 가이드)

microSD 카드의 첫 번째 FAT 파티션(`/boot/firmware` 또는 윈도우에서 인식되는 드라이브)에 복사하면 즉시 적용됩니다:

```bash
# BBB 내부에서 직접 덮어쓰는 경우:
sudo cp MLO /boot/firmware/
sudo cp u-boot.img /boot/firmware/
sync
```

재부팅 시 UART 시리얼 콘솔에서 U-Boot 배너가 최신 버전(`U-Boot 2024.01`)으로 갱신된 것을 확인할 수 있습니다.
