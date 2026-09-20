# BeagleBone Black 부팅 시퀀스 (Boot Flow) 심층 분석

## 1. 개요: AM335x 부팅 5단계 파이프라인

BeagleBone Black(TI Sitara AM3358, ARM Cortex-A8)의 전원을 켜면 하드웨어 레벨에서 유저 영역의 어플리케이션까지 다음과 같은 5단계 과정을 거쳐 부팅됩니다:

```text
+-------------------------------------------------------------------------+
| Phase 1: Boot ROM (Primary Bootloader)                                  |
| - On-Chip ROM에 하드웨어적으로 구워진 코드 (176KB ROM)                   |
| - SYSBOOT 핀 상태를 읽어 부팅 장치(eMMC / SD Card / UART 등) 순서 결정   |
| - SRAM 크기 한계(약 109KB)로 인해 작은 크기의 SPL을 내부 SRAM으로 로드   |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 2: SPL / MLO (Secondary Program Loader)                           |
| - U-Boot의 1단계 축소판 바이너리 (파일명: MLO)                           |
| - DDR3 SDRAM 컨트롤러 초기화 (512MB RAM 활성화)                          |
| - 핀 멀티플렉싱(Pinmux), 기본 PLL 및 클록 설정                          |
| - 외부 저장소(SD/eMMC)에서 풀 버전 U-Boot(u-boot.img)를 DDR3로 로드     |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 3: U-Boot (Third-Stage Bootloader)                                |
| - DDR3 RAM에서 동작하는 본격적인 부트로더 (u-boot.img)                   |
| - 네트워크(TFTP), 스토리지(ext4, FAT), I2C, USB 등 다양한 드라이버 활성화|
| - uEnv.txt 환경변수 로드 및 bootcmd 실행                                 |
| - 커널 이미지(zImage)와 디바이스 트리(DTB)를 RAM의 지정된 주소로 로드    |
| - bootz [kernel_addr] [initrd_addr] [fdt_addr] 호출로 커널에 제어권 넘김|
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 4: Linux Kernel & Device Tree                                     |
| - MMU(가상 메모리) 활성화 및 페이지 테이블 구성                         |
| - DTB 파싱: 하드웨어 토폴로지(주소, 인터럽트, 버스) 인식                |
| - 드라이버 모델(Device Model): bus -> device ↔ driver probe() 실행       |
| - RootFS 마운트 (eMMC / SD 파티션 또는 NFS)                              |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 5: User Space (init -> systemd -> Application)                    |
| - PID 1 프로세스(/sbin/init 또는 systemd) 실행                          |
| - 디바이스 노드(/dev) 생성 (udev / devtmpfs)                             |
| - 백그라운드 서비스 및 네트워크 시작                                    |
| - Custom Driver / Edge AI 추론 앱 자동 실행                              |
+-------------------------------------------------------------------------+
```

---

## 2. 각 단계별 핵심 메모리 맵 및 동작 원리

### (1) Boot ROM ↔ SRAM
- AM335x의 내부 SRAM은 **109KB**에 불과합니다.
- 풀 버전 U-Boot나 리눅스 커널(수 MB ~ 수십 MB)은 DDR3 RAM이 초기화되기 전에는 SRAM에 적재될 수 없습니다.
- 따라서 TI AM335x Boot ROM은 109KB 이하의 특수 헤더를 가진 **MLO (MMC Load Object)** 파일만을 읽어 SRAM(`0x402F0400`)에 올립니다.

### (2) SPL (MLO)의 역할
- DDR3 SDRAM 파라미터 설정 및 타이밍 캘리브레이션
- MPU(CPU) 클록을 저주파에서 1GHz(또는 기본 550~800MHz)로 승압
- SD 카드의 첫 번째 FAT 파티션에서 `u-boot.img`를 읽어 DDR3 RAM 주소(`0x80800000`)에 로드 후 점프

### (3) U-Boot의 커널 로딩 주소 (Memory Layout 예시)
- AM335x의 물리 DDR3 메모리는 `0x80000000` (512MB: `0x80000000` ~ `0xA0000000`)에 매핑됩니다.
- U-Boot 환경변수 기본값:
  - `loadaddr` (zImage 로드 주소): `0x82000000`
  - `fdtaddr` (DTB 로드 주소): `0x88000000`
  - `rdaddr` (Ramdisk 로드 주소): `0x88080000`
- 부팅 명령: `bootz 0x82000000 - 0x88000000`

### (4) U-Boot가 커널에 전달하는 것
1. **CPU 상태**: 32비트 ARM 모드, IRQ/FIQ 비활성화, MMU 꺼짐, D-Cache 꺼짐.
2. **r0 = 0**
3. **r1 = Machine Type ID** (Device Tree 부팅 시에는 무시됨)
4. **r2 = DTB(Device Tree Blob)의 물리 RAM 시작 주소** (`0x88000000`)
5. **커널 커맨드라인 (`bootargs`)**: `console=ttyS0,115200n8 root=/dev/mmcblk0p2 rw ...`

---

## 3. 실습 시 점검해야 할 핵심 명령 (UART U-Boot 프롬프트)
보드 전원 인가 직후 스페이스바를 연타하면 U-Boot 프롬프트(`=>`)에 진입할 수 있습니다:
```bash
=> printenv           # 전체 환경변수 및 부팅 스크립트 출력
=> bdinfo             # 보드 정보 및 DRAM 시작/크기 주소
=> mmc list           # 인식된 스토리지 (mmc 0: SD, mmc 1: eMMC)
=> mmc dev 0          # SD 카드로 전환
=> ls mmc 0:1         # 부팅 파티션 내 MLO, u-boot.img 파일 확인
```
