import XCTest
@testable import VibeSurveyor

/// Integration smoke tests validating project-level invariants.
///
/// These tests verify:
///   - Info.plist contains all required permission keys (Requirements 11.1, 11.2, 11.3)
///   - The Documents directory is writable and readable (Requirement 10.1)
///   - The CI workflow file exists at `.github/workflows/build.yml` (Requirement 13.1)
final class IntegrationTests: XCTestCase {

    // MARK: - Info.plist Permission Keys (Requirements 11.1, 11.2, 11.3)

    /// The test bundle and the app bundle are different targets; we read the app's
    /// Info.plist from the main bundle (which, in an XCTest run, is the host app bundle).
    /// If the keys are missing the runtime permission dialogs cannot appear and the app
    /// will crash, so their presence is a hard build-time requirement.

    func testInfoPlistContainsNSCameraUsageDescription() {
        let info = Bundle.main.infoDictionary
        XCTAssertNotNil(info, "infoDictionary should not be nil")
        let value = info?["NSCameraUsageDescription"] as? String
        XCTAssertNotNil(
            value,
            "Info.plist is missing NSCameraUsageDescription (Requirement 11.1)"
        )
        XCTAssertFalse(
            value?.isEmpty ?? true,
            "NSCameraUsageDescription should not be empty (Requirement 11.1)"
        )
    }

    func testInfoPlistContainsNSLocationWhenInUseUsageDescription() {
        let info = Bundle.main.infoDictionary
        XCTAssertNotNil(info, "infoDictionary should not be nil")
        let value = info?["NSLocationWhenInUseUsageDescription"] as? String
        XCTAssertNotNil(
            value,
            "Info.plist is missing NSLocationWhenInUseUsageDescription (Requirement 11.2)"
        )
        XCTAssertFalse(
            value?.isEmpty ?? true,
            "NSLocationWhenInUseUsageDescription should not be empty (Requirement 11.2)"
        )
    }

    func testInfoPlistContainsNSMotionUsageDescription() {
        let info = Bundle.main.infoDictionary
        XCTAssertNotNil(info, "infoDictionary should not be nil")
        let value = info?["NSMotionUsageDescription"] as? String
        XCTAssertNotNil(
            value,
            "Info.plist is missing NSMotionUsageDescription (Requirement 11.3)"
        )
        XCTAssertFalse(
            value?.isEmpty ?? true,
            "NSMotionUsageDescription should not be empty (Requirement 11.3)"
        )
    }

    // MARK: - Documents Directory Write/Read (Requirement 10.1)

    func testDocumentsDirectoryWriteAndRead() throws {
        let docsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let testFile = docsURL.appendingPathComponent("integration_test_dummy.jpg")

        // Write a minimal valid JPEG placeholder (any non-empty data suffices for the
        // write-path test; we don't need to decode it as a real image here).
        let dummyData = Data([0xFF, 0xD8, 0xFF, 0xE0])  // JPEG magic bytes prefix
        try dummyData.write(to: testFile, options: .atomic)

        // Verify the file exists on disk.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testFile.path),
            "Written file should exist in the Documents directory"
        )

        // Read back and verify the bytes match.
        let readBack = try Data(contentsOf: testFile)
        XCTAssertEqual(
            dummyData,
            readBack,
            "Read-back data should match written data"
        )

        // Clean up.
        try FileManager.default.removeItem(at: testFile)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: testFile.path),
            "Test file should be deleted after clean-up"
        )
    }

    // MARK: - CI Workflow File Existence (Requirement 13.1)

    func testCIWorkflowFileExists() {
        // The test locates the workflow relative to the source root.
        // On CI (GitHub Actions), the checkout root is the working directory.
        // Locally the project lives inside the workspace root.
        //
        // Strategy: walk up from the test bundle's resource path until we find
        // `.github/workflows/build.yml` or exhaust the directory tree.

        let workflowRelative = ".github/workflows/build.yml"

        // Start from the directory that contains VibeSurveyor.xcodeproj.
        // Bundle.main.bundlePath in the simulator is something like:
        //   .../Debug-iphonesimulator/VibeSurveyor.app
        // We walk up until we find the workflow file.
        var current = URL(fileURLWithPath: Bundle.main.bundlePath)
        var found = false

        for _ in 0..<10 {
            current = current.deletingLastPathComponent()
            let candidate = current.appendingPathComponent(workflowRelative)
            if FileManager.default.fileExists(atPath: candidate.path) {
                found = true
                break
            }
        }

        XCTAssertTrue(
            found,
            "CI workflow file '\(workflowRelative)' was not found in any ancestor directory of the test bundle — Requirement 13.1"
        )
    }
}
