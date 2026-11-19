import AppKit

/// The menu bar icon, drawn to match the app icon: four corner marks round the capture and the
/// bolt leaning a little, in one color (a template: macOS colors it for light and dark).
enum MenuBarIcon {
    /// `focus`: how far the corner marks have drawn in (0 at rest, 1 fully in); `flash`: how bright
    /// the bolt is (1 normal, lower dims it); `boltScale` grows or shrinks the bolt.
    static func image(size s: CGFloat = 18, focus: CGFloat = 0, flash: CGFloat = 1, boltScale: CGFloat = 1) -> NSImage {
        let img = NSImage(size: NSSize(width: s, height: s), flipped: true) { _ in
            let k = s / 18                                     // drawn on an 18 pt grid
            NSColor.black.set()

            // the corner marks: right angles with a small round turn and round ends, a third of each side
            let inset = (1.7 + 1.3 * focus) * k, arm = 4.6 * k, turn = 1.9 * k
            let box = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
            let marks = NSBezierPath()
            marks.lineWidth = 1.6 * k
            marks.lineCapStyle = .round
            marks.lineJoinStyle = .round
            for (c, dx, dy) in [(NSPoint(x: box.minX, y: box.minY), 1.0, 1.0), (NSPoint(x: box.maxX, y: box.minY), -1.0, 1.0),
                                (NSPoint(x: box.maxX, y: box.maxY), -1.0, -1.0), (NSPoint(x: box.minX, y: box.maxY), 1.0, -1.0)] {
                // along one side to the turn, round it, along the other side
                marks.move(to: NSPoint(x: c.x + dx * arm, y: c.y))
                marks.line(to: NSPoint(x: c.x + dx * turn, y: c.y))
                marks.curve(to: NSPoint(x: c.x, y: c.y + dy * turn),
                            controlPoint1: NSPoint(x: c.x + dx * turn * 0.45, y: c.y),
                            controlPoint2: NSPoint(x: c.x, y: c.y + dy * turn * 0.45))
                marks.line(to: NSPoint(x: c.x, y: c.y + dy * arm))
            }
            marks.stroke()

            // the bolt, the app icon's shape, leaning 10°
            let p: [(CGFloat, CGFloat)] = [(0.64, 0.00), (0.16, 0.57), (0.46, 0.57), (0.34, 1.00), (0.86, 0.41), (0.55, 0.41), (0.70, 0.00)]
            let h = 10.8 * k * boltScale, tilt = 10 * CGFloat.pi / 180, cx = s / 2, cy = s / 2
            let bolt = NSBezierPath()
            for (i, (x, y)) in p.enumerated() {
                let dx = (x - 0.5) * h, dy = (y - 0.5) * h
                let q = NSPoint(x: cx + dx * cos(tilt) - dy * sin(tilt), y: cy + dx * sin(tilt) + dy * cos(tilt))
                i == 0 ? bolt.move(to: q) : bolt.line(to: q)
            }
            bolt.close()
            NSColor.black.withAlphaComponent(max(0, min(1, flash))).set()
            bolt.fill()
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "sniplite"
        return img
    }

    /// A quick capture was saved: the corner marks draw in like a lens focusing, then spring back
    /// a little past their place and settle, while the bolt dims and comes back with a pop.
    /// 33 frames, about 0.55 s at 60 frames a second.
    static let snapFrameCount = 33
    static func snapFrame(_ i: Int) -> NSImage {
        let t = CGFloat(i) / CGFloat(snapFrameCount - 1)          // 0 … 1
        let focus: CGFloat
        if t < 0.2 { focus = ease(t / 0.2) }                       // in
        else {                                                      // back out, past, settling
            let u = (t - 0.2) / 0.8
            focus = cos(u * .pi * 1.5) * pow(1 - u, 1.6)
        }
        let flash: CGFloat = t < 0.2 ? 1 - 0.65 * ease(t / 0.2) : 0.35 + 0.65 * ease(min(1, (t - 0.2) / 0.3))
        let pop: CGFloat = t < 0.2 ? 1 - 0.08 * ease(t / 0.2) : 1 + 0.14 * sin(min(1, (t - 0.2) / 0.5) * .pi)
        return image(focus: focus, flash: flash, boltScale: pop)
    }

    private static func ease(_ x: CGFloat) -> CGFloat { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
}
