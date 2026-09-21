# [Phase 4] Device Tree(디바이스 트리) 심층 분석 및 실습 가이드

## 1. Device Tree가 왜 등장했는가? (역사적 배경)

과거 리눅스 2.6 ~ 3.x 시절의 ARM 아키텍처는 보드가 하나 추가될 때마다 `arch/arm/mach-omap2/board-am335xevm.c` 같은 C 언어 하드웨어 정의 파일(Board File)을 수천 줄씩 작성해야 했습니다. 
- 보드의 핀 연결 하나, I2C 주소 하나만 바뀌어도 **커널 소스코드(C 언어)를 수정하고 커널 전체를 다시 컴파일**해야 했습니다.
- 이로 인해 커널 소스 트리가 수많은 보드 전용 코드로 난잡해지자, 리눅스 창시자 리누스 토르발스(Linus Torvalds)가 극단적인 비판을 쏟아내며 ARM 진영에 전면 개혁을 요구했습니다.

그 결과 도입된 것이 **Device Tree (Open Firmware 표준, IEEE 1275)**입니다:
> **핵심 철학**: "OS 바이너리(`zImage`)와 하드웨어 명세서(`dtb`)를 완전히 분리한다!"
> - 하드웨어 회로가 바뀌면 텍스트 명세서(`.dts`)만 고쳐서 바이너리(`.dtb`)로 컴파일해 U-Boot에 넘겨주면, 커널은 단 한 줄도 고칠 필요가 없습니다.

---

## 2. Device Tree 4대 핵심 구성 요소

```text
+-----------------------+                    +-----------------------+
|  SoC 공통 템플릿     |                    |  보드별 특화 파일     |
|  (am33xx.dtsi)        |                    |  (am335x-boneblack.dts)
+-----------+-----------+                    +-----------+-----------+
            |                                            |
            +--------------------+  +--------------------+
                                 |  | (#include)
                                 v  v
                    +-----------------------------+
                    |  DTS (Device Tree Source)   |
                    |  - 사람이 읽을 수 있는 텍스트 |
                    +--------------+--------------+
                                   |
                                   | [dtc 컴파일러]
                                   v
                    +-----------------------------+
                    |  DTB (Device Tree Blob)     |
                    |  - 커널/부트로더용 바이너리 |
                    +--------------+--------------+
                                   |
                                   | (부팅 시 RAM에 로드)
                                   v
                    +-----------------------------+
                    |  Linux Kernel Device Model  |
                    |  - 드라이버 probe() 자동 호출|
                    +-----------------------------+
```

1. **`.dtsi` (Device Tree Source Include)**:
   - SoC 제조사(TI)가 제공하는 칩셋 공통 명세서 (예: AM335x의 UART0~5 주소, I2C0~2 컨트롤러 레지스터 등).
2. **`.dts` (Device Tree Source)**:
   - 보드 제조사(BeagleBoard)가 작성한 실제 보드 명세서 (`.dtsi`를 인클루드한 뒤 실제 사용되는 핀과 전원 상태를 정의).
3. **`dtc` (Device Tree Compiler)**:
   - 텍스트 파일인 `.dts`를 이진 바이트 스트림인 `.dtb`로 컴파일하는 전용 컴파일러.
4. **`.dtb` (Device Tree Blob / Flattened Device Tree)**:
   - U-Boot가 읽어서 리눅스 커널의 시작 함수(`start_kernel`)에 2번째 파라미터(`r2` 레지스터)로 넘겨주는 최종 바이너리.

---

## 3. 핵심 문법 및 속성(Property) 해설

### (1) 노드(Node)의 기본 형태
```dts
[라벨:] 노드이름[@유닛주소] {
    속성1 = 값1;
    속성2 = <값2>;
    자식노드 {
        ...
    };
};
```

### (2) 필수 핵심 속성 5가지

| 속성명 | 설명 | 예시 |
| :--- | :--- | :--- |
| **`compatible`** | **[가장 중요]** 커널 드라이버와 매칭되는 고유 식별 문자열.<br>`"제조사,모델명"` 형식으로 작성 | `compatible = "taesun,bbb-ai-ctrl";` |
| **`status`** | 장치의 활성화 여부 (`"okay"` 또는 `"disabled"`) | `status = "okay";` |
| **`reg`** | 장치의 물리 메모리 주소(Base Address)와 크기(Size) | `reg = <0x44e0b000 0x1000>;` |
| **`interrupts`** | 하드웨어 인터럽트(IRQ) 번호 및 트리거 방식 | `interrupts = <16 2>; /* Falling Edge */` |
| **`pinctrl-*`** | AM335x의 핀 멀티플렉싱(Pinmux) 설정 연결 | `pinctrl-0 = <&custom_pins>;` |

---

## 4. 커널은 Device Tree를 어떻게 드라이버와 연결하는가? (매칭 원리)

이 과정이 임베디드 리눅스 BSP 엔지니어의 핵심 역량입니다:

```text
1. [부팅 초기]
   U-Boot가 RAM(0x88000000)에 am335x-boneblack.dtb 적재 후 커널 점프
      ↓
2. [DT 파싱 (unflatten)]
   커널이 DTB를 읽어 메모리에 트리 구조(struct device_node)를 생성
      ↓
3. [플랫폼 디바이스 생성]
   각 노드마다 struct platform_device 객체를 자동 생성하여 커널에 등록
      ↓
4. [드라이버 매칭]
   디바이스의 compatible 문자열과 드라이버(C 코드)의 of_match_table 문자열 비교!

   [Device Tree]                              [Driver C Code]
   compatible = "taesun,bbb-ai-ctrl";  <───>  static const struct of_device_id match[] = {
                                                   { .compatible = "taesun,bbb-ai-ctrl" },
                                                   { }
                                              };
      ↓
5. [일치 확인!]
   문자열이 완전히 일치하면 커널이 드라이버의 probe() 함수를 즉시 호출!
   my_driver_probe(struct platform_device *pdev);
```

---

## 5. 명령어별 상세 해설 (DTC 및 분석 도구)

### (1) DTS 단독 컴파일 (DTC 직접 호출)
```bash
dtc -I dts -O dtb -o output.dtb input.dts
```
- `-I dts` : 입력 파일 형식이 **DTS (텍스트 소스)**임을 명시
- `-O dtb` : 출력 파일 형식이 **DTB (바이너리 블롭)**임을 명시
- `-o output.dtb` : 생성할 파일 이름 지정

### (2) DTB 역컴파일 (바이너리를 텍스트로 풀어보기)
```bash
dtc -I dtb -O dts -o decompiled.dts input.dtb
```
- 컴파일된 `.dtb` 파일 안에 내가 원하는 노드가 제대로 들어갔는지 확인할 때 사용하는 가장 강력한 디버깅 명령어입니다.

### (3) 커널 빌드 시스템을 통한 전체 DTB 빌드
```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
```
- 커널 Makefile이 C 전처리기(`cpp`)를 돌려 `#include` 문을 모두 해결한 뒤 `dtc`를 호출해 모든 타깃 보드의 `.dtb`를 생성합니다.
