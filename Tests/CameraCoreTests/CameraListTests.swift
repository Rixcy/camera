import CameraCore
import Testing

private let facetime = CameraInfo(id: "builtin", name: "FaceTime HD Camera", kind: .builtIn)
private let iphone = CameraInfo(id: "iphone", name: "iPhone Camera", kind: .continuity)
private let desk = CameraInfo(id: "desk", name: "iPhone Desk View Camera", kind: .deskView)
private let logitech = CameraInfo(id: "logi", name: "Logitech BRIO", kind: .external)
private let anker = CameraInfo(id: "anker", name: "Anker PowerConf C200", kind: .external)

@Suite struct CameraListTests {
    @Test func sortsBuiltInThenContinuityThenExternalThenDeskView() {
        let sorted = CameraList.sorted([desk, logitech, iphone, anker, facetime])
        #expect(sorted == [facetime, iphone, anker, logitech, desk])
    }

    @Test func prefersRememberedCameraWhenConnected() {
        #expect(CameraList.preferred(in: [facetime, logitech], remembered: "logi") == logitech)
    }

    @Test func fallsBackToFirstSortedWhenRememberedCameraIsGone() {
        #expect(CameraList.preferred(in: [logitech, facetime], remembered: "iphone") == facetime)
        #expect(CameraList.preferred(in: [logitech, facetime], remembered: nil) == facetime)
    }

    @Test func noCamerasMeansNoPreference() {
        #expect(CameraList.preferred(in: [], remembered: "builtin") == nil)
        #expect(CameraList.next(after: "builtin", in: []) == nil)
    }

    @Test func nextCyclesInSortedOrderAndWraps() {
        let cameras = [logitech, facetime, iphone]
        #expect(CameraList.next(after: "builtin", in: cameras) == iphone)
        #expect(CameraList.next(after: "iphone", in: cameras) == logitech)
        #expect(CameraList.next(after: "logi", in: cameras) == facetime)
    }

    @Test func nextWithSingleCameraStaysPut() {
        #expect(CameraList.next(after: "builtin", in: [facetime]) == facetime)
    }

    @Test func nextFromUnknownCameraStartsAtFirst() {
        #expect(CameraList.next(after: nil, in: [logitech, facetime]) == facetime)
        #expect(CameraList.next(after: "gone", in: [logitech, facetime]) == facetime)
    }

    @Test func onlyDeskViewIsUnmirrored() {
        #expect(facetime.isMirrored)
        #expect(iphone.isMirrored)
        #expect(logitech.isMirrored)
        #expect(!desk.isMirrored)
    }
}
