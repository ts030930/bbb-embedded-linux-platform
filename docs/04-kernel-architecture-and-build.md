# [Phase 3] Linux Kernel 아키텍처 및 빌드 완벽 가이드

## 1. 리눅스 커널 소스코드 구조와 AM335x

리눅스 커널 소스코드는 수천만 줄에 달하지만, 디렉터리별 역할이 매우 엄격하게 분리되어 있습니다:

```text
linux-6.6.x/
├── arch/arm/                 # [핵심] 32비트 ARM(Cortex-A8) 전용 코드
│   ├── boot/dts/ti/omap/     # BeagleBone Black 디바이스 트리 소스 (.dts)
│   ├── configs/              # 기본 설정 파일 (omap2plus_defconfig)
│   ├── kernel/               # ARM 전용 예외 처리, 인터럽트 벡터, 스케줄러 저수준 코드
│   └── mm/                   # ARM MMU 및 가상 메모리 관리
├── drivers/                  # 모든 하드웨어 디바이스 드라이버 (I2C, SPI, GPIO 등)
├── fs/                       # 파일 시스템 (ext4, fat, sysfs, procfs)
├── include/                  # 커널 전역 헤더 파일
├── init/main.c               # [핵심] 커널 시작 지점 (start_kernel() 함수)
├── kernel/                   # 핵심 OS 로직 (스케줄러, 락, 워크큐, 타이머)
└── Makefile                  # 최상위 빌드 메이크파일
```

---

## 2. 명령어별 상세 해설 (Command-by-Command Manual)

### (1) 크로스 컴파일 환경변수 선언
```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```
- **`export ARCH=arm`**:
  - 기본값은 호스트 PC의 아키텍처인 `x86_64`입니다.
  - 이를 `arm`으로 지정하여 커널 Makefile이 `arch/arm/` 하위의 소스코드를 컴파일하도록 지시합니다.
- **`export CROSS_COMPILE=arm-linux-gnueabihf-`**:
  - Makefile 내부의 모든 컴파일러 명령어 앞단에 접두사(Prefix)를 붙입니다.
  - `$(CROSS_COMPILE)gcc` → `arm-linux-gnueabihf-gcc`
  - `$(CROSS_COMPILE)ld`  → `arm-linux-gnueabihf-ld`

---

### (2) 하드웨어 기본 설정 적용 (`defconfig`)
```bash
make omap2plus_defconfig
```
- **역할**: `arch/arm/configs/omap2plus_defconfig`를 읽어 최상위 디렉터리에 **`.config`** 파일을 생성합니다.
- **`omap2plus`란?**: TI(Texas Instruments)의 OMAP / AM335x(Sitara) / AM437x 제품군을 지원하는 표준 통합 설정입니다.
- **왜 이 작업이 필요한가?**: 리눅스 커널에는 수만 개의 컴파일 옵션(Kconfig)이 있습니다. 하나하나 수동으로 고를 수 없으므로, AM335x 칩셋에 필수적인 드라이버(TPS65217 PMIC, OMAP MMC, I2C, UART 등)가 미리 활성화된 템플릿을 불러오는 것입니다.

---

### (3) 커널 이미지 빌드 (`zImage`)
```bash
make -j$(nproc) zImage
```
- **`-j$(nproc)`**: PC의 가용 CPU 코어 수(예: 8코어, 16코어)만큼 병렬 빌드를 수행하여 빌드 시간을 수 분 내로 단축합니다.
- **`zImage`의 정체 (Self-Extracting Compressed Kernel)**:
  1. `vmlinux`: 컴파일된 순수 무압축 커널 ELF 바이너리 (수십 MB 크기)
  2. `Image`: 디버그 심볼을 제거한 순수 기계어 바이너리
  3. `zImage`: `Image`를 gzip/LZO로 압축한 뒤, 맨 앞에 **"초소형 자체 압축 해제 코드(Decompressor Stub)"**를 덧붙인 최종 파일입니다.
  - U-Boot가 `zImage`를 RAM에 올리고 점프하면, `zImage` 스스로 압축을 풀어 RAM에 본래 커널을 전개한 후 커널 부팅 함수(`start_kernel`)를 호출합니다.

---

### (4) 디바이스 트리 컴파일 (`dtbs`)
```bash
make -j$(nproc) dtbs
```
- **역할**: `arch/arm/boot/dts/ti/omap/am335x-boneblack.dts` 소스 텍스트 파일을 디바이스 트리 컴파일러(`dtc`)로 컴파일하여 바이너리 파일인 **`am335x-boneblack.dtb`**로 변환합니다.
- **왜 분리해서 빌드하는가?**: 커널 바이너리(`zImage`)는 순수 OS 코드이고, 보드의 핀 연결 및 주소 정보는 `dtb`에 독립적으로 담깁니다. 따라서 하드웨어 회로가 바뀌어도 커널을 다시 빌드할 필요 없이 `dtb`만 새로 구우면 됩니다.

---

### (5) 커널 모듈 빌드 (`modules`)
```bash
make -j$(nproc) modules
```
- **역할**: `.config`에서 `CONFIG_XXX=m`으로 설정된 드라이버들을 동적 로딩 가능한 **`.ko` (Kernel Object)** 모듈 파일로 컴파일합니다.
- **메모리 절약 효과**: BBB의 512MB RAM은 매우 작습니다. 모든 드라이버를 `zImage` 안에 넣으면(Built-in, `=y`) 커널 메모리가 낭비되므로, 필요할 때만 메모리에 올리는 모듈(`=m`) 형태로 분리 빌드합니다.

---

## 3. 커널 수정 및 식별 로그 삽입 (내가 빌드한 커널 증명하기)

`init/main.c`의 `start_kernel()` 함수 끝부분(또는 배너 출력 함수)에 우리만의 커스텀 로그를 삽입합니다:

```c
pr_info("====================================================\n");
pr_info(" BeagleBone Black Edge AI Custom Kernel Booted!\n");
pr_info(" Engineer : Taesun Park (ts030930)\n");
pr_info(" Build Ver: Phase 3 Linux 6.6 LTS\n");
pr_info("====================================================\n");
```

이 로그가 부팅 시 UART 시리얼 콘솔에 나타나면, 인터넷에서 받은 이미지가 아니라 **내가 직접 빌드한 리눅스 커널이 보드에서 돌고 있음을 100% 증명**하게 됩니다.
