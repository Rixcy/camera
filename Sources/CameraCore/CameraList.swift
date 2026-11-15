/// A camera as the app sees it, independent of AVFoundation so the
/// selection rules can be tested without hardware.
public struct CameraInfo: Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: Int, Sendable, Comparable {
        case builtIn
        case continuity
        case external
        case deskView

        public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let id: String
    public let name: String
    public let kind: Kind

    public init(id: String, name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    /// Desk View shows the desk from above, so flipping it would make text
    /// on the desk read backwards. Every other camera faces the user.
    public var isMirrored: Bool { kind != .deskView }
}

public enum CameraList {
    /// Built-in first, then iPhone, external and Desk View cameras, each
    /// group ordered by name so the list stays stable as devices come and go.
    public static func sorted(_ cameras: [CameraInfo]) -> [CameraInfo] {
        cameras.sorted {
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            if $0.name != $1.name {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    /// The camera to open: the one used last time if it is still connected,
    /// otherwise the first in sorted order.
    public static func preferred(in cameras: [CameraInfo], remembered id: String?) -> CameraInfo? {
        if let id, let match = cameras.first(where: { $0.id == id }) {
            return match
        }
        return sorted(cameras).first
    }

    /// The camera after `id` in sorted order, wrapping around. Returns the
    /// first camera when `id` is nil or no longer connected.
    public static func next(after id: String?, in cameras: [CameraInfo]) -> CameraInfo? {
        let ordered = sorted(cameras)
        guard let index = ordered.firstIndex(where: { $0.id == id }) else {
            return ordered.first
        }
        return ordered[(index + 1) % ordered.count]
    }
}
