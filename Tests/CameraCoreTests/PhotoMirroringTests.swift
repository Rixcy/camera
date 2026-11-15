import CameraCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@Suite struct PhotoMirroringTests {
    private func makeJPEG() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func orientation(of data: Data) throws -> UInt32? {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        return properties?[kCGImagePropertyOrientation] as? UInt32
    }

    @Test func mirroredSetsUpMirroredOrientationAndKeepsPixels() throws {
        let original = try makeJPEG()
        let mirrored = try #require(PhotoMirroring.mirrored(original))
        #expect(try orientation(of: mirrored) == CGImagePropertyOrientation.upMirrored.rawValue)

        let source = try #require(CGImageSourceCreateWithData(mirrored as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 8 && image.height == 4)
    }

    @Test func mirroringTwiceRestoresOrientation() throws {
        let once = try #require(PhotoMirroring.mirrored(try makeJPEG()))
        let twice = try #require(PhotoMirroring.mirrored(once))
        #expect(try orientation(of: twice) == CGImagePropertyOrientation.up.rawValue)
    }

    @Test func flipTableIsAnInvolution() {
        let all: [CGImagePropertyOrientation] = [.up, .upMirrored, .down, .downMirrored, .left, .leftMirrored, .right, .rightMirrored]
        for orientation in all {
            #expect(PhotoMirroring.horizontallyFlipped(orientation) != orientation)
            #expect(PhotoMirroring.horizontallyFlipped(PhotoMirroring.horizontallyFlipped(orientation)) == orientation)
        }
        #expect(PhotoMirroring.horizontallyFlipped(.right) == .leftMirrored)
    }

    @Test func nonImageDataIsRejected() {
        #expect(PhotoMirroring.mirrored(Data("not an image".utf8)) == nil)
    }
}
