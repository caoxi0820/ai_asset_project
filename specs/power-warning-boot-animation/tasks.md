# Implementation Plan: Power Warning Boot Animation

## Overview

This implementation adds power warning display capability to the FireOS boot animation system. The work modifies `BootAnimation.h` and `BootAnimation.cpp` to check a system property at startup, display a static warning image from a zip file, and hold the boot animation process from exiting. The property value IS the zip file path — boot animation reads the property and uses the value directly as the path. Both the warning zip path and hold property are temporarily hardcoded for the initial implementation. Testing uses Google Test (gtest) with property-based test patterns for the decision logic.

## Tasks

- [ ] 1. Add constants, member variables, and method declaration to BootAnimation.h
  - [ ] 1.1 Add new constants, member variables, and method declaration to BootAnimation.h
    - Add `POWER_WARNING_FILE[]` constant with path `/system/media/power_warning/en_US/warning.zip`
    - Add `POWER_WARNING_PROP_NAME[]` constant with value `sys.power.warning_zip`
    - Add `HOLD_PROP_NAME[]` constant with value `sys.bootanim.hold`
    - Add `bool mPowerWarningActive` member variable (initialized to false)
    - Add `String8 mPowerWarningPath` member variable to store the property value (which IS the zip path)
    - Add `bool checkPowerWarning()` method declaration to the private section
    - _Requirements: 1.4, 5.1_

- [ ] 2. Implement checkPowerWarning() and modify threadLoop()
  - [ ] 2.1 Implement the checkPowerWarning() method in BootAnimation.cpp
    - Add the three `static const char` constants (`POWER_WARNING_FILE`, `POWER_WARNING_PROP_NAME`, `HOLD_PROP_NAME`) near existing path constants at the top of the file
    - Implement `checkPowerWarning()`:
      - Read `POWER_WARNING_PROP_NAME` via `property_get()` with empty default
      - FOR INITIAL IMPLEMENTATION: hardcode the value to `POWER_WARNING_FILE` constant instead of reading the actual property
      - If value length > 0: store value directly in `mPowerWarningPath`, set `mPowerWarningActive = true`
      - If value length == 0: set `mPowerWarningActive = false`
      - Return `mPowerWarningActive`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 5.2, 5.3_

  - [ ] 2.2 Modify threadLoop() to call checkPowerWarning() first and use mPowerWarningPath
    - Insert `checkPowerWarning()` call as the first operation in `threadLoop()`, before the existing `mZipFileName.isEmpty()` check
    - If `mPowerWarningActive` is true:
      - Call `loadAnimation(mPowerWarningPath)` to load the warning zip from the stored path
      - Call `playAnimation(*warningAnimation)`, release animation, cleanup EGL, return false
    - When `mPowerWarningActive` is true, the normal boot animation path (movie/android) is NEVER reached
    - If `mPowerWarningActive` is false: proceed with existing logic unchanged (`movie()` or `android()`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 4.1, 4.2, 4.3, 4.4_

  - [ ] 2.3 Write property test for checkPowerWarning() decision logic
    - **Property 1: Non-empty property value activates warning and stores path**
    - **Property 2: Empty property value deactivates warning**
    - Generate random strings of varying lengths (0 to 255 chars, including whitespace-only, path-like, garbage bytes) and verify: non-empty activates and stores value as mPowerWarningPath, empty deactivates
    - **Validates: Requirements 1.2, 1.3, 1.5**

- [ ] 3. Modify checkExit() to support hold mechanism
  - [ ] 3.1 Add hold property check to checkExit() in BootAnimation.cpp
    - Read `HOLD_PROP_NAME` via `property_get()` with "0" as default value
    - FOR INITIAL IMPLEMENTATION: hardcode the value to "1" (ensuring checkExit always returns immediately)
    - If value equals "1": return immediately without evaluating `EXIT_PROP_NAME` or calling `requestExit()`
    - If value is not "1": proceed with existing exit logic (read EXIT_PROP_NAME, call requestExit if indicated)
    - The hold check must be the first operation inside `checkExit()`, before any other exit condition
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ] 3.2 Write property test for checkExit() hold logic
    - **Property 3: Hold property prevents exit**
    - **Property 4: Non-hold state allows normal exit evaluation**
    - Generate random hold property values and verify checkExit behavior: "1" always prevents exit, anything else allows normal evaluation
    - **Validates: Requirements 3.1, 3.2, 3.5, 3.7**

- [ ] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Initialize mPowerWarningActive/mPowerWarningPath and add error handling
  - [ ] 5.1 Initialize members in constructor and add logging
    - Initialize `mPowerWarningActive = false` in the BootAnimation constructor's initializer list
    - Initialize `mPowerWarningPath` as empty String8 in the constructor
    - Add `ALOGW` for cases where `sys.power.warning_zip` property cannot be read (treat as empty)
    - Add `ALOGW` for cases where `sys.bootanim.hold` property cannot be read (treat as "0")
    - _Requirements: 1.3, 2.4, 4.4_

  - [ ] 5.2 Write unit tests for warning display path and error behavior
    - **Property 5: Warning active skips normal animation**
    - **Property 6: Warning inactive preserves normal behavior**
    - Test that when mPowerWarningActive is true and zip loads successfully from mPowerWarningPath, normal animation path is not invoked
    - Test that when mPowerWarningActive is false, existing animation logic executes unchanged
    - **Validates: Requirements 4.2, 4.3, 2.4**

- [ ] 6. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The implementation language is C++ (matching the existing codebase)
- The value of `sys.power.warning_zip` IS the file path to the zip — boot animation reads the property and uses the value directly as the path to load from, stored in `mPowerWarningPath`
- Both `sys.power.warning_zip` and `sys.bootanim.hold` are temporarily hardcoded for initial implementation; property-based reading code is present but overridden
- When property is set, the zip file is guaranteed to exist — no load-failure handling needed

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1", "3.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "3.2"] },
    { "id": 3, "tasks": ["5.1"] },
    { "id": 4, "tasks": ["5.2"] }
  ]
}
```
