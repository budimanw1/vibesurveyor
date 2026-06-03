import XCTest
import Combine
@testable import VibeSurveyor

// Feature: vibesurveyor, Property 12

final class MotionManagerTests: XCTestCase {

    // MARK: - isAvailable

    /// Tests that a manager created with `isAvailable: false` reports unavailability.
    /// On the iOS Simulator CMMotionManager.isDeviceMotionAvailable is always false,
    /// but using the override init makes this deterministic on all platforms.
    func testIsAvailableFalse() {
        let manager = MotionManager(isAvailable: false)
        XCTAssertFalse(manager.isAvailable, "Manager created with isAvailable:false should report isAvailable == false")
    }

    func testIsAvailableTrue() {
        let manager = MotionManager(isAvailable: true)
        XCTAssertTrue(manager.isAvailable, "Manager created with isAvailable:true should report isAvailable == true")
    }

    // MARK: - startUpdates on unavailable manager

    /// Tests that calling startUpdates() when motion is unavailable sets motionError
    /// to "Motion Unavailable" and clears pitch/roll.
    func testStartUpdatesWhenUnavailableSetsMotionError() {
        let manager = MotionManager(isAvailable: false)
        manager.startUpdates()
        XCTAssertEqual(manager.motionError, "Motion Unavailable",
                       "motionError should be 'Motion Unavailable' when motion hardware is unavailable")
    }

    func testStartUpdatesWhenUnavailableClearsPitch() {
        let manager = MotionManager(isAvailable: false)
        // Pre-assign a value so we confirm it gets cleared to nil
        manager.pitch = 45.0
        manager.startUpdates()
        XCTAssertNil(manager.pitch, "pitch should be nil after startUpdates() on an unavailable manager")
    }

    func testStartUpdatesWhenUnavailableClearsRoll() {
        let manager = MotionManager(isAvailable: false)
        manager.roll = -30.0
        manager.startUpdates()
        XCTAssertNil(manager.roll, "roll should be nil after startUpdates() on an unavailable manager")
    }

    // MARK: - Property 12: Published property changes are observable

    /// **Validates: Requirements 14.3**
    ///
    /// For any value assigned to `pitch` on MotionManager, a Combine subscriber
    /// attached before the assignment shall receive the new value in its `receiveValue` closure.
    func testPublishedPitchChangesAreObservable() {
        // Feature: vibesurveyor, Property 12
        let manager = MotionManager(isAvailable: false)
        var cancellables = Set<AnyCancellable>()

        for _ in 0..<100 {
            let expectedValue = Double.random(in: -90.0...90.0)
            var receivedValue: Double? = nil
            let expectation = XCTestExpectation(description: "pitch subscriber fires")

            manager.$pitch
                .dropFirst() // skip the current value emitted on subscription
                .sink { value in
                    receivedValue = value
                    expectation.fulfill()
                }
                .store(in: &cancellables)

            manager.pitch = expectedValue
            wait(for: [expectation], timeout: 1.0)

            XCTAssertEqual(receivedValue, expectedValue,
                           "Combine subscriber should receive the assigned pitch value \(expectedValue)")
        }
    }

    /// **Validates: Requirements 14.3**
    ///
    /// For any value assigned to `roll` on MotionManager, a Combine subscriber
    /// attached before the assignment shall receive the new value in its `receiveValue` closure.
    func testPublishedRollChangesAreObservable() {
        // Feature: vibesurveyor, Property 12
        let manager = MotionManager(isAvailable: false)
        var cancellables = Set<AnyCancellable>()

        for _ in 0..<100 {
            let expectedValue = Double.random(in: -180.0...180.0)
            var receivedValue: Double? = nil
            let expectation = XCTestExpectation(description: "roll subscriber fires")

            manager.$roll
                .dropFirst() // skip the current value emitted on subscription
                .sink { value in
                    receivedValue = value
                    expectation.fulfill()
                }
                .store(in: &cancellables)

            manager.roll = expectedValue
            wait(for: [expectation], timeout: 1.0)

            XCTAssertEqual(receivedValue, expectedValue,
                           "Combine subscriber should receive the assigned roll value \(expectedValue)")
        }
    }

    /// Verifies that initial pitch and roll are nil before any updates.
    func testInitialPitchAndRollAreNil() {
        let manager = MotionManager(isAvailable: false)
        XCTAssertNil(manager.pitch)
        XCTAssertNil(manager.roll)
    }

    /// Verifies that initial motionError is nil before any updates.
    func testInitialMotionErrorIsNil() {
        let manager = MotionManager(isAvailable: false)
        XCTAssertNil(manager.motionError)
    }
}
