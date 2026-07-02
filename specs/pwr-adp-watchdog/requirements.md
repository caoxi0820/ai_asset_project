# Requirements Document

## Introduction

This feature introduces a new native init service called `pwr_adp_watchdog` for FireOS 8. The service acts as a power adapter watchdog that plays an audio warning when the device boots, then initiates a device shutdown after a configurable delay. The service is started automatically on boot via an `.rc` file, reads a system property to determine the warning audio file path, waits for the audio subsystem to initialize, plays the warning audio, and then powers off the device after a 10-minute delay.

## Glossary

- **Pwr_Adp_Watchdog_Service**: The native C/C++ daemon (`pwr_adp_watchdog`) managed by the Android init process, responsible for playing a power warning audio file and subsequently shutting down the device.
- **Init_RC_File**: The Android init resource configuration file (`.rc`) that declares the `pwr_adp_watchdog` service, its class, user, group, and startup behavior for the init process.
- **Warning_Wav_Property**: The Android system property `sys.power.warning_wav` whose value is a file path pointing to the audio file to be played as a power warning (e.g., `/system/media/power_warning/en_US/warning.wav`).
- **Audio_Init_Property**: The Android system property `sys.audio_init` that indicates whether the audio subsystem has completed initialization. The value "true" signals readiness.
- **Powerctl_Property**: The Android system property `sys.powerctl` used to command the init process to perform power state transitions. Setting this property to "shutdown" triggers a device power-off sequence.
- **Audio_Subsystem**: The system component responsible for audio playback hardware and software initialization, whose readiness is signaled by Audio_Init_Property.

## Requirements

### Requirement 1: Service Declaration and Auto-Start

**User Story:** As a system engineer, I want `pwr_adp_watchdog` to be declared as an init service that starts automatically on boot, so that the power warning sequence begins without manual intervention.

#### Acceptance Criteria

1. THE Init_RC_File SHALL declare `pwr_adp_watchdog` as a service with a defined class that causes it to start automatically during the default boot sequence.
2. THE Init_RC_File SHALL specify the executable path for Pwr_Adp_Watchdog_Service pointing to the compiled binary location (e.g., `/system/bin/pwr_adp_watchdog`).
3. THE Init_RC_File SHALL declare the service as `oneshot`, indicating that init does not restart the service if it exits.
4. THE Init_RC_File SHALL specify appropriate user and group permissions for Pwr_Adp_Watchdog_Service to access audio playback resources and system properties.

### Requirement 2: Read Warning Audio Path on Startup

**User Story:** As a system engineer, I want the service to read the warning audio file path from a system property at startup, so that the audio file location is configurable without recompiling the binary.

#### Acceptance Criteria

1. WHEN Pwr_Adp_Watchdog_Service starts, THE Pwr_Adp_Watchdog_Service SHALL read the value of Warning_Wav_Property and store the result as the path to the warning audio file.
2. IF Warning_Wav_Property is empty or not set, THEN THE Pwr_Adp_Watchdog_Service SHALL use the default path `/system/media/power_warning/en_US/warning.wav` as the warning audio file path.
3. FOR the initial implementation, THE Pwr_Adp_Watchdog_Service SHALL hardcode the warning audio file path to `/system/media/power_warning/en_US/warning.wav`, simulating the property being set to this value.
4. THE Pwr_Adp_Watchdog_Service SHALL read Warning_Wav_Property exactly once at startup and retain the stored path for the duration of the process lifecycle.

### Requirement 3: Wait for Audio Subsystem Initialization

**User Story:** As a system engineer, I want the service to wait until the audio subsystem is ready before attempting playback, so that audio playback does not fail due to uninitialized hardware or software.

#### Acceptance Criteria

1. AFTER reading the warning audio file path, THE Pwr_Adp_Watchdog_Service SHALL enter a polling loop that checks Audio_Init_Property for the value "true".
2. WHILE Audio_Init_Property does not equal "true", THE Pwr_Adp_Watchdog_Service SHALL continue polling at a regular interval (e.g., every 1 second).
3. WHEN Audio_Init_Property equals "true", THE Pwr_Adp_Watchdog_Service SHALL exit the polling loop and proceed to audio playback.
4. IF Audio_Init_Property does not become "true" within 5 minutes (300 seconds) of entering the polling loop, THEN THE Pwr_Adp_Watchdog_Service SHALL log an error message indicating a timeout and proceed to the shutdown step, skipping audio playback.

### Requirement 4: Play Warning Audio

**User Story:** As a system engineer, I want the service to play the warning audio file once the audio subsystem is ready, so that the user receives an audible power warning.

#### Acceptance Criteria

1. WHEN Audio_Init_Property equals "true" and the polling loop exits successfully, THE Pwr_Adp_Watchdog_Service SHALL initiate playback of the audio file at the stored warning audio file path.
2. THE Pwr_Adp_Watchdog_Service SHALL play the audio file to completion before proceeding to the next step.
3. IF the audio file does not exist at the stored path or cannot be opened, THEN THE Pwr_Adp_Watchdog_Service SHALL log an error message and proceed to the shutdown delay step without playing audio.
4. IF audio playback fails during execution, THEN THE Pwr_Adp_Watchdog_Service SHALL log an error message and proceed to the shutdown delay step.

### Requirement 5: Shutdown After Delay

**User Story:** As a system engineer, I want the device to shut down automatically after a fixed delay following audio playback, so that the device powers off gracefully to protect against the power adapter issue.

#### Acceptance Criteria

1. AFTER audio playback completes (or is skipped due to error), THE Pwr_Adp_Watchdog_Service SHALL wait for 10 minutes (600 seconds) before initiating shutdown.
2. WHEN the 10-minute delay expires, THE Pwr_Adp_Watchdog_Service SHALL set Powerctl_Property to the value "shutdown" to trigger device power-off.
3. THE Pwr_Adp_Watchdog_Service SHALL log an informational message before setting Powerctl_Property, indicating that the shutdown sequence is being initiated.
4. AFTER setting Powerctl_Property to "shutdown", THE Pwr_Adp_Watchdog_Service SHALL exit cleanly, as the init process will handle the actual power-off sequence.

### Requirement 6: Logging and Diagnostics

**User Story:** As a system engineer, I want the service to produce log messages at each lifecycle stage, so that I can diagnose issues during development and field debugging.

#### Acceptance Criteria

1. WHEN Pwr_Adp_Watchdog_Service starts, THE Pwr_Adp_Watchdog_Service SHALL log the resolved warning audio file path.
2. WHILE waiting for Audio_Init_Property, THE Pwr_Adp_Watchdog_Service SHALL log a message periodically (every 30 seconds) indicating it is still waiting for audio initialization.
3. WHEN Audio_Init_Property becomes "true", THE Pwr_Adp_Watchdog_Service SHALL log a message indicating audio subsystem readiness.
4. WHEN audio playback begins, THE Pwr_Adp_Watchdog_Service SHALL log the file path being played.
5. WHEN the 10-minute shutdown delay begins, THE Pwr_Adp_Watchdog_Service SHALL log a message indicating the countdown to shutdown has started.
6. THE Pwr_Adp_Watchdog_Service SHALL use the Android logging system (ALOG macros) with the log tag "pwr_adp_watchdog" for all log output.
