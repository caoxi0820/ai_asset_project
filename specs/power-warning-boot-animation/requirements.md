# Requirements Document

## Introduction

This feature adds a power compatibility warning display to the FireOS boot animation system. When the device detects an incompatible power supply (indicated via system property), a static warning image is displayed instead of the normal boot animation. The boot animation process can also be held indefinitely to prevent progression to the home screen, allowing the warning to remain visible until the system resolves the power issue.

## Glossary

- **Boot_Animation_Process**: The Android native service (`bootanimation`) responsible for rendering visual content on screen during device boot, implemented as a thread in `frameworks/base/cmds/bootanimation/`.
- **Power_Warning_Property**: The Android system property `sys.power.warning_zip` whose value is a file path (e.g., `/system/media/power_warning/en_US/warning.zip`) pointing to a power warning zip file. Boot animation reads this property and uses the value directly as the path from which to load the warning zip.
- **Hold_Property**: The Android system property `sys.bootanim.hold` that controls whether the boot animation process should ignore exit signals.
- **Warning_Zip**: A zip file located at the path specified by Power_Warning_Property, containing a static image to be displayed as a power incompatibility warning, following the same format as standard boot animation zip files (containing `desc.txt` and image frames).
- **Exit_Property**: The existing Android system property `service.bootanim.exit` that signals the boot animation process to terminate.
- **BootAnimation_Class**: The core C++ class (`BootAnimation`) in `BootAnimation.h`/`BootAnimation.cpp` that manages the boot animation rendering lifecycle.

## Requirements

### Requirement 1: Power Warning Property Check

**User Story:** As a system engineer, I want the boot animation process to check for a power warning property at startup, so that incompatible power conditions can be communicated to the user before normal boot animation begins.

#### Acceptance Criteria

1. WHEN the Boot_Animation_Process starts its thread loop, THE BootAnimation_Class SHALL read the value of Power_Warning_Property before any normal boot animation rendering begins.
2. IF Power_Warning_Property contains a non-empty string (length greater than 0) after being read, THEN THE BootAnimation_Class SHALL treat that string as the file path to the Warning_Zip, store it for later use, and set the internal boolean flag indicating that a power warning display is required to true.
3. IF Power_Warning_Property is empty (length 0) or not set (property_get returns default empty value), THEN THE BootAnimation_Class SHALL set the internal boolean flag to false and proceed with normal boot animation rendering.
4. THE BootAnimation_Class SHALL provide a dedicated function to check the Power_Warning_Property value, store the resulting path, and return whether a warning display is required.

### Requirement 2: Power Warning Image Display

**User Story:** As a system engineer, I want the power warning image to be displayed using the existing zip-based rendering infrastructure, so that an incompatible power condition is communicated visually to the user during boot.

#### Acceptance Criteria

1. WHEN the power warning flag is true, THE BootAnimation_Class SHALL load the zip file from the path obtained from Power_Warning_Property (as read in Requirement 1) using the existing `loadAnimation()` mechanism.
2. WHEN the Warning_Zip is loaded, THE BootAnimation_Class SHALL render the first image frame from the zip as a static display on screen, repeating the same frame on every render cycle without advancing to subsequent frames.
3. WHEN rendering the power warning image, THE BootAnimation_Class SHALL use the same OpenGL ES texture rendering approach used for normal boot animation frames.
4. WHILE the power warning image is active, THE BootAnimation_Class SHALL use the existing `playAnimation()` loop mechanism to continuously re-render the static warning frame, keeping the image visible on screen as long as the rendering thread is alive.

### Requirement 3: Boot Animation Hold Mechanism

**User Story:** As a system engineer, I want the boot animation hold mechanism to prevent exit from within the `checkExit()` function, so that the boot animation process continues running and the warning image remains visible on screen.

#### Acceptance Criteria

1. WHEN Hold_Property equals "1", THE BootAnimation_Class `checkExit()` function SHALL return immediately without evaluating Exit_Property or calling `requestExit()`, keeping the rendering thread alive.
2. WHEN Hold_Property is not set, is empty, or equals "0", THE BootAnimation_Class `checkExit()` function SHALL proceed with existing exit logic (reading Exit_Property and calling `requestExit()` if indicated).
3. THE BootAnimation_Class SHALL evaluate Hold_Property as the first check inside the `checkExit()` function, before any other exit condition is evaluated.
4. THE BootAnimation_Class `checkExit()` hold mechanism SHALL apply regardless of whether the power warning display is active; the hold check is a simple property read with no dependency on the power warning flag.
5. WHILE Hold_Property equals "1", THE BootAnimation_Class SHALL continue its rendering loop indefinitely because `checkExit()` never triggers `requestExit()`, keeping any currently displayed content (including the power warning image) visible on screen.
6. FOR the initial implementation, THE BootAnimation_Class SHALL temporarily hardcode Hold_Property to return the constant value "1", ensuring that `checkExit()` always returns immediately without allowing exit.
7. WHEN Hold_Property transitions from "1" to "0" or is unset, THE BootAnimation_Class `checkExit()` function SHALL resume normal exit evaluation on the next invocation, allowing the boot animation process to terminate when Exit_Property signals exit.

### Requirement 4: Execution Priority

**User Story:** As a system engineer, I want the power warning check to execute before all other boot animation logic, so that the warning is the first visual feedback the user receives.

#### Acceptance Criteria

1. THE BootAnimation_Class SHALL execute the power warning property check as the first operation in the `threadLoop()` method, before any call to `findBootAnimationFile()`, `movie()`, or `android()`.
2. IF the power warning flag is true, THEN THE BootAnimation_Class SHALL skip the normal boot animation file selection and rendering logic. The normal boot animation path SHALL NEVER be taken when the power warning flag is active.
3. IF the power warning flag is false, THEN THE BootAnimation_Class SHALL proceed with the existing boot animation rendering logic with no change to current behavior.
4. IF the power warning property is undefined or cannot be read, THEN THE BootAnimation_Class SHALL treat the value as false and proceed with normal boot animation rendering.

### Requirement 5: Hardcoded Power Warning Path for Initial Implementation

**User Story:** As a system engineer, I want the power warning zip path to be temporarily hardcoded for the initial implementation, so that I can validate the rendering behavior before integrating with the power management subsystem that will set the property dynamically.

#### Acceptance Criteria

1. THE BootAnimation_Class SHALL define the path `/system/media/power_warning/en_US/warning.zip` as a named constant (consistent with existing path constants such as SYSTEM_BOOTANIMATION_FILE) for code clarity and maintainability.
2. FOR the initial implementation, THE BootAnimation_Class SHALL temporarily hardcode the Power_Warning_Property reading to return the named constant path value, simulating the property being set to this value by the power management subsystem.
3. THE named constant SHALL be used as the single source of truth for the hardcoded path value within the initial implementation.
