# Requirements Document

## Introduction

VibeSurveyor is a native iOS application built for field surveyors who need to capture geotagged, annotated photographs. The app combines a full-screen camera preview with live telemetry data — GPS coordinates, altitude, compass bearing, and device tilt angles — and permanently stamps all telemetry onto each captured photo. Photos are organised into named projects and stored in the app's Documents directory with a structured filename convention. The app is built entirely with native Apple frameworks (SwiftUI, AVFoundation, CoreLocation, CoreMotion) and has zero external dependencies.

## Glossary

- **App**: The VibeSurveyor iOS application
- **CameraManager**: The AVFoundation component responsible for camera session setup and photo capture
- **LocationManager**: The CoreLocation component responsible for GPS, altitude, and heading data
- **MotionManager**: The CoreMotion component responsible for device pitch and roll data
- **ImageWatermarkProcessor**: The component responsible for compositing telemetry text onto a captured photo
- **Project**: A named survey session used to group captured photos
- **Telemetry**: The set of sensor data stamped onto a photo: coordinates, altitude, bearing, pitch, roll, and timestamp
- **Watermark**: The rendered telemetry text permanently drawn onto a captured JPEG image
- **Documents Directory**: The app's sandboxed file-system directory where photos are saved
- **Bearing**: Compass heading in degrees (0–360), also referred to as azimuth
- **Pitch**: Forward/backward tilt angle of the device in degrees, used for elevation/inclination measurement
- **Roll**: Left/right tilt angle of the device in degrees
- **Decimal Degrees**: GPS coordinate format expressing latitude and longitude as floating-point numbers

---

## Requirements

### Requirement 1: Camera Preview

**User Story:** As a surveyor, I want a full-screen live camera preview, so that I can frame my subject accurately in the field.

#### Acceptance Criteria

1. WHEN the App launches and camera permission is granted, THE CameraManager SHALL display a full-screen AVCaptureVideoPreviewLayer occupying the entire device screen.
2. WHEN the device is in portrait orientation, THE CameraManager SHALL maintain the camera preview in full-screen without letterboxing or cropping the viewfinder area.
3. WHEN camera permission is denied by the user, THE App SHALL display a permission-error message explaining that camera access is required and providing a button to open iOS Settings.
4. IF the device has no available camera, THEN THE App SHALL display an informational message stating that no camera hardware was detected.

---

### Requirement 2: Target Grid Overlay

**User Story:** As a surveyor, I want a crosshair grid overlay on the camera preview, so that I can precisely aim at survey targets in the field.

#### Acceptance Criteria

1. THE App SHALL render a crosshair overlay consisting of one horizontal line and one vertical line intersecting at the exact centre of the screen, displayed on top of the camera preview at all times.
2. THE App SHALL render the crosshair lines using a colour and opacity that provides sufficient contrast against both light and dark backgrounds.
3. WHEN a photo is captured, THE App SHALL NOT include the crosshair overlay in the saved image file.

---

### Requirement 3: Live GPS Telemetry Display

**User Story:** As a surveyor, I want to see live GPS coordinates, altitude, and compass bearing on screen, so that I can confirm my position before capturing a photo.

#### Acceptance Criteria

1. WHEN location permission is granted and a GPS fix is available, THE LocationManager SHALL provide latitude in Decimal Degrees updated at least once per second.
2. WHEN location permission is granted and a GPS fix is available, THE LocationManager SHALL provide longitude in Decimal Degrees updated at least once per second.
3. WHEN location permission is granted and a GPS fix is available, THE LocationManager SHALL provide altitude in metres above sea level updated at least once per second.
4. WHEN the device heading hardware is available, THE LocationManager SHALL provide compass bearing in degrees (0–360) updated at least once per second.
5. WHEN location permission is denied by the user, THE App SHALL display "GPS Unavailable" in place of all GPS telemetry fields.
6. IF a GPS fix cannot be acquired within the current session, THEN THE App SHALL display "Acquiring…" in place of coordinate and altitude values.
7. IF the device has no heading hardware, THEN THE App SHALL display "N/A" in place of the bearing value.

---

### Requirement 4: Live Motion Telemetry Display

**User Story:** As a surveyor, I want to see live device pitch and roll angles on screen, so that I can measure inclination and ensure the camera is level before capturing.

#### Acceptance Criteria

1. WHEN CoreMotion is available on the device, THE MotionManager SHALL provide device pitch in degrees updated at least once per second.
2. WHEN CoreMotion is available on the device, THE MotionManager SHALL provide device roll in degrees updated at least once per second.
3. IF CoreMotion is unavailable on the device, THEN THE App SHALL display "N/A" in place of pitch and roll values.

---

### Requirement 5: Live Timestamp Display

**User Story:** As a surveyor, I want to see the current date and time on screen, so that I have an accurate temporal reference for each observation.

#### Acceptance Criteria

1. THE App SHALL display the current date in the format `YYYY-MM-DD` updated once per second.
2. THE App SHALL display the current time in the format `HH:MM:SS` (24-hour) updated once per second.

---

### Requirement 6: Telemetry Overlay UI

**User Story:** As a surveyor, I want all telemetry data displayed as a readable overlay on the camera preview, so that I can monitor all measurements at a glance without obscuring the subject.

#### Acceptance Criteria

1. THE App SHALL display all telemetry fields — latitude, longitude, altitude, bearing, pitch, roll, date, and time — as a text overlay rendered on top of the camera preview.
2. THE App SHALL position the telemetry overlay in a region of the screen that does not obstruct the crosshair centre point.
3. THE App SHALL render the telemetry text using a font size and colour that is legible on the camera preview without requiring user interaction.

---

### Requirement 7: Photo Capture

**User Story:** As a surveyor, I want to capture a photo by pressing a shutter button, so that I can record my observation with a single tap.

#### Acceptance Criteria

1. WHEN the user taps the shutter button, THE CameraManager SHALL capture a full-resolution still image using AVCapturePhotoOutput.
2. WHEN a photo is captured, THE CameraManager SHALL trigger the ImageWatermarkProcessor to stamp all current telemetry onto the image before saving.
3. WHEN a photo is being captured and processed, THE App SHALL disable the shutter button to prevent duplicate captures until the current capture completes.
4. IF photo capture fails due to a hardware or session error, THEN THE App SHALL display an error message describing the failure.

---

### Requirement 8: Telemetry Watermark

**User Story:** As a surveyor, I want all telemetry data permanently stamped onto each captured photo, so that the image file is self-documenting and the data cannot be separated from the photo.

#### Acceptance Criteria

1. WHEN a photo is captured, THE ImageWatermarkProcessor SHALL render the following telemetry fields as text directly onto the image: latitude, longitude, altitude, bearing, pitch, roll, date, time, and project name.
2. THE ImageWatermarkProcessor SHALL render the watermark text in a font size proportional to the captured image resolution such that the text is legible at the image's native resolution.
3. THE ImageWatermarkProcessor SHALL render the watermark text with a semi-transparent background behind each line of text to ensure legibility against all background colours.
4. WHEN telemetry stamping is complete, THE ImageWatermarkProcessor SHALL return the watermarked image as JPEG data ready for saving.

---

### Requirement 9: Project Management

**User Story:** As a surveyor, I want to create and select a named project, so that I can organise photos by survey session.

#### Acceptance Criteria

1. THE App SHALL provide a UI element that allows the user to enter a project name as a free-text string.
2. WHEN a project name is entered, THE App SHALL use that name as a prefix in the filename of all subsequently captured photos.
3. THE App SHALL persist the most recently used project name across app launches using UserDefaults.
4. WHEN no project name has been entered, THE App SHALL use "NoProject" as the default project name prefix.

---

### Requirement 10: Photo File Naming and Storage

**User Story:** As a surveyor, I want each photo saved with a structured filename in the app's Documents directory, so that I can identify and retrieve photos without opening the app.

#### Acceptance Criteria

1. WHEN a watermarked photo is ready to save, THE App SHALL save it to the app's Documents directory as a JPEG file.
2. THE App SHALL name each saved photo file using the convention: `{ProjectName}_{YYYYMMDD}_{HHmmss}_{Latitude}_{Longitude}.jpg`, where latitude and longitude are formatted to 6 decimal places.
3. WHEN a file with the same name already exists in the Documents directory, THE App SHALL append a numeric suffix to make the filename unique.
4. IF saving the file to the Documents directory fails, THEN THE App SHALL display an error message describing the failure.

---

### Requirement 11: iOS Permissions

**User Story:** As a surveyor, I want the app to request only the permissions it needs, so that I can trust the app and grant access with confidence.

#### Acceptance Criteria

1. THE App SHALL include the `NSCameraUsageDescription` key in Info.plist with a description explaining why camera access is required.
2. THE App SHALL include the `NSLocationWhenInUseUsageDescription` key in Info.plist with a description explaining why location access is required.
3. THE App SHALL include the `NSMotionUsageDescription` key in Info.plist with a description explaining why motion sensor access is required.
4. WHEN any required permission is not yet determined, THE App SHALL request that permission at the point of first use.
5. WHEN a permission request is presented to the user, THE App SHALL display the system permission dialog using the description strings from Info.plist.

---

### Requirement 12: Zero External Dependencies

**User Story:** As a build engineer, I want the app to compile with only native Apple frameworks, so that the CI/CD pipeline requires no package managers or third-party tooling.

#### Acceptance Criteria

1. THE App SHALL import only frameworks included in the iOS 15+ SDK: SwiftUI, AVFoundation, CoreLocation, CoreMotion, Combine, UIKit, Foundation, and CoreGraphics.
2. THE App SHALL include no `Package.swift`, `Podfile`, `Cartfile`, or any other package-manager manifest file.
3. THE App SHALL compile successfully with `xcodebuild` using only the Xcode toolchain available on a standard GitHub Actions macOS runner.

---

### Requirement 13: GitHub Actions CI/CD Build

**User Story:** As a build engineer, I want a GitHub Actions workflow that builds the app and produces a distributable .ipa file, so that the build process is automated and reproducible.

#### Acceptance Criteria

1. THE App SHALL include a `.github/workflows/build.yml` file that defines a GitHub Actions workflow.
2. WHEN the workflow is triggered, THE build system SHALL run `xcodebuild` with the `archive` action to produce an `.xcarchive`.
3. WHEN the archive step succeeds, THE build system SHALL run `xcodebuild -exportArchive` to export an `.ipa` file.
4. THE build workflow SHALL use a `macos-latest` or `macos-14` GitHub Actions runner.
5. THE build workflow SHALL upload the produced `.ipa` as a GitHub Actions build artifact.
6. IF the `xcodebuild` step fails, THEN THE build workflow SHALL surface the build log as part of the workflow failure output.

---

### Requirement 14: Reactive Data Flow

**User Story:** As a developer, I want all sensor data to flow reactively through ObservableObject classes, so that the UI automatically updates whenever sensor values change.

#### Acceptance Criteria

1. THE CameraManager SHALL be implemented as a class conforming to `ObservableObject`, publishing state changes via `@Published` properties.
2. THE LocationManager SHALL be implemented as a class conforming to `ObservableObject`, publishing latitude, longitude, altitude, and bearing as `@Published` properties.
3. THE MotionManager SHALL be implemented as a class conforming to `ObservableObject`, publishing pitch and roll as `@Published` properties.
4. THE ContentView SHALL consume all manager instances as `@StateObject` or `@ObservedObject` properties so that any published change triggers an automatic SwiftUI view refresh.

---

### Requirement 15: Error Handling

**User Story:** As a surveyor, I want the app to remain functional and informative when sensors fail, so that I can continue working even in degraded conditions.

#### Acceptance Criteria

1. WHEN the CameraManager encounters a session interruption, THE CameraManager SHALL publish an error state and THE App SHALL display a descriptive message.
2. WHEN the LocationManager encounters a location error, THE LocationManager SHALL publish the error description and THE App SHALL display it in the telemetry overlay area.
3. WHEN the MotionManager fails to start device motion updates, THE MotionManager SHALL publish an error state and THE App SHALL display "Motion Unavailable" in place of pitch and roll values.
4. THE App SHALL handle all sensor errors gracefully without crashing, maintaining a usable UI state at all times.
