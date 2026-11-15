import Foundation

public enum PhotoNaming {
    /// "Photo 2026-11-16 at 10.01.02" — the same shape macOS uses for
    /// screenshots, so photos sort by time in Finder.
    public static func baseName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Photo \(formatter.string(from: date))"
    }

    /// A file URL in `directory` that `exists` reports as free, adding
    /// " 2", " 3"… when several photos are taken within the same second.
    public static func uniqueURL(
        in directory: URL,
        for date: Date,
        pathExtension: String = "jpg",
        timeZone: TimeZone = .current,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let base = baseName(for: date, timeZone: timeZone)
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(pathExtension)
        var counter = 2
        while exists(candidate) {
            candidate = directory
                .appendingPathComponent("\(base) \(counter)")
                .appendingPathExtension(pathExtension)
            counter += 1
        }
        return candidate
    }
}
