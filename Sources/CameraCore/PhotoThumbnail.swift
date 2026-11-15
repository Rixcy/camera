import Foundation
import ImageIO

public enum PhotoThumbnail {
    /// A small upright image for the last-photo button, with the EXIF
    /// orientation (including mirroring) applied to the pixels.
    public static func make(from imageData: Data, maxPixelSize: Int = 160) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
