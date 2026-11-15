import Foundation
import ImageIO

public enum PhotoMirroring {
    /// The EXIF orientation that shows an image flipped left-to-right
    /// relative to `orientation`.
    public static func horizontallyFlipped(_ orientation: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .upMirrored
        case .upMirrored: .up
        case .down: .downMirrored
        case .downMirrored: .down
        case .left: .rightMirrored
        case .rightMirrored: .left
        case .right: .leftMirrored
        case .leftMirrored: .right
        }
    }

    /// Returns `imageData` with its orientation tag flipped so viewers show
    /// it mirrored, the way the live preview looks. Only metadata changes;
    /// the JPEG pixels are not re-encoded. Returns nil if the data isn't an
    /// image ImageIO can rewrite.
    public static func mirrored(_ imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source)
        else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let current = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationMergeMetadata: true,
            kCGImageDestinationOrientation: horizontallyFlipped(current).rawValue,
        ]
        guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil) else {
            return nil
        }
        return output as Data
    }
}
