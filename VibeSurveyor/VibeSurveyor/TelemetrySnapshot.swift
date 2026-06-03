import Foundation

/// Captures all sensor readings at a single instant for watermarking and file naming.
struct TelemetrySnapshot {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let bearing: Double?
    let pitch: Double?
    let roll: Double?
    let timestamp: Date
    let projectName: String

    // MARK: - Computed Properties

    /// Returns the timestamp formatted as "YYYY-MM-DD".
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: timestamp)
    }

    /// Returns the timestamp formatted as "HH:mm:ss" (24-hour).
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: timestamp)
    }

    /// Builds the photo filename using the convention:
    /// `{projectName}_{YYYYMMDD}_{HHmmss}_{lat6dp}_{lon6dp}.jpg`
    /// Falls back to "0.000000" for nil coordinates.
    var filenameComponent: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let datePart = dateFormatter.string(from: timestamp)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timePart = timeFormatter.string(from: timestamp)

        let latStr = latitude.map { String(format: "%.6f", $0) } ?? "0.000000"
        let lonStr = longitude.map { String(format: "%.6f", $0) } ?? "0.000000"

        return "\(projectName)_\(datePart)_\(timePart)_\(latStr)_\(lonStr).jpg"
    }

    /// Returns 9 formatted "Label: Value" strings for all telemetry fields.
    /// Nil optional values are represented as "N/A".
    var watermarkLines: [String] {
        let latStr  = latitude  .map { String(format: "%.6f°", $0) } ?? "N/A"
        let lonStr  = longitude .map { String(format: "%.6f°", $0) } ?? "N/A"
        let altStr  = altitude  .map { String(format: "%.2f m", $0) } ?? "N/A"
        let bearStr = bearing   .map { String(format: "%.1f°", $0) } ?? "N/A"
        let pitchStr = pitch    .map { String(format: "%.1f°", $0) } ?? "N/A"
        let rollStr  = roll     .map { String(format: "%.1f°", $0) } ?? "N/A"

        return [
            "Project: \(projectName)",
            "Date:    \(formattedDate)",
            "Time:    \(formattedTime)",
            "Lat:     \(latStr)",
            "Lon:     \(lonStr)",
            "Alt:     \(altStr)",
            "Bear:    \(bearStr)",
            "Pitch:   \(pitchStr)",
            "Roll:    \(rollStr)"
        ]
    }
}
