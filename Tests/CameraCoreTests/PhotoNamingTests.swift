import CameraCore
import Foundation
import Testing

@Suite struct PhotoNamingTests {
    private let utc = TimeZone(identifier: "UTC")!
    private let directory = URL(fileURLWithPath: "/tmp/Camera", isDirectory: true)
    // 2026-11-16 10:01:02 UTC
    private let date = Date(timeIntervalSince1970: 1_794_823_262)

    @Test func baseNameUsesScreenshotStyleTimestamp() {
        #expect(PhotoNaming.baseName(for: date, timeZone: utc) == "Photo 2026-11-16 at 10.01.02")
    }

    @Test func uniqueURLUsesBaseNameWhenFree() {
        let url = PhotoNaming.uniqueURL(in: directory, for: date, timeZone: utc, exists: { _ in false })
        #expect(url.lastPathComponent == "Photo 2026-11-16 at 10.01.02.jpg")
        #expect(url.deletingLastPathComponent().path == directory.path)
    }

    @Test func uniqueURLNumbersPhotosTakenInTheSameSecond() {
        let taken: Set<String> = [
            "Photo 2026-11-16 at 10.01.02.jpg",
            "Photo 2026-11-16 at 10.01.02 2.jpg",
        ]
        let url = PhotoNaming.uniqueURL(
            in: directory, for: date, timeZone: utc,
            exists: { taken.contains($0.lastPathComponent) }
        )
        #expect(url.lastPathComponent == "Photo 2026-11-16 at 10.01.02 3.jpg")
    }
}
