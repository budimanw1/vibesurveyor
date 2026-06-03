# Implementation Plan: VibeSurveyor

## Overview

Implement the VibeSurveyor iOS app file-by-file in Swift/SwiftUI, starting with the project scaffold and data model, then each manager, the watermark processor, the UI layer, file persistence, and finally CI/CD. Each step builds on the previous one and ends with the components wired together in `ContentView`. All code uses only iOS 15+ SDK frameworks — no external dependencies.

---

## Task Dependency Graph

```
1 -> 2.1 -> 2.2
1 -> 3.1 -> 3.2
1 -> 4.1 -> 4.2
1 -> 5.1 -> 5.2
1 -> 6.1 -> 6.2
2.1, 3.1, 4.1, 5.1, 6.1 -> 7
7 -> 8.1 -> 8.2 -> 8.3
7 -> 9.1
7 -> 9.2
7 -> 9.3
9.1, 9.2, 9.3, 8.2, 10.1, 10.2 -> 10.3
10.3, 11 -> 12
12 -> 13.1 -> 13.2
12 -> 14.1
12 -> 14.2
14.1, 14.2 -> 14.3
13.2, 14.3 -> 15
```

---

## Tasks

- [x] 1. Create the Xcode project scaffold and configure build settings
  - Create a new Xcode project named `VibeSurveyor` using the iOS App template with SwiftUI interface and Swift language
  - Set the deployment target to iOS 15.0
  - Remove the auto-generated `ContentView.swift` placeholder content (keep the file, clear its body)
  - Add the following `Info.plist` usage description keys:
    - `NSCameraUsageDescription`: "VibeSurveyor needs camera access to capture survey photos."
    - `NSLocationWhenInUseUsageDescription`: "VibeSurveyor needs your location to stamp GPS coordinates on survey photos."
    - `NSMotionUsageDescription`: "VibeSurveyor needs motion sensor access to stamp pitch and roll angles on survey photos."
  - Confirm the project folder contains only native Apple framework references (no `Package.swift`, no `Podfile`)
  - _Requirements: 11.1, 11.2, 11.3, 12.2_

- [x] 2. Implement `TelemetrySnapshot.swift` — core data model
  - [x] 2.1 Create `TelemetrySnapshot.swift` with the struct definition
    - Define `TelemetrySnapshot` as a `struct` with fields: `latitude: Double?`, `longitude: Double?`, `altitude: Double?`, `bearing: Double?`, `pitch: Double?`, `roll: Double?`, `timestamp: Date`, `projectName: String`
    - Add a `formattedDate: String` computed property returning `timestamp` formatted as `"YYYY-MM-DD"` using `DateFormatter` with `"yyyy-MM-dd"` format and `Locale(identifier: "en_US_POSIX")`
    - Add a `formattedTime: String` computed property returning `timestamp` formatted as `"HH:MM:SS"` using `DateFormatter` with `"HH:mm:ss"` format and `Locale(identifier: "en_US_POSIX")`
    - Add a `filenameComponent: String` computed property building the filename as `"{projectName}_{YYYYMMDD}_{HHmmss}_{lat6dp}_{lon6dp}.jpg"` where lat/lon are formatted to 6 decimal places; fall back to `"0.000000"` for nil coordinates
    - Add a `watermarkLines: [String]` computed property returning an array of 9 formatted label: value strings for all telemetry fields, using `"N/A"` for nil optional values
    - _Requirements: 5.1, 5.2, 8.1, 9.2, 10.2_

  - [ ]* 2.2 Write property tests for `TelemetrySnapshot` in `TelemetrySnapshotTests.swift`
    - **Property 9: Date format matches YYYY-MM-DD** — for 100 random `Date` values, assert `formattedDate` matches regex `^\d{4}-\d{2}-\d{2}$`
    - **Property 10: Time format matches HH:MM:SS** — for 100 random `Date` values, assert `formattedTime` matches regex `^\d{2}:\d{2}:\d{2}$`
    - **Property 5: Filename matches the required convention** — for 100 random lat/lon/date combinations, assert `filenameComponent` matches regex `^[^_]+_\d{8}_\d{6}_-?\d+\.\d{6}_-?\d+\.\d{6}\.jpg$`
    - **Property 7: Project name is filename prefix** — for 100 random project names, assert `filenameComponent` starts with `"{projectName}_"`
    - **Property 11: Watermark lines contain all fields** — for 100 random snapshots, assert `watermarkLines.count == 9` and no line is empty
    - // Feature: vibesurveyor, Property 5, 7, 9, 10, 11
    - _Requirements: 5.1, 5.2, 9.2, 10.2_

- [x] 3. Implement `LocationManager.swift`
  - [x] 3.1 Create `LocationManager.swift`
    - Import `CoreLocation` and `Combine`
    - Define `LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate`
    - Add `@Published` properties: `latitude: Double?`, `longitude: Double?`, `altitude: Double?`, `bearing: Double?`, `locationError: String?`, `authorizationStatus: CLAuthorizationStatus`
    - In `init()`, create a `CLLocationManager`, set `desiredAccuracy = kCLLocationAccuracyBest`, `distanceFilter = kCLDistanceFilterNone`, `headingFilter = 1.0`, and assign `self` as delegate
    - Implement `requestPermission()` calling `locationManager.requestWhenInUseAuthorization()`
    - Implement `startUpdating()`: if authorised, call `startUpdatingLocation()` and `startUpdatingHeading()` (if `headingAvailable`)
    - Implement `stopUpdating()` calling both stop methods
    - Implement `locationManager(_:didUpdateLocations:)`: extract `lastLocation`, update `latitude`, `longitude`, `altitude` on `DispatchQueue.main`
    - Implement `locationManager(_:didUpdateHeading:)`: update `bearing` from `newHeading.trueHeading` on main queue; set `nil` if `trueHeading < 0`
    - Implement `locationManager(_:didFailWithError:)`: set `locationError = error.localizedDescription` on main queue
    - Implement `locationManagerDidChangeAuthorization(_:)`: update `authorizationStatus`; call `startUpdating()` if `.authorizedWhenInUse` or `.authorizedAlways`; set `locationError = "GPS Unavailable"` if `.denied` or `.restricted`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 14.2, 15.2_

  - [ ]* 3.2 Write property tests for `LocationManager` in `LocationManagerTests.swift`
    - **Property 1: GPS coordinate values are within valid ranges** — programmatically assign 100 random `CLLocation` objects to a test `LocationManager` subclass and assert published `latitude ∈ [-90, 90]` and `longitude ∈ [-180, 180]`
    - **Property 2: Bearing values are within compass range** — assign 100 random `CLHeading` mock values and assert `bearing ∈ [0, 360)`
    - **Property 12: Published property changes are observable** — attach a `Combine` sink before assignment, assign a value, assert sink's `receiveValue` was called
    - // Feature: vibesurveyor, Property 1, 2, 12
    - _Requirements: 3.1, 3.2, 3.4, 14.2_

- [x] 4. Implement `MotionManager.swift`
  - [x] 4.1 Create `MotionManager.swift`
    - Import `CoreMotion` and `Combine`
    - Define `MotionManager: ObservableObject`
    - Add `@Published` properties: `pitch: Double?`, `roll: Double?`, `motionError: String?`, `isAvailable: Bool`
    - In `init()`, create `CMMotionManager` and set `isAvailable = motionManager.isDeviceMotionAvailable`
    - Implement `startUpdates()`: if `isAvailable`, call `startDeviceMotionUpdates(to: .main) { [weak self] motion, error in … }`; in the handler, convert `motion.attitude.pitch` and `.roll` from radians to degrees and assign to `@Published` properties; on error, set `motionError`
    - Implement `stopUpdates()` calling `motionManager.stopDeviceMotionUpdates()`
    - If `!isAvailable`, set `pitch = nil`, `roll = nil`, `motionError = "Motion Unavailable"`
    - _Requirements: 4.1, 4.2, 4.3, 14.3, 15.3_

  - [ ]* 4.2 Write unit and property tests for `MotionManager` in `MotionManagerTests.swift`
    - Test that `isAvailable` is `false` when `CMMotionManager.isDeviceMotionAvailable` is false (use a testable subclass or dependency injection)
    - **Property 12 (MotionManager variant): Published property changes are observable** — assign values to `pitch` and `roll` via a test hook, assert Combine subscriber receives them
    - Test that `startUpdates()` on an unavailable manager sets `motionError` to `"Motion Unavailable"`
    - // Feature: vibesurveyor, Property 12
    - _Requirements: 4.1, 4.2, 4.3, 14.3, 15.3_

- [x] 5. Implement `ImageWatermarkProcessor.swift`
  - [x] 5.1 Create `ImageWatermarkProcessor.swift`
    - Import `UIKit` and `CoreGraphics`
    - Define `enum ImageWatermarkProcessor` (caseless enum to prevent instantiation)
    - Implement `static func process(imageData: Data, telemetry: TelemetrySnapshot) -> Data?`
    - Inside `process`: decode `imageData` to `UIImage`; return `nil` if decoding fails
    - Create a `UIGraphicsImageRenderer` at `image.size` with scale `image.scale`
    - Draw the original `image` at origin
    - Compute `fontSize = max(image.size.width, image.size.height) * 0.018`
    - Prepare `paragraphStyle` with `.left` alignment
    - Build `textAttributes: [NSAttributedString.Key: Any]` with `UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)` and `.white` foreground colour
    - For each line in `telemetry.watermarkLines`, compute the line's `CGRect` (stacked from bottom-left, padding 8 pts scaled by fontSize/14), fill a `UIColor.black.withAlphaComponent(0.55)` background rectangle, then draw the text string
    - Return JPEG `Data` at compression quality `0.92` from the renderer
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ]* 5.2 Write property tests for `ImageWatermarkProcessor` in `ImageWatermarkProcessorTests.swift`
    - **Property 3: Watermark contains all required fields** — for 100 random `TelemetrySnapshot` values and a fixed 100×100 white test image, assert `process(imageData:telemetry:)` returns non-nil and that the `telemetry.watermarkLines` used during rendering contain all 9 fields
    - **Property 4: Watermark output is valid decodable JPEG** — for 100 random image sizes (50–500 px) and random snapshots, assert returned `Data` is non-nil and decodes to a `UIImage` with the same pixel dimensions as the input
    - // Feature: vibesurveyor, Property 3, 4
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 6. Implement `PhotoFileManager.swift`
  - [x] 6.1 Create `PhotoFileManager.swift`
    - Import `Foundation`
    - Define `enum PhotoFileManager` (caseless)
    - Implement `static func documentsDirectory() -> URL` returning `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!`
    - Implement `static func uniqueURL(for filename: String) -> URL`: start with `documentsDirectory().appendingPathComponent(filename)`; while `FileManager.default.fileExists(atPath: url.path)`, insert a numeric suffix before the `.jpg` extension and increment counter; return the unique URL
    - Implement `static func save(jpegData: Data, filename: String) throws`: obtain `uniqueURL`, then call `try jpegData.write(to: url, options: .atomic)`; return the saved URL via `inout` or use `@discardableResult`
    - _Requirements: 10.1, 10.3, 10.4_

  - [ ]* 6.2 Write property tests for `PhotoFileManager` in `PhotoFileManagerTests.swift`
    - **Property 8: Unique filenames under collision** — for 100 iterations, create a temp directory, pre-populate it with N (random 1–5) identically named files, call `uniqueURL(for:)`, assert the returned URL does not match any existing file
    - **Property 7 (integration)**: for 100 random project names, generate a filename via `TelemetrySnapshot.filenameComponent`, assert the base filename starts with the project name
    - Write and read a dummy JPEG to the Documents directory, assert the file exists, then delete it
    - // Feature: vibesurveyor, Property 7, 8
    - _Requirements: 10.1, 10.2, 10.3_

- [x] 7. Checkpoint — Ensure all model and utility tests pass
  - Run `xcodebuild test -scheme VibeSurveyor -destination 'platform=iOS Simulator,name=iPhone 15'`
  - All `TelemetrySnapshotTests`, `ImageWatermarkProcessorTests`, `PhotoFileManagerTests`, `LocationManagerTests`, and `MotionManagerTests` must pass
  - Ask the user if there are any questions before proceeding to the camera and UI layer

- [x] 8. Implement `CameraManager.swift`
  - [x] 8.1 Create `CameraManager.swift` with session setup
    - Import `AVFoundation` and `Combine`
    - Define `CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate`
    - Add `@Published` properties: `isSessionRunning: Bool = false`, `captureError: String?`, `isCapturing: Bool = false`
    - Create private `let session = AVCaptureSession()`
    - Create `private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer` returning a layer backed by `session`, with `videoGravity = .resizeAspectFill`
    - Implement `configureSession()` on a private serial `DispatchQueue("camera.setup")`:
      - Call `session.beginConfiguration()`
      - Set `session.sessionPreset = .photo`
      - Find `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)`; on nil, set `captureError` and return
      - Create `AVCaptureDeviceInput`; catch errors and set `captureError`
      - Add input and `AVCapturePhotoOutput` to session
      - Call `session.commitConfiguration()`
    - Implement `startSession()`: call `configureSession()`, then `session.startRunning()`, set `isSessionRunning = true` on main queue
    - Implement `stopSession()`: `session.stopRunning()`, set `isSessionRunning = false`
    - Register for `AVCaptureSessionWasInterrupted` and `AVCaptureSessionInterruptionEnded` notifications; on interruption, set `isSessionRunning = false` and set `captureError` to the interruption reason string
    - _Requirements: 1.1, 1.4, 7.1, 12.1, 14.1, 15.1_

  - [x] 8.2 Implement photo capture in `CameraManager.swift`
    - Add `private var pendingTelemetry: TelemetrySnapshot?` to store the snapshot at capture time
    - Implement `capturePhoto(telemetry: TelemetrySnapshot, projectName: String)`:
      - Guard `!isCapturing`; set `isCapturing = true` on main queue
      - Store `telemetry` in `pendingTelemetry`
      - Create `AVCapturePhotoSettings` with JPEG format
      - Call `photoOutput.capturePhoto(with: settings, delegate: self)`
    - Implement `photoOutput(_:didFinishProcessingPhoto:error:)`:
      - On `error != nil`, set `captureError`, set `isCapturing = false` on main, return
      - Get `photoData = photo.fileDataRepresentation()` — on nil, set `captureError`, return
      - Retrieve `pendingTelemetry`
      - On a `DispatchQueue.global(qos: .userInitiated)`, call `ImageWatermarkProcessor.process(imageData:telemetry:)`
      - On completion, back on main queue: on nil result, set `captureError`; on success, call `PhotoFileManager.save(jpegData:filename:)` inside a `do/catch`, setting `captureError` on failure
      - Set `isCapturing = false`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 15.1_

  - [ ]* 8.3 Write unit tests for `CameraManager` in `CameraManagerTests.swift`
    - Test that `configureSession()` on a device with no camera sets `captureError` to a non-nil string (use a testable subclass that overrides `AVCaptureDevice.default`)
    - Test that `capturePhoto` sets `isCapturing = true` immediately and `false` after delegate returns
    - Test that `capturePhoto` calls `ImageWatermarkProcessor.process` with the correct telemetry (use a protocol-based mock)
    - Test that a delegate error triggers `captureError` and resets `isCapturing`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 14.1, 15.1_

- [x] 9. Implement `ContentView.swift` — camera preview sub-views
  - [x] 9.1 Create `CameraPreviewView` (`UIViewRepresentable`) inside `ContentView.swift` or a separate file
    - Import `SwiftUI` and `AVFoundation`
    - Define `struct CameraPreviewView: UIViewRepresentable`
    - Accept `previewLayer: AVCaptureVideoPreviewLayer` as a property
    - In `makeUIView(context:)`, create a `UIView`, add `previewLayer` as a sublayer, set `previewLayer.frame = view.bounds`
    - In `updateUIView(_:context:)`, update `previewLayer.frame = uiView.bounds`
    - _Requirements: 1.1, 1.2_

  - [x] 9.2 Create `CrosshairOverlay` view inside `ContentView.swift` or a separate file
    - Define `struct CrosshairOverlay: View`
    - Use a `GeometryReader` to obtain container size
    - Draw two `Rectangle()` shapes: a horizontal line (`height: 1`) spanning full width, centred vertically; and a vertical line (`width: 1`) spanning full height, centred horizontally
    - Apply `.foregroundColor(.white.opacity(0.8))` for contrast
    - _Requirements: 2.1, 2.2_

  - [x] 9.3 Create `TelemetryOverlayView` inside `ContentView.swift` or a separate file
    - Define `struct TelemetryOverlayView: View` accepting a `TelemetrySnapshot` or individual fields via `@ObservedObject` managers
    - Build a `VStack(alignment: .leading, spacing: 2)` of `Text` views for each of: date, time, lat, lon, alt, bearing, pitch, roll
    - Format each field: use `"N/A"` for nil values, `"Acquiring…"` for nil location coordinates, `"GPS Unavailable"` when `locationError` is set
    - Apply `.font(.system(size: 12, weight: .medium, design: .monospaced))`, `.foregroundColor(.white)`, and a `.padding(4).background(Color.black.opacity(0.5))` wrapper
    - Position the view in the bottom-left of its parent using `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(8)`
    - _Requirements: 3.5, 3.6, 3.7, 4.3, 6.1, 6.2, 6.3_

- [x] 10. Implement `ContentView.swift` — controls bar and main layout
  - [x] 10.1 Create `ShutterButton` view
    - Define `struct ShutterButton: View` accepting `action: () -> Void` and `isDisabled: Bool`
    - Render a `Circle()` with white fill, diameter 70 pts, with an inner `Circle()` border
    - Apply `.disabled(isDisabled)` and reduce opacity to `0.5` when disabled
    - _Requirements: 7.3_

  - [x] 10.2 Create `ProjectNameField` view
    - Define `struct ProjectNameField: View`
    - Use `@AppStorage("projectName")` bound to a `TextField` with placeholder "Enter project name…"
    - Apply `.textInputAutocapitalization(.words)` and `.disableAutocorrection(true)`
    - Display the field in a toolbar or a collapsible panel at the top of the screen
    - _Requirements: 9.1, 9.3, 9.4_

  - [x] 10.3 Assemble the main `ContentView` body
    - Inject `@EnvironmentObject` properties for `cameraManager`, `locationManager`, `motionManager`
    - Add `@AppStorage("projectName") private var projectName: String = "NoProject"`
    - In `body`, build a `ZStack`:
      - Base layer: `CameraPreviewView(previewLayer: cameraManager.previewLayer).ignoresSafeArea()`
      - Middle layer: `CrosshairOverlay().ignoresSafeArea()`
      - Overlay layer: `TelemetryOverlayView(…)`
      - Bottom layer: `VStack { Spacer(); ShutterButton(action: capturePhoto, isDisabled: cameraManager.isCapturing) }.padding(.bottom, 32)`
      - Top layer: `ProjectNameField()` in a `.toolbar` or `VStack` at top
    - Implement `capturePhoto()` method: build a `TelemetrySnapshot` from current manager values, call `cameraManager.capturePhoto(telemetry:projectName:)`
    - Implement permission error banner: observe `cameraManager.captureError` and `locationManager.locationError` with `.onChange(of:)`, show/hide a red banner `Text` view, auto-dismiss after 4 seconds
    - Call `cameraManager.startSession()`, `locationManager.startUpdating()`, `motionManager.startUpdates()` in `.onAppear`
    - Call `cameraManager.stopSession()`, `locationManager.stopUpdating()`, `motionManager.stopUpdates()` in `.onDisappear`
    - _Requirements: 1.1, 1.3, 6.1, 7.1, 7.2, 9.1, 14.4, 15.1, 15.2, 15.3_

- [x] 11. Implement `VibeSurveyorApp.swift` — app entry point and dependency injection
  - Define `@main struct VibeSurveyorApp: App`
  - Create `@StateObject private var cameraManager = CameraManager()`
  - Create `@StateObject private var locationManager = LocationManager()`
  - Create `@StateObject private var motionManager = MotionManager()`
  - Inject all three via `.environmentObject(…)` on `ContentView()`
  - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 12. Checkpoint — Build and run on simulator, verify core flow
  - Run `xcodebuild build -scheme VibeSurveyor -destination 'platform=iOS Simulator,name=iPhone 15'`
  - Confirm the app launches, camera preview appears (simulator may show black), telemetry overlay is visible, shutter button is present
  - Run all tests: `xcodebuild test -scheme VibeSurveyor -destination 'platform=iOS Simulator,name=iPhone 15'`
  - All tests must pass with zero failures
  - Ask the user if there are any questions before proceeding to CI/CD

- [x] 13. Create GitHub Actions CI/CD workflow
  - [x] 13.1 Create `.github/workflows/build.yml`
    - Add a workflow named `"Build VibeSurveyor"` triggered on `push` to `main` and on `pull_request`
    - Use runner `macos-latest` (or `macos-14` if `macos-latest` does not include Xcode 15+)
    - Add a step `"Select Xcode"` using `sudo xcode-select -s /Applications/Xcode_15.x.app` (or use `maxim-lobanov/setup-xcode@v1` action pinned to a specific version)
    - Add a step `"Build and Test"` running:
      ```
      xcodebuild clean test \
        -scheme VibeSurveyor \
        -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' \
        CODE_SIGNING_ALLOWED=NO
      ```
    - Add a step `"Archive"` running:
      ```
      xcodebuild archive \
        -scheme VibeSurveyor \
        -archivePath build/VibeSurveyor.xcarchive \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        DEVELOPMENT_TEAM="" \
        -destination 'generic/platform=iOS'
      ```
    - _Requirements: 13.1, 13.2, 13.4, 13.6_

  - [x] 13.2 Create `ExportOptions.plist` for IPA export
    - Create `ExportOptions.plist` in the project root with `method = development`, `compileBitcode = false`, `signingStyle = manual`
    - Add a workflow step `"Export IPA"` running:
      ```
      xcodebuild -exportArchive \
        -archivePath build/VibeSurveyor.xcarchive \
        -exportPath build/ipa \
        -exportOptionsPlist ExportOptions.plist
      ```
    - Add a workflow step `"Upload IPA artifact"` using `actions/upload-artifact@v4` to upload `build/ipa/*.ipa`
    - _Requirements: 13.3, 13.5_

- [x] 14. Final integration — wire everything together and verify
  - [x] 14.1 Review all `@EnvironmentObject` and `@StateObject` connections
    - Confirm `ContentView` receives all three managers via `@EnvironmentObject`
    - Confirm `TelemetryOverlayView` reads from the correct managers
    - Confirm `ShutterButton` action builds a complete `TelemetrySnapshot` before calling `capturePhoto`
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

  - [x] 14.2 Verify filename and storage flow end-to-end
    - Trace the code path from shutter tap → `CameraManager.capturePhoto` → delegate callback → `ImageWatermarkProcessor.process` → `PhotoFileManager.save`
    - Confirm that the `TelemetrySnapshot` built in `ContentView` is the same object stamped on the image and used to generate the filename
    - Confirm `@AppStorage("projectName")` default value is `"NoProject"` when never set
    - _Requirements: 9.4, 10.1, 10.2_

  - [ ]* 14.3 Write a final integration smoke test
    - Create an `IntegrationTests.swift` test file
    - Test that `Info.plist` contains `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription`
    - Test that writing and reading a dummy file from the Documents directory succeeds
    - Test that the CI workflow file exists at `.github/workflows/build.yml`
    - _Requirements: 11.1, 11.2, 11.3, 10.1, 13.1_

- [x] 15. Final checkpoint — all tests pass, build succeeds
  - Run `xcodebuild test -scheme VibeSurveyor -destination 'platform=iOS Simulator,name=iPhone 15'`
  - Confirm zero test failures and zero build warnings related to missing permissions or unused imports
  - Confirm no `Package.swift`, `Podfile`, `Cartfile`, or `.npm` files are present in the repository
  - Ensure all tasks pass, ask the user if there are any questions before concluding
  - _Requirements: 12.1, 12.2, 12.3_

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP implementation
- All property tests use a hand-rolled `for _ in 0..<100` iteration pattern with `Double.random(in:)` and `Int.random(in:)` — no external PBT libraries are needed
- The GitHub Actions archive step uses `CODE_SIGNING_ALLOWED=NO` to avoid certificate setup; the resulting `.ipa` is for distribution via sideloading or TestFlight after adding provisioning externally
- `@AppStorage("projectName")` with default `"NoProject"` satisfies Requirements 9.3 and 9.4 automatically — no explicit `UserDefaults.standard.register(defaults:)` call is needed
- All radians-to-degrees conversions: `degrees = radians * (180.0 / .pi)`
- The watermark uses `UIGraphicsImageRenderer` which is thread-safe when called off the main queue
