# [Phase 3] Linux Kernel 6.6 LTS 빌드 결과 및 트러블슈팅 보고서

## 1. 빌드 환경 및 설정 요약
- **커널 버전**: Linux 6.6.50 LTS (Long Term Support)
- **타깃 SoC / 아키텍처**: TI Sitara AM3358 (ARM Cortex-A8, ARMv7-A)
- **호스트 컴파일러**: `arm-linux-gnueabihf-gcc` (Ubuntu 13.3.0)
- **적용 Defconfig**: `omap2plus_defconfig` (AM335x / OMAP 통합 설정)
- **빌드 스크립트**: [`scripts/build_kernel.sh`](file:///d:/BBB/scripts/build_kernel.sh)

---

## 2. 생성된 핵심 산출물 (Artifacts)

| 파일명 | 크기 | 저장 경로 | 역할 | SHA256 체크섬 |
| :--- | :--- | :--- | :--- | :--- |
| **`zImage`** | **5.0 MB** | `kernel/artifacts/zImage` | Self-Extracting 압축 커널 바이너리 | `379c4c71faf3d15c8b133ff95d94ba5fc0ecf85fb4dc16d25d8076955bbbf438` |
| **`am335x-boneblack.dtb`**| **69 KB** | `kernel/artifacts/am335x-boneblack.dtb`| BBB 하드웨어 디바이스 트리 블롭 | `f9ad57357133d92e3c935629fb787abdd1ec1d56a914487ed36e5434ce8f6de5` |

---

## 3. 커스텀 코드 수정 (자체 빌드 검증용 배너 삽입)

커널의 최초 진입점인 `init/main.c` 내부의 `start_kernel()` 함수에 고유 식별 코드를 직접 주입하여 빌드했습니다:

```c
// init/main.c (Line 896~)
boot_cpu_init();
page_address_init();
pr_notice("%s", linux_banner);

/* --- Custom Verification Banner --- */
pr_info("====================================================\n");
pr_info(" BeagleBone Black Edge AI Custom Kernel Booted!\n");
pr_info(" Engineer : Taesun Park (ts030930)\n");
pr_info(" Build Ver: Phase 3 Linux 6.6 LTS\n");
pr_info("====================================================\n");

early_security_init();
```

- **동작 원리**:
  - 부팅 시 커널이 MMU를 켜고 기본 초기화를 마치면 `start_kernel()`이 실행됩니다.
  - 리눅스 기본 배너(`linux_banner`)가 출력된 직후 우리만의 식별 배너가 커널 콘솔 버퍼(Ring Buffer)와 UART 시리얼 콘솔로 동시 출력됩니다.
  - 이를 통해 인터넷 기성 이미지가 아닌 **내가 직접 크로스 컴파일한 커널이 실행되고 있음을 100% 입증**할 수 있습니다.

---

## 4. 디버깅 및 트러블슈팅 사례 (Troubleshooting Case)

> [!NOTE]
> 엔지니어링 포트폴리오에서 가장 높게 평가받는 것은 **"에러가 났을 때 원인을 어떻게 추적하고 해결했는가"**입니다.

### [문제 발생]
- 병렬 빌드 중 `init/main.o` 컴파일 단계에서 `unterminated argument list invoking macro "pr_info"` 에러 발생하며 빌드 중단.

### [원인 분석]
- 자동화 스크립트에서 파이썬 정규식으로 C 코드를 주입할 때, `\n` 이스케이프 문자가 파이썬 문자열 내에서 실제 줄바꿈(CR/LF) 문자로 조기 변환되었습니다.
- 그 결과 C 소스코드에서 `pr_info("문자열\n");`이 아니라 문자열 따옴표가 닫히기 전에 줄바꿈이 일어난 비정상적인 C 문법(`pr_info("...\n ");`)이 생성되었습니다.

### [해결 방법]
- 전용 C 소스 패치 도구인 [`scripts/fix_main_c.py`](file:///d:/BBB/scripts/fix_main_c.py)를 작성하여 줄 단위 AST 파싱 및 안전한 이스케이프 문자열 주입 방식으로 변경.
- 단일 스레드 컴파일 검증 후 최종 `zImage`와 `am335x-boneblack.dtb` 빌드 완벽 성공.

---

## 5. 타깃 보드 배포 및 검증 방법

BBB의 microSD 카드에 복사하여 부팅을 검증하는 2가지 방법입니다:

### 방법 A: 보드가 켜져 있는 상태에서 네트워크(SCP)로 전송
```bash
# Host PC (WSL)에서 BBB로 파일 전송
scp kernel/artifacts/zImage debian@<BBB_IP>:/tmp/
scp kernel/artifacts/am335x-boneblack.dtb debian@<BBB_IP>:/tmp/

# BBB 터미널에서 /boot/에 배치
sudo cp /tmp/zImage /boot/vmlinuz-6.6.50-custom
sudo cp /tmp/am335x-boneblack.dtb /boot/dtbs/6.6.50-custom/
```

### 방법 B: microSD 카드를 PC에 직접 연결하여 복사
- PC의 파일 탐색기에서 microSD 카드의 부팅 파티션에 `zImage`와 `am335x-boneblack.dtb`를 교체 배치합니다.
