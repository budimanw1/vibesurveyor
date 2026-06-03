import AVFoundation
import Combine

/// Manages the AVCaptureSession lifecycle and photo capture.
///
/// Conforms to `ObservableObject` so SwiftUI views automatically refresh when
/// published properties change (Requirements 14.1, 1.1).
/// Conforms to `AVCapturePhotoCaptureDelegate` to receive photo data
/// asynchronously after capture (Requirement 7.1).
final class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    // MARK: - Published State

    /// `true` while the capture session is actively running.
    @Published var isSessionRunning: Bool = false

    /// Set to a human-readable string when any camera or capture error occurs.
    /// `nil` when there is no current error (Requirement 15.1).
    @Published var captureError: String?

    /// `true` from the moment `capturePhoto` is called until the delegate
    /// finishes all post-processing. Used to disable the shutter button
    /// (Requirement 7.3).
    @Published var isCapturing: Bool = false

    // MARK: - Private Session Objects

    /// The underlying AVFoundation capture session.
    private let session = AVCaptureSession()

    /// A serial queue used for all session configuration and start/stop calls.
    /// AVCaptureSession operations must never be performed on the main thread.
    private let sessionQueue = DispatchQueue(label: "camera.setup")

    /// The photo output added to the session during configuration.
    private let photoOutput = AVCapturePhotoOutput()

    // MARK: - Preview Layer

    /// A preview layer backed by the capture session.
    /// Lazily initialised so it is only created if the caller requests it.
    /// `private(set)` prevents callers from replacing the layer while still
    /// allowing reads (Requirement 1.1).
    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    // MARK: - Pending Capture State

    /// Holds the telemetry snapshot supplied to `capturePhoto` until the
    /// delegate callback fires and needs to stamp the image (Requirement 7.2).
    private var pendingTelemetry: TelemetrySnapshot?

    /// Project name forwarded from `capturePhoto` for use in the filename.
    private var pendingProjectName: String?

    // MARK: - Initialisation

    override init() {
        super.init()
        registerForInterruptionNotifications()
    }

    // MARK: - Session Configuration

    /// Configures the capture session: sets preset, attaches the back camera
    /// input and the photo output. Called from `startSession()` on `sessionQueue`.
    ///
    /// On any failure the method sets `captureError` on the main queue and
    /// returns early without committing the configuration
    /// (Requirements 1.4, 15.1).
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Locate the built-in wide-angle back camera.
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = "No camera detected on this device."
            }
            session.commitConfiguration()
            return
        }

        // Create a device input, catching any initialisation error.
        let deviceInput: AVCaptureDeviceInput
        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = error.localizedDescription
            }
            session.commitConfiguration()
            return
        }

        // Add the device input to the session.
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }

        // Add the photo output to the session.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    // MARK: - Session Lifecycle

    /// Configures and starts the capture session on the background serial queue.
    /// Updates `isSessionRunning` on the main queue when done (Requirement 1.1).
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    /// Stops the capture session synchronously on the session queue and
    /// updates `isSessionRunning` on the main queue.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Interruption Handling

    /// Registers for AVFoundation session interruption notifications so the
    /// app can surface a descriptive error when the session is interrupted
    /// (e.g. incoming phone call, Control Centre camera access revocation).
    /// Satisfies Requirement 15.1.
    private func registerForInterruptionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
    }

    /// Handles the `AVCaptureSessionWasInterrupted` notification.
    /// Extracts a human-readable reason string and publishes it as `captureError`.
    @objc private func sessionWasInterrupted(_ notification: Notification) {
        let reasonValue = notification.userInfo?[
            AVCaptureSessionInterruptionReasonKey
        ] as? Int

        let reasonString: String
        if let value = reasonValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: value) {
            switch reason {
            case .videoDeviceNotAvailableInBackground:
                reasonString = "Camera unavailable in background."
            case .audioDeviceInUseByAnotherClient:
                reasonString = "Audio device in use by another app."
            case .videoDeviceInUseByAnotherClient:
                reasonString = "Camera in use by another app."
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                reasonString = "Camera unavailable with multiple foreground apps."
            case .videoDeviceNotAvailableDueToSystemPressure:
                reasonString = "Camera unavailable due to system pressure."
            @unknown default:
                reasonString = "Camera session was interrupted."
            }
        } else {
            reasonString = "Camera session was interrupted."
        }

        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = false
            self?.captureError = reasonString
        }
    }

    // MARK: - Photo Capture

    /// Initiates a still photo capture with the current telemetry snapshot.
    ///
    /// Guards against concurrent captures via `isCapturing`. Stores `telemetry`
    /// for use in the delegate callback. Triggers `AVCapturePhotoOutput` with a
    /// JPEG settings object (Requirements 7.1, 7.2, 7.3).
    ///
    /// - Parameters:
    ///   - telemetry: The sensor snapshot to stamp onto the captured image.
    ///   - projectName: The active project name used to generate the filename.
    func capturePhoto(telemetry: TelemetrySnapshot, projectName: String) {
        guard !isCapturing else { return }

        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = true
        }

        pendingTelemetry = telemetry
        pendingProjectName = projectName

        let settings = AVCapturePhotoSettings(
            format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
        )
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    /// Delegate callback invoked when the photo pipeline finishes processing.
    ///
    /// Handles all error paths and dispatches watermarking to a background queue
    /// before saving with `PhotoFileManager` (Requirements 7.2, 7.4, 15.1).
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // --- Error path: capture hardware/session error ---
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = error.localizedDescription
                self?.isCapturing = false
            }
            return
        }

        // --- Error path: no image data in the photo buffer ---
        guard let photoData = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = "Failed to get image data."
                self?.isCapturing = false
            }
            return
        }

        // --- Error path: telemetry was somehow lost between capture and callback ---
        guard let snapshot = pendingTelemetry else {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = "No telemetry available."
                self?.isCapturing = false
            }
            return
        }

        // Capture the project name and clear pending state before dispatching.
        let filename = snapshot.filenameComponent
        pendingTelemetry = nil
        pendingProjectName = nil

        // --- Background watermark processing (Requirement 7.2) ---
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let watermarked = ImageWatermarkProcessor.process(
                imageData: photoData,
                telemetry: snapshot
            )

            DispatchQueue.main.async {
                guard let self else { return }

                defer { self.isCapturing = false }

                // --- Error path: watermark processor returned nil ---
                guard let jpegData = watermarked else {
                    self.captureError = "Failed to process image watermark."
                    return
                }

                // --- Save to Documents directory ---
                do {
                    try PhotoFileManager.save(jpegData: jpegData, filename: filename)
                } catch {
                    self.captureError = "Failed to save photo: \(error.localizedDescription)"
                }
            }
        }
    }
}
