import UIKit
import CoreGraphics

/// Caseless enum used as a namespace to prevent instantiation.
/// Provides a single static method to composite telemetry onto a JPEG image.
enum ImageWatermarkProcessor {

    /// Draws all telemetry watermark lines onto the given image data and returns
    /// the result as JPEG data at 0.92 compression quality.
    ///
    /// - Parameters:
    ///   - imageData: Raw JPEG (or any `UIImage`-decodable) data of the captured photo.
    ///   - telemetry: The telemetry snapshot whose `watermarkLines` will be drawn.
    /// - Returns: Watermarked JPEG `Data`, or `nil` if `imageData` cannot be decoded.
    static func process(imageData: Data, telemetry: TelemetrySnapshot) -> Data? {
        // 1. Decode the source image; bail out on failure.
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // 2. Create a renderer that matches the source image's size and scale so that
        //    pixel dimensions are preserved exactly (Property 4).
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        let jpegData = renderer.jpegData(withCompressionQuality: 0.92) { context in
            // 3. Draw the original image at the origin.
            image.draw(at: .zero)

            // 4. Compute a font size proportional to image resolution (Requirement 8.2).
            //    1.8 % of the longer dimension ensures legibility at native resolution.
            let fontSize = max(image.size.width, image.size.height) * 0.018

            // 5. Paragraph style: left-aligned single lines.
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineBreakMode = .byClipping

            // 6. White monospaced text attributes.
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            // 7. Measure line height once so we can stack lines from the bottom.
            let sampleLine = telemetry.watermarkLines.first ?? " "
            let lineHeight = (sampleLine as NSString).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                             height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: textAttributes,
                context: nil
            ).height

            // 8. Padding scales with font size so it looks proportional across resolutions.
            let padding = 8.0 * (fontSize / 14.0)

            let lines = telemetry.watermarkLines
            let totalLines = lines.count

            // 9. Draw each line stacked from the bottom-left corner (Requirement 8.3).
            //    Line index 0 is the bottom-most line.
            for (index, lineText) in lines.reversed().enumerated() {
                // Compute the vertical position of this line measured from the bottom.
                let yFromBottom = padding + Double(index) * (lineHeight + padding)
                let yOrigin = image.size.height - yFromBottom - lineHeight

                // Measure text width for the background rectangle.
                let textSize = (lineText as NSString).boundingRect(
                    with: CGSize(width: image.size.width,
                                 height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes,
                    context: nil
                ).size

                let bgRect = CGRect(
                    x: padding,
                    y: yOrigin - padding / 2.0,
                    width: textSize.width + padding * 2.0,
                    height: lineHeight + padding
                )

                // Fill semi-transparent black background (Requirement 8.3).
                UIColor.black.withAlphaComponent(0.55).setFill()
                UIRectFill(bgRect)

                // Draw the text string.
                let textRect = CGRect(
                    x: padding + padding,
                    y: yOrigin,
                    width: textSize.width,
                    height: lineHeight
                )
                (lineText as NSString).draw(in: textRect, withAttributes: textAttributes)
            }

            // Suppress unused-variable warning for totalLines (kept for clarity).
            _ = totalLines
        }

        return jpegData
    }
}
