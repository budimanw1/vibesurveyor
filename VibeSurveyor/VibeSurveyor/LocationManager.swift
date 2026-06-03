import CoreLocation
import Combine

/// Wraps CLLocationManager and publishes live GPS, altitude, and heading data.
/// Conforms to ObservableObject for SwiftUI reactive consumption.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published Properties

    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var altitude: Double?
    @Published var bearing: Double?
    @Published var locationError: String?
    @Published var authorizationStatus: CLAuthorizationStatus

    // MARK: - Private Properties

    private let locationManager: CLLocationManager

    // MARK: - Initialisation

    override init() {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = 1.0
        // Capture current status before setting delegate
        authorizationStatus = manager.authorizationStatus
        locationManager = manager
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Public Methods

    /// Requests "when in use" location authorisation from the user.
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Starts location and heading updates if authorisation has been granted.
    func startUpdating() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }

    /// Stops location and heading updates.
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate — Location Updates

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.latitude = lastLocation.coordinate.latitude
            self?.longitude = lastLocation.coordinate.longitude
            self?.altitude = lastLocation.altitude
        }
    }

    // MARK: - CLLocationManagerDelegate — Heading Updates

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { [weak self] in
            // trueHeading < 0 indicates an invalid heading (e.g. calibration required)
            if newHeading.trueHeading >= 0 {
                self?.bearing = newHeading.trueHeading
            } else {
                self?.bearing = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate — Error Handling

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.locationError = error.localizedDescription
        }
    }

    // MARK: - CLLocationManagerDelegate — Authorisation Changes

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.locationError = "GPS Unavailable"
            }
        default:
            break
        }
    }
}
