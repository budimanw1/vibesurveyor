import Foundation

/// Utility namespace for photo file I/O.
/// Implemented as a caseless enum to prevent instantiation.
enum PhotoFileManager {

    // MARK: - Directory

    /// Returns the app's sandboxed Documents directory URL.
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - Unique URL

    /// Returns a unique URL in the Documents directory for the given filename.
    ///
    /// If a file with `filename` already exists, a numeric suffix is inserted
    /// before the `.jpg` extension and incremented until a non-colliding name
    /// is found, e.g. `photo_1.jpg`, `photo_2.jpg`, …
    static func uniqueURL(for filename: String) -> URL {
        var url = documentsDirectory().appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        // Strip the .jpg extension to build suffixed variants.
        let base = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension  // "jpg"

        var counter = 1
        repeat {
            let suffixedName = "\(base)_\(counter).\(ext)"
            url = documentsDirectory().appendingPathComponent(suffixedName)
            counter += 1
        } while FileManager.default.fileExists(atPath: url.path)

        return url
    }

    // MARK: - Save

    /// Saves JPEG data to the Documents directory using the given filename.
    ///
    /// A unique URL is obtained via `uniqueURL(for:)` so existing files are
    /// never overwritten. The write is atomic to guard against partial writes.
    ///
    /// - Parameters:
    ///   - jpegData: The JPEG-encoded image data to persist.
    ///   - filename: The desired filename (including `.jpg` extension).
    /// - Throws: Any `Error` thrown by `Data.write(to:options:)`.
    @discardableResult
    static func save(jpegData: Data, filename: String) throws -> URL {
        let url = uniqueURL(for: filename)
        try jpegData.write(to: url, options: .atomic)
        return url
    }
}
