# Implementation Plan: pwr_adp_watchdog

## Overview

Implement a native C++ daemon for FireOS 8 that plays a power warning audio on boot and shuts down the device after a 10-minute delay. The service consists of three files: an Android.bp build file, an .rc init service declaration, and the main daemon source file. Tasks are ordered to build infrastructure first, then the service logic, followed by build verification.

## Tasks

- [ ] 1. Create directory structure and build configuration
  - [ ] 1.1 Create Android.bp build file
    - Create `frameworks/base/cmds/pwr_adp_watchdog/Android.bp`
    - Define `cc_binary` target named `pwr_adp_watchdog`
    - Source: `pwr_adp_watchdog.cpp`
    - Shared libs: `libcutils`, `liblog`
    - Include `init_rc` reference to `pwr_adp_watchdog.rc`
    - Add cflags: `-Wall`, `-Werror`, `-Wunused`, `-Wunreachable-code`
    - _Requirements: 1.1, 1.2_

  - [ ] 1.2 Create init service declaration file
    - Create `frameworks/base/cmds/pwr_adp_watchdog/pwr_adp_watchdog.rc`
    - Declare service pointing to `/system/bin/pwr_adp_watchdog`
    - Set `class main`, `user media`, `group audio system`, `oneshot`, `disabled`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 2. Implement main daemon source
  - [ ] 2.1 Implement pwr_adp_watchdog.cpp with full watchdog logic
    - Create `frameworks/base/cmds/pwr_adp_watchdog/pwr_adp_watchdog.cpp`
    - Include headers: `cutils/properties.h`, `log/log.h`, `stdio.h`, `stdlib.h`, `string.h`, `unistd.h`, `time.h`
    - Define constants: `PROP_WARNING_WAV`, `PROP_AUDIO_INIT`, `PROP_POWERCTL`, `DEFAULT_WAV_PATH`, timeout/interval values
    - Implement `get_warning_wav_path()`: read `sys.power.warning_wav`, fall back to default path, log resolved path
    - Implement `wait_for_audio_init()`: poll `sys.audio_init` every 1s, log every 30s, timeout at 300s
    - Implement `play_warning_audio()`: check file access, build tinyplay command, popen/pclose, check exit status
    - Implement `initiate_shutdown()`: log message, `property_set("sys.powerctl", "shutdown")`
    - Implement `main()`: orchestrate full sequence — get path, wait for audio, play audio, sleep 600s, shutdown
    - Use ALOGI/ALOGE with LOG_TAG "pwr_adp_watchdog" for all logging
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [ ]* 2.2 Write property test for poll loop correctness
    - **Property 1: Poll loop exits only on "true"**
    - Verify `wait_for_audio_init()` only returns true when property value is exactly "true"
    - Generate random sequences of non-"true" strings followed by "true" and verify behavior
    - **Validates: Requirements 3.1, 3.3**

  - [ ]* 2.3 Write property test for periodic logging
    - **Property 2: Periodic logging during wait**
    - For random wait durations (1-300s), verify log count equals floor(N / 30)
    - **Validates: Requirements 6.2**

- [ ] 3. Checkpoint - Verify build compiles successfully
  - Ensure the module builds with `mm` or equivalent from `frameworks/base/cmds/pwr_adp_watchdog/`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- The daemon is a single-file implementation given its sequential, straightforward nature
- Property tests require mocking `property_get` which may need a test harness or on-device integration
- The checkpoint task verifies the Android.bp build configuration produces a valid binary

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3"] }
  ]
}
```
