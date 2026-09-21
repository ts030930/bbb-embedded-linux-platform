# [Phase 4] Device Tree 커스텀 노드 구현 및 바이너리 검증 보고서

## 1. 개요 및 목적
본 단계에서는 BeagleBone Black의 하드웨어 명세서인 Device Tree에 우리가 직접 설계한 Edge AI 플랫폼 장치 노드(**`bbb-ai-ctrl`**)를 정의하고, 이를 **독립형 오버레이(`.dtbo`)**와 **보드 통합 바이너리(`.dtb`)** 두 가지 형태로 각각 컴파일 및 검증을 완료했습니다.

---

## 2. 우리가 정의한 커스텀 노드 명세 (Specification)

```dts
bbb_ai_ctrl: bbb-ai-ctrl {
    compatible = "taesun,bbb-ai-ctrl";
    status = "okay";
    interrupt-parent = <&gpio1>;
    interrupts = <16 2>; /* GPIO1_16 (Pin P9_15), Falling Edge Trigger */
    ai-engine = "tflite-micro-armv7";
    buffer-size = <4096>;
    firmware-version = "v1.0-edge-ai";
};
```

### 각 필드의 의미
- **`compatible = "taesun,bbb-ai-ctrl"`**: Phase 5에서 작성할 커널 드라이버가 매칭할 고유 식별자.
- **`interrupt-parent = <&gpio1>`**: AM335x의 GPIO Bank 1을 인터럽트 컨트롤러로 지정.
- **`interrupts = <16 2>`**: Bank 1의 16번 핀(물리 핀 P9_15번)을 사용하며, 신호가 떨어질 때(`IRQ_TYPE_EDGE_FALLING = 2`) 인터럽트를 발생시키도록 커널에 지시.
- **`buffer-size = <4096>`**: 추론 전처리용 링버퍼 크기(4KB). 드라이버의 `probe()` 함수에서 `of_property_read_u32()`로 직접 읽어올 수 있습니다.

---

## 3. 생성된 산출물 (Artifacts)

| 파일명 | 크기 | 저장 경로 | 설명 |
| :--- | :--- | :--- | :--- |
| **`bbb-ai-overlay.dtbo`** | **667 bytes** | `dts/bbb-ai-overlay.dtbo` | 런타임/부팅 시 동적으로 얹을 수 있는 독립형 오버레이 바이너리 |
| **`am335x-boneblack.dtb`** | **70 KB** | `kernel/artifacts/am335x-boneblack.dtb` | 커스텀 노드가 영구 주입된 BBB 메인 하드웨어 바이너리 |

---

## 4. 바이너리 역컴파일(Decompilation) 검증

컴파일된 바이너리 `am335x-boneblack.dtb`를 `dtc -I dtb -O dts`로 역컴파일하여 바이너리 내부에 노드가 완벽히 구워졌는지 확인했습니다:

```dts
/* 역컴파일된 실제 바이너리 내용 확인 */
bbb-ai-ctrl {
    compatible = "taesun,bbb-ai-ctrl";
    status = "okay";
    interrupt-parent = <0x28>;       /* &gpio1 레이블이 phandle 0x28로 완벽 치환됨 */
    interrupts = <0x10 0x02>;        /* 16핀(0x10)과 Falling edge(0x02)가 16진수 바이트로 컴파일됨 */
    ai-engine = "tflite-micro-armv7";
    buffer-size = <0x1000>;          /* 4096(0x1000) 바이트 */
    firmware-version = "v1.0-edge-ai";
};
```
- 텍스트 레이블이었던 `&gpio1`이 내부 객체 핸들 번호인 `phandle <0x28>`로 완벽하게 링킹되었음을 볼 수 있습니다.

---

## 5. 트러블슈팅: DTC 컴파일러의 엄격한 문법 규칙

### [문제 발생]
- `Error: Properties must precede subnodes` 에러와 함께 DTB 빌드 실패.

### [원인 및 해결]
- Device Tree 사양서(DTC v1.4.x+) 규칙에 따라, **어떤 노드 내부에서도 일반 속성(`model`, `compatible` 등)은 반드시 자식 서브노드(`bbb-ai-ctrl { ... }`)보다 앞서 선언**되어야 합니다.
- 주입 위치를 `compatible = ...;` 바로 뒤로 배치하도록 [`scripts/patch_dts.py`](file:///d:/BBB/scripts/patch_dts.py)를 개선하여 정상 컴파일을 완료했습니다.

---

## 6. Phase 5 드라이버와의 연결 고리

이제 리눅스 하드웨어 명세서(DTB)에 `taesun,bbb-ai-ctrl` 장치가 정식 등록되었습니다.
Phase 5에서 커널 모듈을 작성할 때 아래와 같이 매칭 테이블을 선언하면:

```c
static const struct of_device_id bbb_ai_of_match[] = {
    { .compatible = "taesun,bbb-ai-ctrl" },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, bbb_ai_of_match);
```

모듈이 로드되는 순간 커널이 Device Tree에서 이 노드를 찾아내어 우리 드라이버의 **`probe()` 함수를 자동으로 호출**하게 됩니다.
