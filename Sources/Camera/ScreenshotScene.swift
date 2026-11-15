#if DEBUG
import AppKit

/// A made-up orc waving from a desk, standing in for the camera feed in the
/// README screenshots. Both shots draw the same room; the close-up frames it
/// tighter, the way a laptop camera does next to a wider display camera.
enum ScreenshotScene {
    private static let size = NSSize(width: 1440, height: 960)

    static func closeUp() -> NSImage { image(zoom: 1.5, focus: NSPoint(x: 790, y: 540)) }
    static func wide() -> NSImage { image(zoom: 1, focus: NSPoint(x: 720, y: 480)) }

    /// Draws the room scaled by `zoom` around `focus`, which lands in the middle.
    private static func image(zoom: CGFloat, focus: NSPoint) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX, yBy: rect.midY)
            transform.scale(by: zoom)
            transform.translateX(by: -focus.x, yBy: -focus.y)
            transform.concat()
            drawWall()
            drawWindow()
            drawShelf()
            drawOrc()
            return true
        }
    }

    // MARK: Room

    private static func drawWall() {
        NSGradient(starting: rgb(0.93, 0.84, 0.70), ending: rgb(0.78, 0.65, 0.51))!
            .draw(in: NSRect(origin: .zero, size: size), angle: -90)
    }

    private static func drawWindow() {
        fill(rgb(0.45, 0.30, 0.20), NSBezierPath(rect: NSRect(x: 130, y: 420, width: 320, height: 380)))
        let glass = NSRect(x: 150, y: 440, width: 280, height: 340)
        NSGradient(colors: [
            rgb(0.98, 0.72, 0.48), rgb(0.86, 0.50, 0.52), rgb(0.30, 0.32, 0.55),
        ])!.draw(in: glass, angle: 90)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: glass).addClip()
        let hill = NSBezierPath()
        hill.move(to: NSPoint(x: 150, y: 440))
        hill.line(to: NSPoint(x: 150, y: 540))
        hill.curve(to: NSPoint(x: 430, y: 520),
                   controlPoint1: NSPoint(x: 240, y: 600), controlPoint2: NSPoint(x: 330, y: 470))
        hill.line(to: NSPoint(x: 430, y: 440))
        hill.close()
        fill(rgb(0.27, 0.20, 0.34), hill)
        NSGraphicsContext.restoreGraphicsState()
        fill(rgb(0.45, 0.30, 0.20), NSBezierPath(rect: NSRect(x: 284, y: 440, width: 12, height: 340)))
        fill(rgb(0.45, 0.30, 0.20), NSBezierPath(rect: NSRect(x: 150, y: 604, width: 280, height: 12)))
        fill(rgb(0.56, 0.39, 0.27), NSBezierPath(rect: NSRect(x: 115, y: 404, width: 350, height: 22)))
    }

    private static func drawShelf() {
        fill(rgb(0.56, 0.39, 0.27), NSBezierPath(rect: NSRect(x: 1110, y: 440, width: 300, height: 18)))
        let books: [(x: CGFloat, width: CGFloat, height: CGFloat, color: NSColor)] = [
            (1130, 34, 110, rgb(0.62, 0.22, 0.20)),
            (1166, 28, 96, rgb(0.24, 0.36, 0.52)),
            (1196, 38, 118, rgb(0.85, 0.66, 0.30)),
        ]
        for book in books {
            fill(book.color, NSBezierPath(rect: NSRect(x: book.x, y: 458, width: book.width, height: book.height)))
        }
        for (angle, length) in [(70.0, 110.0), (100.0, 120.0), (130.0, 100.0), (45.0, 80.0), (155.0, 85.0)] {
            let radians = angle * .pi / 180
            let tip = NSPoint(x: 1330 + cos(radians) * length, y: 520 + sin(radians) * length)
            stroke(rgb(0.30, 0.55, 0.45), width: 26, from: NSPoint(x: 1330, y: 520), to: tip)
        }
        let pot = NSBezierPath()
        pot.move(to: NSPoint(x: 1300, y: 458))
        pot.line(to: NSPoint(x: 1360, y: 458))
        pot.line(to: NSPoint(x: 1372, y: 530))
        pot.line(to: NSPoint(x: 1288, y: 530))
        pot.close()
        fill(rgb(0.78, 0.42, 0.28), pot)
    }

    private static func drawDesk() {
        fill(rgb(0.55, 0.38, 0.25), NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: 190)))
        fill(rgb(0.64, 0.46, 0.31), NSBezierPath(rect: NSRect(x: 0, y: 178, width: size.width, height: 18)))

        let mug = NSBezierPath(roundedRect: NSRect(x: 330, y: 192, width: 72, height: 86), xRadius: 10, yRadius: 10)
        let handle = NSBezierPath(ovalIn: NSRect(x: 386, y: 212, width: 46, height: 46))
        handle.lineWidth = 12
        rgb(0.25, 0.45, 0.60).setStroke()
        handle.stroke()
        fill(rgb(0.25, 0.45, 0.60), mug)
    }

    // MARK: Orc

    private static let skin = rgb(0.49, 0.68, 0.35)
    private static let skinShade = rgb(0.40, 0.57, 0.28)
    private static let skinDark = rgb(0.25, 0.38, 0.18)
    private static let tunic = rgb(0.48, 0.32, 0.22)
    private static let tunicShade = rgb(0.40, 0.26, 0.18)
    private static let leather = rgb(0.30, 0.19, 0.13)
    private static let gold = rgb(0.92, 0.74, 0.32)
    private static let ivory = rgb(0.98, 0.95, 0.86)

    private static func drawOrc() {
        drawBody()
        drawHead()
        drawDesk()
        fill(skin, NSBezierPath(ovalIn: NSRect(x: 560, y: 176, width: 96, height: 58)))
        drawWavingArm()
    }

    private static func drawBody() {
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 500, y: 0))
        body.line(to: NSPoint(x: 530, y: 330))
        body.curve(to: NSPoint(x: 640, y: 430),
                   controlPoint1: NSPoint(x: 540, y: 400), controlPoint2: NSPoint(x: 580, y: 425))
        body.line(to: NSPoint(x: 800, y: 430))
        body.curve(to: NSPoint(x: 910, y: 330),
                   controlPoint1: NSPoint(x: 860, y: 425), controlPoint2: NSPoint(x: 900, y: 400))
        body.line(to: NSPoint(x: 940, y: 0))
        body.close()
        fill(tunic, body)

        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        // The resting arm reaches down to the desk.
        stroke(tunicShade, width: 84, from: NSPoint(x: 570, y: 360), to: NSPoint(x: 600, y: 200))
        stroke(leather, width: 28, from: NSPoint(x: 590, y: 430), to: NSPoint(x: 900, y: 40))
        fill(gold, NSBezierPath(roundedRect: NSRect(x: 712, y: 248, width: 40, height: 40), xRadius: 6, yRadius: 6))
        NSGraphicsContext.restoreGraphicsState()

        fill(skinShade, NSBezierPath(rect: NSRect(x: 668, y: 400, width: 104, height: 90)))
        fill(rgb(0.86, 0.80, 0.68), NSBezierPath(ovalIn: NSRect(x: 600, y: 392, width: 240, height: 64)))
    }

    private static func drawHead() {
        // The ears go behind the head.
        for side in [-1.0, 1.0] as [CGFloat] {
            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: 720 + side * 100, y: 610))
            ear.curve(to: NSPoint(x: 720 + side * 215, y: 668),
                      controlPoint1: NSPoint(x: 720 + side * 150, y: 625), controlPoint2: NSPoint(x: 720 + side * 190, y: 650))
            ear.curve(to: NSPoint(x: 720 + side * 108, y: 540),
                      controlPoint1: NSPoint(x: 720 + side * 200, y: 600), controlPoint2: NSPoint(x: 720 + side * 160, y: 545))
            ear.close()
            fill(skin, ear)
            let inner = NSBezierPath()
            inner.move(to: NSPoint(x: 720 + side * 112, y: 600))
            inner.line(to: NSPoint(x: 720 + side * 185, y: 645))
            inner.line(to: NSPoint(x: 720 + side * 118, y: 560))
            inner.close()
            fill(skinShade, inner)
        }
        let ring = NSBezierPath(ovalIn: NSRect(x: 832, y: 520, width: 30, height: 30))
        ring.lineWidth = 7
        gold.setStroke()
        ring.stroke()

        fill(skin, NSBezierPath(ovalIn: NSRect(x: 600, y: 450, width: 240, height: 250)))
        fill(skin, NSBezierPath(ovalIn: NSRect(x: 588, y: 436, width: 264, height: 150)))

        fill(rgb(0.16, 0.12, 0.12), NSBezierPath(ovalIn: NSRect(x: 683, y: 688, width: 74, height: 64)))
        fill(rgb(0.70, 0.24, 0.20), NSBezierPath(roundedRect: NSRect(x: 698, y: 684, width: 44, height: 16), xRadius: 6, yRadius: 6))

        // Brows lower at the outer ends read as friendly; the other way round, as angry.
        stroke(skinDark, width: 16, from: NSPoint(x: 648, y: 616), to: NSPoint(x: 700, y: 626))
        stroke(skinDark, width: 16, from: NSPoint(x: 792, y: 616), to: NSPoint(x: 740, y: 626))
        for x in [676, 764] as [CGFloat] {
            fill(rgb(0.12, 0.10, 0.10), NSBezierPath(ovalIn: NSRect(x: x - 13, y: 576, width: 26, height: 30)))
            fill(.white, NSBezierPath(ovalIn: NSRect(x: x - 3, y: 592, width: 9, height: 9)))
            fill(rgb(0.90, 0.45, 0.35, 0.3), NSBezierPath(ovalIn: NSRect(x: x - 34 + (x < 720 ? -14 : 14), y: 520, width: 68, height: 34)))
        }

        fill(skinShade, NSBezierPath(ovalIn: NSRect(x: 690, y: 538, width: 60, height: 38)))
        for x in [706, 734] as [CGFloat] {
            fill(skinDark, NSBezierPath(ovalIn: NSRect(x: x - 5, y: 544, width: 10, height: 8)))
        }

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 660, y: 518))
        mouth.curve(to: NSPoint(x: 780, y: 518),
                    controlPoint1: NSPoint(x: 690, y: 462), controlPoint2: NSPoint(x: 750, y: 462))
        mouth.curve(to: NSPoint(x: 660, y: 518),
                    controlPoint1: NSPoint(x: 750, y: 508), controlPoint2: NSPoint(x: 690, y: 508))
        fill(rgb(0.32, 0.12, 0.12), mouth)
        for (base, tip) in [(CGFloat(684), CGFloat(692)), (756, 748)] {
            let tusk = NSBezierPath()
            tusk.move(to: NSPoint(x: base - 10, y: 482))
            tusk.line(to: NSPoint(x: base + 10, y: 480))
            tusk.line(to: NSPoint(x: tip, y: 534))
            tusk.close()
            fill(ivory, tusk)
        }
    }

    private static func drawWavingArm() {
        stroke(tunic, width: 86, from: NSPoint(x: 870, y: 370), to: NSPoint(x: 985, y: 450))
        stroke(skin, width: 62, from: NSPoint(x: 992, y: 455), to: NSPoint(x: 1052, y: 615))
        stroke(leather, width: 72, from: NSPoint(x: 1004, y: 487), to: NSPoint(x: 1030, y: 562))

        // The hand, tipped mid-wave.
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: 1062, yBy: 660)
        transform.rotate(byDegrees: -14)
        transform.concat()
        for (x, top) in [(-36, 96), (-12, 108), (12, 104), (36, 88)] as [(CGFloat, CGFloat)] {
            stroke(skin, width: 24, from: NSPoint(x: x, y: 20), to: NSPoint(x: x * 1.15, y: top))
        }
        stroke(skin, width: 28, from: NSPoint(x: -36, y: -14), to: NSPoint(x: -84, y: 32))
        fill(skin, NSBezierPath(roundedRect: NSRect(x: -52, y: -46, width: 104, height: 92), xRadius: 38, yRadius: 38))
        stroke(skinShade, width: 5, from: NSPoint(x: -22, y: -8), to: NSPoint(x: 18, y: 4))
        NSGraphicsContext.restoreGraphicsState()

        // Arcs beside the hand show it moving.
        for (radius, start, end) in [(150, -15, 35), (184, -5, 25)] as [(CGFloat, CGFloat, CGFloat)] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: 1062, y: 660), radius: radius, startAngle: start, endAngle: end)
            arc.lineWidth = 9
            arc.lineCapStyle = .round
            NSColor(white: 1, alpha: 0.85).setStroke()
            arc.stroke()
        }
    }

    // MARK: Drawing

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func fill(_ color: NSColor, _ path: NSBezierPath) {
        color.setFill()
        path.fill()
    }

    private static func stroke(_ color: NSColor, width: CGFloat, from start: NSPoint, to end: NSPoint) {
        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        line.lineWidth = width
        line.lineCapStyle = .round
        color.setStroke()
        line.stroke()
    }
}
#endif
