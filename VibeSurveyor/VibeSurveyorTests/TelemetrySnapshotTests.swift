import XCTest
@testable import VibeSurveyor

// **Validates: Requirements 5.1, 5.2, 9.2, 10.2**

final class TelemetrySnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func randomDate() -> Date {
        Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000))
    }

    private func randomSnapshot(date: Date? = nil) -> TelemetrySnapshot {
        TelemetrySnapshot(
            latitude:    Double.random(in: -90...90),
            longitude:   Double.random(in: -180...180),
            altitude:    Double.random(in: -500...9000),
            bearing:     Double.random(in: 0..<360),
            pitch:       Double.random(in: -90...90),
            roll:        Double.random(in: -90...90),
            timestamp:   date ?? randomDate(),
            projectName: randomProjectName()
        )
    }

    private func randomProjectName() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = Int.random(in: 1...20)
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    // MARK: - Property 9: Date format matches YYYY-MM-DD

    /// **Validates: Requirements 9.2**
    func testProperty9_dateFormatMatchesYYYYMMDD() throws {
        let regex = try NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)

        for _ in 0..<100 {
            let snapshot = randomSnapshot(date: randomDate())
            let formatted = snapshot.formattedDate
            let range = NSRange(formatted.startIndex..., in: formatted)
            let match = regex.firstMatch(in: formatted, range: range)
            XCTAssertNotNil(
                match,
                "formattedDate '\(formatted)' does not match YYYY-MM-DD"
            )
        }
    }

    // MARK: - Property 10: Time format matches HH:MM:SS

    /// **Validates: Requirements 9.2**
    func testProperty10_timeFormatMatchesHHMMSS() throws {
        let regex = try NSRegularExpression(pattern: #"^\d{2}:\d{2}:\d{2}$"#)

        for _ in 0..<100 {
            let snapshot = randomSnapshot(date: randomDate())
            let formatted = snapshot.formattedTime
            let range = NSRange(formatted.startIndex..., in: formatted)
            let match = regex.firstMatch(in: formatted, range: range)
            XCTAssertNotNil(
                match,
                "formattedTime '\(formatted)' does not match HH:MM:SS"
            )
        }
    }

    // MARK: - Property 5: Filename matches the required convention

    /// **Validates: Requirements 5.1, 5.2**
    func testProperty5_filenameMatchesConvention() throws {
        let regex = try NSRegularExpression(
            pattern: #"^[^_]+_\d{8}_\d{6}_-?\d+\.\d{6}_-?\d+\.\d{6}\.jpg$"#
        )

        for _ in 0..<100 {
            let snapshot = TelemetrySnapshot(
                latitude:    Double.random(in: -90...90),
                longitude:   Double.random(in: -180...180),
                altitude:    nil,
                bearing:     nil,
                pitch:       nil,
                roll:        nil,
                timestamp:   randomDate(),
                projectName: randomProjectName()
            )
            let filename = snapshot.filenameComponent
            let range = NSRange(filename.startIndex..., in: filename)
            let match = regex.firstMatch(in: filename, range: range)
            XCTAssertNotNil(
                match,
                "filenameComponent '\(filename)' does not match required convention"
            )
        }
    }

    // MARK: - Property 7: Project name is filename prefix

    /// **Validates: Requirements 5.1**
    func testProperty7_projectNameIsFilenamePrefix() {
        for _ in 0..<100 {
            let projectName = randomProjectName()
            let snapshot = TelemetrySnapshot(
                latitude:    Double.random(in: -90...90),
                longitude:   Double.random(in: -180...180),
                altitude:    nil,
                bearing:     nil,
                pitch:       nil,
                roll:        nil,
                timestamp:   randomDate(),
                projectName: projectName
            )
            let filename = snapshot.filenameComponent
            XCTAssertTrue(
                filename.hasPrefix("\(projectName)_"),
                "filenameComponent '\(filename)' does not start with '\(projectName)_'"
            )
        }
    }

    // MARK: - Property 11: Watermark lines contain all fields

    /// **Validates: Requirements 10.2**
    func testProperty11_watermarkLinesContainAllFields() {
        for _ in 0..<100 {
            let snapshot = randomSnapshot()
            let lines = snapshot.watermarkLines

            XCTAssertEqual(
                lines.count, 9,
                "watermarkLines count is \(lines.count), expected 9"
            )

            for (index, line) in lines.enumerated() {
                XCTAssertFalse(
                    line.isEmpty,
                    "watermarkLines[\(index)] is empty"
                )
            }
        }
    }
}
