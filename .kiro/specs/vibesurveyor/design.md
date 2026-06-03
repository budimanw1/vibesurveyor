# Design Document: VibeSurveyor

## Overview

VibeSurveyor is a native iOS surveying camera application built exclusively with Apple's first-party frameworks. The app presents a full-screen AVFoundation camera preview augmented by a crosshair overlay and a live telemetry HUD. On shutter press, all live sensor data (GPS, compass, device motion, timestamp, and project name) is composited as a permanent watermark onto the captured JPEG image. Photos are saved to the app's sandboxed Documents directory with a structured, human-readable filename.

The entire codebase uses zero external dependencies. All data flows reactively through `ObservableObject` managers consumed by SwiftUI views via `@StateObject` and `@ObservedObject`. The project builds on a stock GitHub Actions macOS runner using only `xcodebuild`.

---

## Architecture

The app follows a lightweight MVVM-style reactive architecture. Three manager objects act as the data layer; `ContentView` acts as the presenter.

```
┌─────────────────────────────────────────────────────┐
│                   ContentView (SwiftUI)              │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────┐  │
│  │ CameraPreview│  │TelemetryHUD│  │ControlsBar  │  │
│  └──────────────┘  └────────────┘  └─────────────┘  │
└───────────┬─────────────────┬──────────────┬────────┘
            │ @StateObject    │ @StateObject │ @StateObject
            ▼                 ▼              ▼
    ┌───────────────┐  ┌────────────────┐  ┌──────────────┐
    │ CameraManager │  │LocationManager │  │MotionManager │
    │ AVFoundation  │  │ CoreLocation   │  │ CoreMotion   │
    └───────┬───────┘  └────────────────┘  └──────────────┘
            │ (on capture)
            ▼
    ┌───────────────────────┐
    │ ImageWatermarkProcessor│
    │   CoreGraphics/UIKit  │
    └───────────────────────┘
            │ (JPEG Data)
            ▼
    ┌───────────────────────┐
    │  Documents Directory  │
    │  (FileManager)        │
    └───────────────────────┘
```

### Key Design Decisions

1. **No UIKit view controllers for camera** — `AVCaptureVideoPreviewLayer` is wrapped in a `UIViewRepresentable` so it can be embedded directly in SwiftUI without a `UIViewController` subclass. This keeps all view logic in SwiftUI.
2. **Telemetry snapshot at shutter press** — sensor values are captured atomically at the moment the `AVCapturePhotoCaptureDelegate` callback fires (not at button press) to ensure the stamped data matches the actual moment of image capture.
3. **Synchronous watermark on background queue** — `ImageWatermarkProcessor` does all CoreGraphics work on a background `DispatchQueue`, returning JPEG `Data` to the main queue only when complete. This prevents UI freezes on large images.
4. **UserDefaults for project persistence** — project name is a single lightweight string; no Core Data or SQLite is needed.
5. **Filename uniqueness via counter** — before saving, the app checks `FileManager.fileExists(atPath:)` in a loop, appending `_N` suffixes as needed. This is simple, deterministic, and avoids race conditions in single-user operation.

---

## Components and Interfaces

### `VibeSurveyorApp.swift`

The `@main` entry point. Creates and injects `CameraManager`, `LocationManager`, and `MotionManager` as `@StateObject` instances into the SwiftUI environment.

```swift
@main
struct VibeSurveyorApp: App {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var motionManager = MotionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraManager)
                .environmentObject(locationManager)
                .environmentObject(motionManager)
        }
    }
}
```

---

### `CameraManager.swift`

Manages the `AVCaptureSession` lifecycle and photo capture. Conforms to `ObservableObject` and `AVCapturePhotoCaptureDelegate`.

**Public Published Properties:**
```swift
@Published var isSessionRunning: Bool
@Published var captureError: String?
@Published var isCapturing: Bool
```

**Key Methods:**
```swift
func configureSession()           // Sets up AVCaptureDeviceInput + AVCapturePhotoOutput
func startSession()               // Starts the capture session on a background queue
func stopSession()                // Stops the session
func capturePhoto(telemetry: TelemetrySnapshot, projectName: String) // Triggers capture
```

**`AVCaptureVideoPreviewLayer` access:**
```swift
var previewLayer: AVCaptureVideoPreviewLayer { get }
```

**`AVCapturePhotoCaptureDelegate` callback:**
```swift
func photoOutput(_ output: AVCapturePhotoOutput,
                 didFinishProcessingPhoto photo: AVCapturePhoto,
                 error: Error?)
```
Inside the callback, `ImageWatermarkProcessor.process(imageData:telemetry:)` is called asynchronously, then the result is saved by `PhotoFileManager.save(jpegData:filename:)`.

---

### `LocationManager.swift`

Wraps `CLLocationManager`, updates location and heading. Conforms to `ObservableObject` and `CLLocationManagerDelegate`.

**Public Published Properties:**
```swift
@Published var latitude: Double?
@Published var longitude: Double?
@Published var altitude: Double?
@Published var bearing: Double?
@Published var locationError: String?
@Published var authorizationStatus: CLAuthorizationStatus
```

**Key Methods:**
```swift
func requestPermission()  // Calls requestWhenInUseAuthorization()
func startUpdating()      // Starts location + heading updates
func stopUpdating()       // Stops updates
```

**`CLLocationManagerDelegate` callbacks:**
- `locationManager(_:didUpdateLocations:)` — updates lat/lon/altitude
- `locationManager(_:didUpdateHeading:)` — updates bearing
- `locationManager(_:didFailWithError:)` — sets `locationError`
- `locationManagerDidChangeAuthorization(_:)` — updates `authorizationStatus`, starts/stops updates accordingly

---

### `MotionManager.swift`

Wraps `CMMotionManager` for device attitude (pitch, roll). Conforms to `ObservableObject`.

**Public Published Properties:**
```swift
@Published var pitch: Double?
@Published var roll: Double?
@Published var motionError: String?
@Published var isAvailable: Bool
```

**Key Methods:**
```swift
func startUpdates()   // Starts device motion updates at 10 Hz
func stopUpdates()    // Stops device motion updates
```

Updates are delivered to the main queue via `CMMotionManager.startDeviceMotionUpdates(to:withHandler:)`. Pitch and roll are extracted from `CMAttitude` using `.euler` representation in degrees.

---

### `ImageWatermarkProcessor.swift`

Pure function component with no stored state. Accepts raw JPEG `Data` and a `TelemetrySnapshot` struct, returns watermarked JPEG `Data`.

```swift
struct ImageWatermarkProcessor {
    static func process(imageData: Data, telemetry: TelemetrySnapshot) -> Data?
}
```

**Rendering steps:**
1. Decode `Data` to `UIImage`.
2. Begin a `UIGraphicsImageRenderer` context at the image's native size.
3. Draw the original image into the context.
4. Compute font size as `max(image.size.height, image.size.width) * 0.018` (1.8% of the longer dimension).
5. Build the telemetry text block as an array of `String` lines.
6. For each line, compute a `CGRect`, fill a semi-transparent black background rectangle, then draw the white text.
7. Extract JPEG `Data` at 0.92 quality.
8. Return the `Data`.

---

### `ContentView.swift`

The root SwiftUI view. Composes the camera preview, crosshair, telemetry overlay, and shutter controls.

**Sub-views:**
- `CameraPreviewView: UIViewRepresentable` — wraps `AVCaptureVideoPreviewLayer`
- `CrosshairOverlay: View` — two `Rectangle` shapes intersecting at centre
- `TelemetryOverlayView: View` — VStack of labelled telemetry rows, positioned in bottom-left corner
- `ShutterButton: View` — circular button, disabled while `cameraManager.isCapturing`
- `ProjectNameField: View` — `TextField` bound to `@AppStorage("projectName")`

**Layout strategy:** `ZStack` with `CameraPreviewView` as base layer, `CrosshairOverlay` in the middle, `TelemetryOverlayView` anchored to `.bottomLeading`, and `ShutterButton` anchored to `.bottom`.

---

### `TelemetrySnapshot.swift`

A pure value type (struct) that captures all sensor readings at a single instant.

```swift
struct TelemetrySnapshot {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let bearing: Double?
    let pitch: Double?
    let roll: Double?
    let timestamp: Date
    let projectName: String
}
```

Helper computed properties:
```swift
var formattedDate: String   // "YYYY-MM-DD"
var formattedTime: String   // "HH:MM:SS"
var filenameComponent: String  // "{ProjectName}_{YYYYMMDD}_{HHmmss}_{lat}_{lon}.jpg"
```

---

### `PhotoFileManager.swift`

Utility struct for file I/O.

```swift
struct PhotoFileManager {
    static func documentsDirectory() -> URL
    static func uniqueURL(for filename: String) -> URL  // Appends _N suffix if needed
    static func save(jpegData: Data, filename: String) throws
}
```

---

## Data Models

### `TelemetrySnapshot`

| Field | Type | Source | Format |
|---|---|---|---|
| `latitude` | `Double?` | `CLLocation.coordinate.latitude` | ±DD.DDDDDD |
| `longitude` | `Double?` | `CLLocation.coordinate.longitude` | ±DDD.DDDDDD |
| `altitude` | `Double?` | `CLLocation.altitude` | metres |
| `bearing` | `Double?` | `CLHeading.trueHeading` | 0–360° |
| `pitch` | `Double?` | `CMAttitude.pitch` (radians → degrees) | ±90° |
| `roll` | `Double?` | `CMAttitude.roll` (radians → degrees) | ±180° |
| `timestamp` | `Date` | `Date()` at capture delegate callback | ISO 8601 |
| `projectName` | `String` | UserDefaults `"projectName"` key | free text |

### Watermark Text Layout

```
ProjectName: {name}
Date: {YYYY-MM-DD}
Time: {HH:MM:SS}
Lat:  {±DD.DDDDDD}°
Lon:  {±DDD.DDDDDD}°
Alt:  {X.XX} m
Bear: {XXX.X}°
Pitch:{±XX.X}°
Roll: {±XX.X}°
```

### Filename Convention

```
{ProjectName}_{YYYYMMDD}_{HHmmss}_{lat6dp}_{lon6dp}.jpg
```
Example: `Survey_Alpha_20240315_143022_-6.175392_106.827194.jpg`

If a file with this name already exists:
`Survey_Alpha_20240315_143022_-6.175392_106.827194_1.jpg`, `…_2.jpg`, etc.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: GPS coordinate values are within valid ranges

*For any* `CLLocation` update delivered to `LocationManager`, the published `latitude` value shall be in the range [-90.0, 90.0] and the published `longitude` value shall be in the range [-180.0, 180.0].

**Validates: Requirements 3.1, 3.2**

---

### Property 2: Bearing values are within compass range

*For any* `CLHeading` update delivered to `LocationManager`, the published `bearing` value shall be in the range [0.0, 360.0).

**Validates: Requirements 3.4**

---

### Property 3: Telemetry watermark contains all required fields

*For any* `TelemetrySnapshot` and any non-empty JPEG image data, the JPEG output produced by `ImageWatermarkProcessor.process(imageData:telemetry:)` shall, when decoded to a `UIImage`, have pixel dimensions equal to the source image, and the telemetry snapshot's `formattedDate`, `formattedTime`, project name, and coordinate strings shall all appear in the watermark text lines used during rendering.

**Validates: Requirements 8.1, 8.4**

---

### Property 4: Watermark output is valid decodable JPEG

*For any* non-nil input `Data` that decodes as a valid `UIImage` and any `TelemetrySnapshot`, `ImageWatermarkProcessor.process(imageData:telemetry:)` shall return non-nil `Data` that can be decoded back to a `UIImage` with the same pixel dimensions as the input (round-trip size invariant).

**Validates: Requirements 8.4**

---

### Property 5: Filename matches the required convention

*For any* `TelemetrySnapshot` with non-nil latitude and longitude, `TelemetrySnapshot.filenameComponent` shall produce a string matching the regex pattern `^[^_]+_\d{8}_\d{6}_-?\d+\.\d{6}_-?\d+\.\d{6}\.jpg$`.

**Validates: Requirements 10.2**

---

### Property 6: Project name persistence round-trip

*For any* non-empty project name string written to `UserDefaults` under the key `"projectName"`, reading that key back from `UserDefaults` shall return the identical string.

**Validates: Requirements 9.3**

---

### Property 7: Project name is used as filename prefix

*For any* project name string and any `TelemetrySnapshot` using that project name, the generated filename shall start with the project name string followed by an underscore.

**Validates: Requirements 9.2, 10.2**

---

### Property 8: Unique filenames under collision

*For any* existing set of filenames in the Documents directory and any new target filename that conflicts with one or more existing filenames, `PhotoFileManager.uniqueURL(for:)` shall return a URL whose `lastPathComponent` does not appear in the existing filename set.

**Validates: Requirements 10.3**

---

### Property 9: Date format matches YYYY-MM-DD

*For any* `Date` value, `TelemetrySnapshot.formattedDate` shall return a string matching the regex pattern `^\d{4}-\d{2}-\d{2}$`.

**Validates: Requirements 5.1**

---

### Property 10: Time format matches HH:MM:SS

*For any* `Date` value, `TelemetrySnapshot.formattedTime` shall return a string matching the regex pattern `^\d{2}:\d{2}:\d{2}$`.

**Validates: Requirements 5.2**

---

### Property 11: Telemetry overlay renders all fields

*For any* `TelemetrySnapshot`, the array of text lines produced for the overlay or watermark shall contain non-empty string representations of all 8 telemetry fields (date, time, latitude, longitude, altitude, bearing, pitch, roll).

**Validates: Requirements 6.1, 8.1**

---

### Property 12: Published property changes are observable

*For any* value assigned to a `@Published` property on `LocationManager` or `MotionManager`, a `Combine` subscriber attached before the assignment shall receive the new value in its `receiveValue` closure.

**Validates: Requirements 14.2, 14.3**

---

## Error Handling

### Permission Errors

| Scenario | Detection | Response |
|---|---|---|
| Camera permission denied | `AVCaptureDevice.authorizationStatus` returns `.denied` | `CameraManager` sets `captureError = "Camera access denied. Open Settings to allow."` |
| Location permission denied | `CLLocationManager` `authorizationStatus` returns `.denied` or `.restricted` | `LocationManager` sets `locationError = "GPS Unavailable"` |
| Location permission not determined | `authorizationStatus` returns `.notDetermined` | `LocationManager.requestPermission()` called at `startUpdating()` |

### Hardware Errors

| Scenario | Detection | Response |
|---|---|---|
| No camera device | `AVCaptureDevice.default(.builtInWideAngleCamera, …)` returns `nil` | `CameraManager` sets `captureError = "No camera detected on this device."` |
| No heading hardware | `CLLocationManager.headingAvailable` returns `false` | `LocationManager` sets `bearing = nil`; UI displays "N/A" |
| CoreMotion unavailable | `CMMotionManager.isDeviceMotionAvailable` returns `false` | `MotionManager` sets `isAvailable = false`; UI displays "N/A" for pitch/roll |

### Capture and Save Errors

| Scenario | Detection | Response |
|---|---|---|
| `AVCapturePhoto` delegate error | `error != nil` in `didFinishProcessingPhoto` | `CameraManager` sets `captureError` to `error.localizedDescription` |
| `ImageWatermarkProcessor` returns nil | Watermark function returns `nil` | `CameraManager` sets `captureError = "Failed to process image watermark."` |
| `FileManager.createFile` fails | `try FileManager.default.createDirectory` or `write` throws | `CameraManager` sets `captureError = "Failed to save photo: \(error.localizedDescription)"` |
| Session interruption | `AVCaptureSessionWasInterrupted` notification | `CameraManager` sets `isSessionRunning = false`, `captureError` set to interruption reason |

### Error UI Pattern

`ContentView` observes `cameraManager.captureError` and `locationManager.locationError`. When non-nil, a banner overlay is displayed at the top of the screen using a `VStack` with a red-tinted background. The error auto-dismisses after 4 seconds via `DispatchQueue.main.asyncAfter`.

---

## Testing Strategy

### Dual Testing Approach

Unit tests validate specific examples, edge cases, and error conditions. Property-based tests validate universal correctness properties across generated inputs. Both are necessary for comprehensive coverage.

### Property-Based Testing Library

**[swift-gen](https://github.com/pointfreeco/swift-gen)** is not used. Instead, property tests are implemented using **[swift-check](https://github.com/nicklockwood/Preconditions)** — wait. Per the zero-dependency requirement, external test libraries are also avoided.

**Approach**: Property tests are implemented using Swift's native `XCTest` framework with a lightweight hand-rolled generator helper (a simple `Gen<T>` type consisting of `(Int) -> T` closures seeded by `arc4random`). Each property test runs 100+ iterations using a `for _ in 0..<100` loop. This requires no external package manager and is fully compatible with `xcodebuild test`.

### Unit Tests (`VibeSurveyorTests/`)

Each test file maps to one source file:

| Test File | Tests |
|---|---|
| `TelemetrySnapshotTests.swift` | Date/time formatting, filename convention, properties 5, 9, 10 |
| `ImageWatermarkProcessorTests.swift` | Watermark output validity, field presence, properties 3, 4, 11 |
| `PhotoFileManagerTests.swift` | Unique URL generation, properties 7, 8 |
| `LocationManagerTests.swift` | Published property updates, coordinate range properties 1, 2, 12 |
| `MotionManagerTests.swift` | Published property updates, error state, property 12 |
| `CameraManagerTests.swift` | Session configuration, capture triggering, error state |

### Property Test Configuration

Each property test:
- Runs **100 iterations minimum** using a deterministic seed loop
- Is tagged with a comment: `// Feature: vibesurveyor, Property N: <property text>`
- Uses in-memory fake data (no hardware required; managers can be tested with mock delegates)

### Example Property Test Structure

```swift
// Feature: vibesurveyor, Property 5: Filename matches the required convention
func testFilenameMatchesConvention() {
    let regex = try! NSRegularExpression(
        pattern: #"^[^_]+_\d{8}_\d{6}_-?\d+\.\d{6}_-?\d+\.\d{6}\.jpg$"#
    )
    for _ in 0..<100 {
        let lat = Double.random(in: -90...90)
        let lon = Double.random(in: -180...180)
        let snapshot = TelemetrySnapshot(
            latitude: lat, longitude: lon,
            altitude: Double.random(in: -500...9000),
            bearing: Double.random(in: 0..<360),
            pitch: Double.random(in: -90...90),
            roll: Double.random(in: -180...180),
            timestamp: Date(),
            projectName: "TestProject"
        )
        let filename = snapshot.filenameComponent
        let range = NSRange(filename.startIndex..., in: filename)
        XCTAssertNotNil(regex.firstMatch(in: filename, range: range),
                        "Filename '\(filename)' does not match convention")
    }
}
```

### Integration Tests

- **Info.plist key presence**: `XCTest` reads the app's `Info.plist` and asserts required keys exist.
- **Documents directory write**: Write a dummy file, assert it exists, clean up.
- **Build smoke test**: `xcodebuild build` in CI confirms zero-dependency compilation.

### GitHub Actions CI/CD

See `Requirement 13`. The workflow file (`.github/workflows/build.yml`) runs:
1. `xcodebuild clean build` (debug) to surface compile errors fast
2. `xcodebuild archive` to produce `.xcarchive`
3. `xcodebuild -exportArchive` to produce `.ipa`
4. Upload `.ipa` as artifact

Export options use `method: development` (no App Store signing required for CI artifact).
