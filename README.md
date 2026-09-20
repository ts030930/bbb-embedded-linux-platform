# BeagleBone Black Edge AI Inference Platform

Embedded Linux system integrating:
- Bootloader (U-Boot) & Boot Flow Analysis (ROM -> SPL -> U-Boot -> Kernel)
- Linux Kernel Build & Customization
- Device Tree (DTS/DTB) & Hardware Description
- Custom Linux Device Driver (/dev/bbb_ctrl, I2C client, IRQ/workqueue)
- User-space Driver API & Preprocessing
- Edge AI Inference Pipeline (Lightweight TFLite / ONNX runtime)
- System Profiling & Latency Analysis (ftrace, perf, dmesg, /proc)

---

## 1. System Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      User Application                       │
│                                                             │
│   Sensor / Input  ───>  Preprocessing  ───>  AI Inference   │
│         │                                        │          │
│         └───────────────> Driver API <───────────┘          │
└──────────────────────────────────┬──────────────────────────┘
                                   │
                         ioctl / read / write
                                   │
┌──────────────────────────────────▼──────────────────────────┐
│                        Linux Kernel                         │
│                                                             │
│              Custom Device Driver / Kernel Module           │
│                               │                             │
│                          Device Tree                        │
│                               │                             │
│                  GPIO / I2C / SPI / UART                    │
└──────────────────────────────────┬──────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────┐
│                          Hardware                           │
│                                                             │
│                  BBB AM335x Cortex-A8                       │
│                  Sensor / Input Device                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure

- `bootloader/` : U-Boot 소스 코드 및 빌드 산출물 (`MLO`, `u-boot.img`)
- `kernel/` : Linux Kernel 소스, `.config`, `zImage`, `DTB`, modules
- `dts/` : 커스텀 Device Tree 소스 (`.dts`, `.dtsi`, device overlays)
- `driver/` : 커스텀 리눅스 커널 드라이버 소스코드
  - `step1_hello/` : 기본 LKM (Loadable Kernel Module) 구조
  - `step2_char_dev/` : 문자 디바이스 (`/dev/bbb_ctrl`, `file_operations`)
  - `step3_i2c_sensor/` : I2C 센서 버스 클라이언트 드라이버 (`probe`, `i2c_transfer`)
  - `step4_irq_event/` : 하드웨어 인터럽트(IRQ) 및 Workqueue 비동기 통지
- `userspace/` : 사용자 영역 애플리케이션 (드라이버 연동 C/C++ 프로그램)
- `ai/` : 임베디드 AI 추론 모델 및 런타임
- `docs/` : 이론 분석, 부팅 흐름, 드라이버 아키텍처, 성능 측정 보고서
- `scripts/` : 호스트 환경설정, 감사, 빌드 자동화 스크립트
- `results/` : 부팅 시간, 레이턴시, 추론 성능 벤치마크 결과

---

## 3. Current Target Information (Phase 1 Baseline)
- **Board**: BeagleBone Black (TI Sitara AM335x, ARM Cortex-A8)
- **Kernel**: Linux 6.18.52-bone54 armv7l
- **Distribution**: Debian GNU/Linux 13 (trixie)
- **Console**: Serial UART (115200 8N1)
