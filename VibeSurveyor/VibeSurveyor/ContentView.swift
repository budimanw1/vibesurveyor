import SwiftUI
import AVFoundation
import Combine

// MARK: - 9.1 CameraPreviewView

/// Wraps an AVCaptureVideoPreviewLayer inside a UIView so it can be embedded
/// in the SwiftUI view hierarchy without a UIViewController subclass.
/// Satisfies Requirements 1.1, 1.2.
struct CameraPreviewView: UIViewRepresentable {

    /// The preview layer to display. Owned and configured by CameraManager.
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

// MARK: - 9.2 CrosshairOverlay

/// Renders a centred crosshair (one horizontal line + one vertical line) on top
/// of the camera preview.
/// Satisfies Requirements 2.1, 2.2.
struct CrosshairOverlay: View {

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            // Horizontal line — 1 pt tall, full width, centred vertically.
            Rectangle()
                .foregroundColor(.white.opacity(0.8))
                .frame(width: size.width, height: 1)
                .offset(y: (size.height / 2) - 0.5)

            // Vertical line — 1 pt wide, full height, centred horizontally.
            Rectangle()
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 1, height: size.height)
                .offset(x: (size.width / 2) - 0.5)
        }
    }
}

// MARK: - 9.3 TelemetryOverlayView

/// Displays all live telemetry fields (date, time, GPS, bearing, pitch, roll)
/// as a monospaced text overlay anchored to the bottom-leading corner.
/// Satisfies Requirements 3.5, 3.6, 3.7, 4.3, 6.1, 6.2, 6.3.
struct TelemetryOverlayView: View {

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var motionManager: MotionManager

    /// Ticks once per second so date/time rows stay current.
    @State private var currentDate = Date()

    // Date formatter — yyyy-MM-dd (Requirement 5.1).
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Time formatter — HH:mm:ss (Requirement 5.2).
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Returns the string to show for a GPS coordinate.
    /// Shows "GPS Unavailable" when a location error is present,
    /// "Acquiring…" when nil but no error (Requirements 3.5, 3.6).
    private func coordinateText(_ value: Double?, label: String) -> String {
        if let v = value {
            return "\(label): \(String(format: "%.6f", v))°"
        } else if locationManager.locationError != nil {
            return "\(label): GPS Unavailable"
        } else {
            return "\(label): Acquiring…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1 — Date
            Text("Date: \(dateFormatter.string(from: currentDate))")

            // Row 2 — Time
            Text("Time: \(timeFormatter.string(from: currentDate))")

            // Row 3 — Latitude
            Text(coordinateText(locationManager.latitude, label: "Lat "))

            // Row 4 — Longitude
            Text(coordinateText(locationManager.longitude, label: "Lon "))

            // Row 5 — Altitude
            Text(
                locationManager.altitude.map { String(format: "Alt : %.2f m", $0) }
                ?? "Alt : N/A"
            )

            // Row 6 — Bearing
            Text(
                locationManager.bearing.map { String(format: "Bear: %.1f°", $0) }
                ?? "Bear: N/A"
            )

            // Row 7 — Pitch
            Text(
                motionManager.pitch.map { String(format: "Ptch: %.1f°", $0) }
                ?? "Ptch: N/A"
            )

            // Row 8 — Roll
            Text(
                motionManager.roll.map { String(format: "Roll: %.1f°", $0) }
                ?? "Roll: N/A"
            )
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .padding(6)
        .background(Color.black.opacity(0.5))
        .cornerRadius(4)
        // Anchor to bottom-leading corner (Requirement 6.2).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(8)
        // Tick the clock every second.
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { date in
            currentDate = date
        }
    }
}

// MARK: - 10.3 ContentView

/// The root view of VibeSurveyor. Wires the camera preview, crosshair,
/// telemetry overlay, shutter button, and project-name field into a single
/// full-screen ZStack. Manages the lifecycle of all three sensor managers and
/// surfaces permission / capture errors as a transient red banner.
///
/// Satisfies Requirements 1.1, 1.3, 6.1, 7.1, 7.2, 9.1, 14.4, 15.1, 15.2, 15.3.
struct ContentView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var motionManager: MotionManager

    // MARK: - Persistent State

    /// The active project name. Persisted across launches via UserDefaults.
    /// Default "NoProject" satisfies Requirements 9.3 and 9.4.
    @AppStorage("projectName") private var projectName: String = "NoProject"

    // MARK: - Error Banner State

    /// The message currently displayed in the error banner, or `nil` when hidden.
    @State private var errorMessage: String?

    /// Holds the auto-dismiss `DispatchWorkItem` so it can be cancelled when a
    /// new error arrives before the 4-second timer fires.
    @State private var dismissTask: DispatchWorkItem?

    // MARK: - Body

    var body: some View {
        ZStack {

            // Layer 1 — Full-screen live camera preview (Requirement 1.1)
            CameraPreviewView(previewLayer: cameraManager.previewLayer)
                .ignoresSafeArea()

            // Layer 2 — Centred crosshair (Requirements 2.1, 2.2)
            CrosshairOverlay()
                .ignoresSafeArea()

            // Layer 3 — Live telemetry overlay, bottom-left (Requirements 6.1, 6.2, 6.3)
            TelemetryOverlayView(
                locationManager: locationManager,
                motionManager: motionManager
            )
            .ignoresSafeArea()

            // Layer 4 — Shutter button anchored to bottom centre (Requirement 7.3)
            VStack {
                Spacer()
                ShutterButton(
                    action: capturePhoto,
                    isDisabled: cameraManager.isCapturing
                )
            }
            .padding(.bottom, 32)

            // Layer 5 — Project name field anchored to top centre (Requirement 9.1)
            VStack {
                ProjectNameField()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }
            .ignoresSafeArea(edges: .bottom)

            // Layer 6 — Transient error banner (Requirements 15.1, 15.2, 15.3)
            if let message = errorMessage {
                VStack {
                    Text(message)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(8)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: errorMessage)
            }
        }
        // MARK: - Lifecycle
        .onAppear {
            cameraManager.startSession()
            locationManager.startUpdating()
            motionManager.startUpdates()
        }
        .onDisappear {
            cameraManager.stopSession()
            locationManager.stopUpdating()
            motionManager.stopUpdates()
        }
        // MARK: - Error Observation
        // Show a red banner whenever captureError changes to a non-nil value
        // and auto-dismiss after 4 seconds (Requirement 15.1).
        .onChange(of: cameraManager.captureError) { newValue in
            showBanner(message: newValue)
        }
        // Show a red banner whenever locationError changes (Requirement 15.2).
        .onChange(of: locationManager.locationError) { newValue in
            showBanner(message: newValue)
        }
    }

    // MARK: - Capture

    /// Assembles a `TelemetrySnapshot` from the current manager values and
    /// forwards it to `CameraManager.capturePhoto(telemetry:projectName:)`.
    /// Satisfies Requirements 7.1 and 7.2.
    private func capturePhoto() {
        let snapshot = TelemetrySnapshot(
            latitude:    locationManager.latitude,
            longitude:   locationManager.longitude,
            altitude:    locationManager.altitude,
            bearing:     locationManager.bearing,
            pitch:       motionManager.pitch,
            roll:        motionManager.roll,
            timestamp:   Date(),
            projectName: projectName
        )
        cameraManager.capturePhoto(telemetry: snapshot, projectName: projectName)
    }

    // MARK: - Banner Helpers

    /// Displays `message` in the red banner and schedules an auto-dismiss after
    /// 4 seconds. A previous pending dismiss is cancelled so that the timer
    /// always resets when a new error arrives.
    private func showBanner(message: String?) {
        guard let message, !message.isEmpty else { return }

        // Cancel any pending auto-dismiss before showing the new message.
        dismissTask?.cancel()

        withAnimation {
            errorMessage = message
        }

        let work = DispatchWorkItem {
            withAnimation {
                errorMessage = nil
            }
        }
        dismissTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}
