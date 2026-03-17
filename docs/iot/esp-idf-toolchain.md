# ESP-IDF Toolchain Guide

This guide defines how firmware development should work in this repository without interfering with the Python, Docker, and SQL tooling used by the data platform.

## Goal
- Keep ESP32 firmware development in the same repository.
- Keep the firmware toolchain isolated from the data-platform Python environment.
- Make the setup understandable for contributors who are new to ESP-IDF.

## Recommended repository pattern

Use a dedicated firmware subtree:

```text
firmware/
  esp32-c6-devkitm-1/
    main/
    CMakeLists.txt
    sdkconfig.defaults
docs/
  iot/
    esp-idf-toolchain.md
```

Principles:
- Firmware code stays under `firmware/`.
- Data-platform code stays under `scripts/`, `infra/`, and `tests/`.
- Shared contracts such as MQTT topics and payload format belong in `docs/`.

## Required VS Code extensions
- `espressif.esp-idf-extension`
- `ms-vscode.cpptools`

Optional but useful:
- `ms-vscode.cmake-tools`

## Python environment strategy

Do not create a second general-purpose project venv for ESP-IDF inside the repo root.

Use this split instead:
- Root project `.venv`:
  - Python scripts
  - pytest
  - Ruff
  - local repo automation
- ESP-IDF managed environment:
  - ESP-IDF Python packages
  - flashing/build tools
  - device-specific development commands

Why:
- ESP-IDF depends on a tightly controlled toolchain.
- The data-platform project also depends on Python packages with different lifecycle and compatibility needs.
- Mixing these environments makes upgrades and troubleshooting harder.

## Beginner-friendly setup flow

### 1) Install VS Code prerequisites
- Install VS Code.
- Install Git.
- Install Python 3.11+.
- Install the ESP-IDF extension in VS Code.

### 2) Let the extension set up the toolchain
- Open VS Code.
- Run the ESP-IDF setup flow from the extension.
- Let it install:
  - ESP-IDF
  - compiler toolchain
  - Python environment for ESP-IDF
  - flashing tools

This is the safest path for beginners because the extension manages most of the moving parts.

### 3) Keep firmware separate from the root project venv
- Continue using the repo root `.venv` for Python scripts and tests.
- Use the ESP-IDF extension commands for firmware build, flash, monitor, and target configuration.
- Do not install ESP-IDF Python packages into the repo root `.venv`.

### 4) Start with one board and one project
- First board: `ESP32-C6-DevKitM-1`
- First firmware goal:
  - join Wi-Fi
  - connect to MQTT broker
  - publish JSON telemetry to `ca/dev/<device_id>/telemetry`

### 5) Keep the MQTT contract identical to the phone test

Example payload:

```json
{"device_id":"esp32c6-01","temp_c":22.4,"hum_pct":41.2,"ts":"2026-03-17T20:30:00Z"}
```

This allows the Android phone and ESP32 device to use the same ingestion path and validation rules.

## Contributor checklist

Before touching firmware:
- Confirm the ESP-IDF extension is installed.
- Confirm the extension setup completed successfully.
- Confirm the target board is set correctly.
- Confirm the local Wi-Fi and MQTT broker details are available.

Before opening a firmware PR:
- Build succeeds in ESP-IDF.
- Device can publish one valid MQTT telemetry payload.
- Payload matches the documented topic and JSON contract.
- Any board-specific assumptions are written down.

## What to avoid
- Do not mix ESP-IDF packages into the root `.venv`.
- Do not hardcode Wi-Fi credentials in source.
- Do not make firmware depend on database or dashboard concerns.
- Do not start with multiple boards at once.

## Next documentation to add
- `docs/iot/mqtt-topic-contract.md`
- `docs/iot/esp32-c6-onboarding.md`
- `docs/iot/device-secrets-and-wifi.md`