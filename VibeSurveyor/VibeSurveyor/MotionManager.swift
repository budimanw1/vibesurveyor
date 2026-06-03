import CoreMotion
import Combine

/// Wraps CMMotionManager to provide reactive device pitch and roll data.
/// Conforms to ObservableObject so SwiftUI views update automatically.
final class MotionManager: ObservableObject {

    // MARK: - Published Properties

    /// Device pitch in degrees. Nil when motion is unavailable.
    @Published var pitch: Double?

    /// Device roll in degrees. Nil when motion is unavailable.
    @Published var roll: Double?

    /// A human-readable error message when motion updates fail.
    @Published var motionError: String?

    /// Whether device motion hardware is available on this device.
    @Published var isAvailable: Bool

    // MARK: - Private

    private let motionManager: CMMotionManager

    // MARK: - Init

    init() {
        let manager = CMMotionManager()
        motionManager = manager
        isAvailable = manager.isDeviceMotionAvailable
    }

    /// Testing-only initialiser. Overrides `isAvailable` so tests can exercise
    /// unavailability paths without requiring real motion hardware.
    init(isAvailable: Bool) {
        motionManager = CMMotionManager()
        self.isAvailable = isAvailable
    }

    // MARK: - Public Methods

    /// Starts device motion updates at the default rate.
    /// Converts pitch and roll from radians to degrees before publishing.
    /// If motion is unavailable, sets error and nil values immediately.
    func startUpdates() {
        guard isAvailable else {
            pitch = nil
            roll = nil
            motionError = "Motion Unavailable"
            return
        }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.motionError = error.localizedDescription
                return
            }

            guard let motion else { return }

            let toDegrees = 180.0 / Double.pi
            self.pitch = motion.attitude.pitch * toDegrees
            self.roll  = motion.attitude.roll  * toDegrees
        }
    }

    /// Stops device motion updates.
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
