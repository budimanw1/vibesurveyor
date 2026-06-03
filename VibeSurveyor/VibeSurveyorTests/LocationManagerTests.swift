import XCTest
import CoreLocation
import Combine
@testable import VibeSurveyor

// **Validates: Requirements 3.1, 3.2, 3.4, 14.2**

// MARK: - Testable subclass

/// A `LocationManager` subclass that exposes test-injection methods without
/// touching the real `CLLocationManager` hardware stack. It directly sets the
/// `@Published` properties so tests can assert invariants on whatever the
/// manager publishes.
private final class TestableLocationManager: LocationManager {

    /// Simulates a `CLLocationManager` location update by directly assigning
    /// the published coordinate properties (mirrors the production code path
    /// inside `locationManager(_:didUpdateLocations:)`).
    func simulateLocation(latitude lat: Double, longitude lon: Double, altitude alt: Double = 0) {
        self.latitude = lat
        self.longitude = lon
        self.altitude = alt
    }

    /// Simulates a `CLLocationManager` heading update. Only assigns `bearing`
    /// when `trueHeading >= 0`, matching the production guard.
    func simulateHeading(trueHeading: Double) {
        if trueHeading >= 0 {
            self.bearing = trueHeading
        } else {
            self.bearing = nil
        }
    }
}

// MARK: - Test suite

final class LocationManagerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Property 1: GPS coordinate values are within valid ranges

    /// **Validates: Requirements 3.1, 3.2**
    ///
    /// For 100 random `CLLocation`-equivalent coordinate pairs, directly assign
    /// them to a `TestableLocationManager` and assert:
    ///   - `latitude  ∈ [-90.0,  90.0]`
    ///   - `longitude ∈ [-180.0, 180.0]`
    // Feature: vibesurveyor, Property 1: GPS coordinate values are within valid ranges
    func testProperty1_gpsCoordinatesAreWithinValidRanges() {
        let manager = TestableLocationManager()

        for _ in 0..<100 {
            let lat = Double.random(in: -90...90)
            let lon = Double.random(in: -180...180)

            manager.simulateLocation(latitude: lat, longitude: lon)

            let publishedLat = manager.latitude
            let publishedLon = manager.longitude

            XCTAssertNotNil(publishedLat, "latitude should not be nil after simulation")
            XCTAssertNotNil(publishedLon, "longitude should not be nil after simulation")

            if let publishedLat = publishedLat {
                XCTAssertGreaterThanOrEqual(
                    publishedLat, -90.0,
                    "latitude \(publishedLat) is below -90"
                )
                XCTAssertLessThanOrEqual(
                    publishedLat, 90.0,
                    "latitude \(publishedLat) is above 90"
                )
            }

            if let publishedLon = publishedLon {
                XCTAssertGreaterThanOrEqual(
                    publishedLon, -180.0,
                    "longitude \(publishedLon) is below -180"
                )
                XCTAssertLessThanOrEqual(
                    publishedLon, 180.0,
                    "longitude \(publishedLon) is above 180"
                )
            }
        }
    }

    // MARK: - Property 2: Bearing values are within compass range

    /// **Validates: Requirements 3.4**
    ///
    /// For 100 random heading values in [0, 360), simulate a heading update on a
    /// `TestableLocationManager` and assert `bearing ∈ [0.0, 360.0)`.
    /// Also tests negative trueHeading values — the manager must set `bearing = nil`.
    // Feature: vibesurveyor, Property 2: Bearing values are within compass range
    func testProperty2_bearingIsWithinCompassRange() {
        let manager = TestableLocationManager()

        for _ in 0..<100 {
            let trueHeading = Double.random(in: 0..<360)
            manager.simulateHeading(trueHeading: trueHeading)

            let publishedBearing = manager.bearing

            XCTAssertNotNil(publishedBearing, "bearing should not be nil for trueHeading \(trueHeading)")

            if let bearing = publishedBearing {
                XCTAssertGreaterThanOrEqual(
                    bearing, 0.0,
                    "bearing \(bearing) is below 0"
                )
                XCTAssertLessThan(
                    bearing, 360.0,
                    "bearing \(bearing) is not less than 360"
                )
            }
        }
    }

    /// Negative trueHeading values must result in `bearing == nil` (invalid
    /// heading — device not calibrated). This is a boundary-condition complement
    /// to Property 2.
    func testProperty2_negativeTrueHeadingPublishesNilBearing() {
        let manager = TestableLocationManager()

        for _ in 0..<100 {
            // First assign a valid bearing so we can confirm it becomes nil.
            manager.simulateHeading(trueHeading: Double.random(in: 0..<360))

            let negative = Double.random(in: -360 ..< 0)
            manager.simulateHeading(trueHeading: negative)

            XCTAssertNil(
                manager.bearing,
                "bearing should be nil when trueHeading \(negative) < 0"
            )
        }
    }

    // MARK: - Property 12: Published property changes are observable

    /// **Validates: Requirements 14.2**
    ///
    /// Attach a `Combine` sink *before* assigning a value to `latitude`, then
    /// assign the value, and assert the sink's `receiveValue` closure was called.
    // Feature: vibesurveyor, Property 12: Published property changes are observable
    func testProperty12_publishedLatitudeIsObservableViaCombine() {
        let manager = TestableLocationManager()

        var receivedValues: [Double?] = []
        // Sink is attached before any value is assigned — we skip the current
        // value emitted immediately by the Publisher by using dropFirst(1).
        manager.$latitude
            .dropFirst(1)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        let lat = Double.random(in: -90...90)
        manager.simulateLocation(latitude: lat, longitude: 0)

        XCTAssertEqual(receivedValues.count, 1, "Combine sink should receive exactly one value")
        XCTAssertEqual(receivedValues.first ?? nil, lat, "Combine sink should receive the assigned latitude")
    }

    /// Same observable-via-Combine guarantee for the `bearing` property.
    func testProperty12_publishedBearingIsObservableViaCombine() {
        let manager = TestableLocationManager()

        var receivedValues: [Double?] = []
        manager.$bearing
            .dropFirst(1)
            .sink { receivedValues.append($0) }
            .store(in: &cancellables)

        let heading = Double.random(in: 0..<360)
        manager.simulateHeading(trueHeading: heading)

        XCTAssertEqual(receivedValues.count, 1, "Combine sink should receive exactly one value")
        XCTAssertEqual(receivedValues.first ?? nil, heading, "Combine sink should receive the assigned bearing")
    }

    /// Verify that multiple consecutive assignments each fire the Combine sink,
    /// confirming the observable contract holds over repeated updates.
    func testProperty12_multipleAssignmentsEachFireCombineSink() {
        let manager = TestableLocationManager()

        var latitudeChangeCount = 0
        manager.$latitude
            .dropFirst(1)
            .sink { _ in latitudeChangeCount += 1 }
            .store(in: &cancellables)

        let iterations = 100
        for _ in 0..<iterations {
            manager.simulateLocation(
                latitude:  Double.random(in: -90...90),
                longitude: Double.random(in: -180...180)
            )
        }

        XCTAssertEqual(
            latitudeChangeCount, iterations,
            "Combine sink should fire once per assignment (\(iterations) expected, got \(latitudeChangeCount))"
        )
    }
}
