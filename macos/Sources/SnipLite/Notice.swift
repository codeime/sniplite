import AppKit

/// sniplite's notices, all alike: a banner like a macOS notification, at the place chosen
/// in Settings (one for all of them). One shows at a time; a new one takes the last one's place.
enum Notice {
    /// What a banner is about, shown at its right.
    enum Lead {
        case picture(CGImage?)               // what was saved or copied, small
        case symbol(String, NSColor)
        case color(NSColor)
        case spinner                         // something is going on
    }

    private static var panel: NSPanel?
    private static var busyID = 0

    /// A banner that goes by itself. With `action` a click runs it (and the banner waits while the
    /// mouse is on it); without, the mouse goes through to what is under it.
    static func show(_ lead: Lead, _ title: String, _ detail: String? = nil, on screen: NSScreen? = nil,
                     tip: String? = nil, action: (() -> Void)? = nil) {
        let p = present(View(lead, title, detail, tip: tip, action: action), on: screen)
        fade(p, after: action == nil ? 2.2 : 4)
    }

    /// Something going on, shown until `done` or the next notice: a spinner, and after a while
    /// `slow`, why it takes longer. Returns what to pass to `done`.
    static func busy(_ title: String, slow: String, on screen: NSScreen?) -> Int {
        busyID += 1
        let id = busyID
        let p = present(View(.spinner, title, nil, tip: nil, action: nil), on: screen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard busyPanel === p, panel === p else { return }   // over (perhaps fading), or another notice
            _ = present(View(.spinner, title, slow, tip: nil, action: nil), on: screen)
            busyPanel = panel
        }
        busyPanel = p
        return id
    }
    /// The panel of the latest `busy`, as long as it is up.
    private static weak var busyPanel: NSPanel?

    /// What `id` showed is over (nothing, if another notice has taken its place).
    static func done(_ id: Int) {
        guard id == busyID, let p = busyPanel else { return }
        busyPanel = nil
        if panel === p { fade(p, after: 0) }
    }

    /// Off the screen at once: a capture is about to be taken.
    static func hide() {
        panel?.orderOut(nil)
        panel = nil
        busyPanel = nil
    }

    // MARK: the panel

    private static func present(_ view: View, on screen: NSScreen?) -> NSPanel {
        let replacing = panel != nil
        panel?.orderOut(nil)
        panel = nil
        let place = Prefs.shared.noticePosition
        let height = view.height
        // as wide as what it holds, within reason
        let width = min(420, max(160, ceil(view.contentWidth)))
        view.setFrameSize(NSSize(width: width, height: height))
        let m = NSEvent.mouseLocation
        let vis = (screen ?? NSScreen.screens.first { NSMouseInRect(m, $0.frame, false) } ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin: CGPoint
        switch place {
        case "bottomRight": origin = CGPoint(x: vis.maxX - width - 12, y: vis.minY + 12)
        case "topCenter": origin = CGPoint(x: vis.midX - width / 2, y: vis.maxY - height - 12)
        case "center": origin = CGPoint(x: vis.midX - width / 2, y: vis.midY - height / 2)
        default: origin = CGPoint(x: vis.maxX - width - 12, y: vis.maxY - height - 12)
        }
        let p = NSPanel(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // above the capture screens: C copies a color while one is up
        p.level = NSWindow.Level(rawValue: OverlayWindow.selectLevel.rawValue + 1)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = view.action == nil
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        // weak: the panel holds the view, the view this closure; a strong reference would keep
        // every notice alive
        view.onClick = { [weak p, weak view] in
            view?.action?()
            p?.orderOut(nil)
            if panel === p { panel = nil }
        }
        p.contentView = view
        panel = p
        if replacing {                           // in place of another: no second slide
            p.orderFrontRegardless()
            p.invalidateShadow()
            return p
        }
        // in: it slides a little from the edge it sits at, fading in
        let dy: CGFloat = place == "bottomRight" ? -14 : (place == "center" ? 0 : 14)
        let end = p.frame
        p.setFrame(end.offsetBy(dx: 0, dy: dy), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            p.animator().alphaValue = 1
            p.animator().setFrame(end, display: true)
        }
        return p
    }

    private static func fade(_ p: NSPanel, after s: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s) {
            guard panel === p else { return }
            if (p.contentView as? View)?.hovered == true { fade(p, after: 1); return }   // still being read
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; p.animator().alphaValue = 0 }) {
                p.orderOut(nil)
                if panel === p { panel = nil }
            }
        }
    }

    /// A small copy of a capture for the banner (the full one is not kept).
    private static func thumbnail(_ img: CGImage?) -> NSImage? {
        guard let img else { return nil }
        // the whole picture within 160 x 100 (a tall or wide one would be huge by its width alone)
        let k = min(160 / CGFloat(img.width), 100 / CGFloat(img.height), 1)
        let w = max(1, Int(CGFloat(img.width) * k)), h = max(1, Int(CGFloat(img.height) * k))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: CGFloat(w) / 2, height: CGFloat(h) / 2)) }
    }

    // MARK: the banner

    /// The app's icon, small, beside the title; the detail under the title; at the right what
    /// it is about (the picture, the color, a mark, or a spinner). On Liquid Glass from macOS 26 on,
    /// on the notification material before.
    final class View: NSView {
        /// Lower without a second line; round ends then, as a capsule.
        let height: CGFloat
        private var radius: CGFloat { min(22, height / 2) }
        var onClick: () -> Void = {}
        let action: (() -> Void)?
        private let row = NSStackView()
        /// The width its content asks for.
        var contentWidth: CGFloat { row.fittingSize.width }
        private let sheen = NSView()
        private(set) var hovered = false { didSet { sheen.animator().alphaValue = hovered ? 1 : 0 } }

        init(_ lead: Lead, _ title: String, _ detail: String?, tip: String?, action: (() -> Void)?) {
            self.action = action
            height = detail == nil ? 44 : 60
            super.init(frame: NSRect(x: 0, y: 0, width: 420, height: height))
            let content = NSView(frame: bounds)
            addBackground(content)

            // a light wash on hover, where it is a button
            sheen.wantsLayer = true
            sheen.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
            sheen.layer?.cornerRadius = radius
            sheen.layer?.cornerCurve = .continuous
            sheen.alphaValue = 0
            sheen.frame = content.bounds
            sheen.autoresizingMask = [.width, .height]
            content.addSubview(sheen)

            let icon = NSImageView(image: NSApp.applicationIconImage ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
            icon.imageScaling = .scaleProportionallyUpOrDown
            Self.fix(icon, 18, 18)

            // the texts: the title, then the detail from where the title begins
            let t = NSTextField(labelWithString: title)
            t.font = .systemFont(ofSize: 13, weight: .semibold)
            t.textColor = .labelColor
            let text = NSStackView(views: [t])
            text.orientation = .vertical
            text.alignment = .leading
            text.spacing = 3
            text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            if let detail {
                let d = NSTextField(labelWithString: detail)
                d.font = .systemFont(ofSize: 13)
                d.textColor = Self.detailColor
                d.maximumNumberOfLines = 1
                d.lineBreakMode = action == nil ? .byTruncatingTail : .byTruncatingMiddle   // a path keeps its end
                d.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                text.addArrangedSubview(d)
            }

            row.setViews([text, Self.mark(lead)], in: .leading)
            row.spacing = 16
            if action != nil {                                   // it can be clicked
                let chevron = NSImageView(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage())
                chevron.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
                chevron.contentTintColor = Self.detailColor
                row.addArrangedSubview(chevron)
                row.setCustomSpacing(10, after: row.arrangedSubviews[1])
            }
            row.alignment = .centerY
            row.edgeInsets = NSEdgeInsets(top: 0, left: 16 + 18 + 7, bottom: 0, right: 14)      // room for the icon
            row.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(row)
            content.addSubview(icon)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: content.leadingAnchor), row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                row.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                icon.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
                icon.centerYAnchor.constraint(equalTo: t.centerYAnchor),       // beside the title, not between the lines
            ])
            toolTip = tip
            if action != nil {
                addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                               owner: self, userInfo: nil))
            }
        }
        required init?(coder: NSCoder) { fatalError() }

        private func addBackground(_ content: NSView) {
            content.autoresizingMask = [.width, .height]
            #if compiler(>=6.2)                                  // the macOS 26 SDK
            if #available(macOS 26.0, *) {
                let g = NSGlassEffectView(frame: bounds)
                g.style = .regular
                g.cornerRadius = radius
                g.autoresizingMask = [.width, .height]
                g.contentView = content
                addSubview(g)
                return
            }
            #endif
            let v = NSVisualEffectView(frame: bounds)
            v.material = .popover
            v.blendingMode = .behindWindow
            v.state = .active
            v.autoresizingMask = [.width, .height]
            let r: CGFloat = 18                                  // the shadow follows the mask
            let mask = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
                NSColor.black.setFill(); NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill(); return true
            }
            mask.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
            mask.resizingMode = .stretch
            v.maskImage = mask
            addSubview(v)
            v.addSubview(content)
        }

        /// Quieter than the title, yet easy to read: the system's secondary color is too faint on
        /// glass (about 3:1) for what the notice is about.
        private static let detailColor = NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.82) : NSColor(white: 0, alpha: 0.74)
        }

        private static func fix(_ v: NSView, _ w: CGFloat, _ h: CGFloat) {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalToConstant: w).isActive = true
            v.heightAnchor.constraint(equalToConstant: h).isActive = true
        }

        /// What it is about, at the right.
        private static func mark(_ lead: Lead) -> NSView {
            switch lead {
            case .picture(let img):
                // as a notification's picture: its own proportions within 56 x 40, rounded
                let thumb = Notice.thumbnail(img)
                let k = thumb.map { min(56 / $0.size.width, 40 / $0.size.height) } ?? 0
                let w = max(20, (thumb?.size.width ?? 0) * k), h = max(14, (thumb?.size.height ?? 0) * k)
                let pic = NSView()
                pic.wantsLayer = true
                pic.layer?.contents = thumb
                pic.layer?.contentsGravity = .resizeAspectFill
                pic.layer?.cornerRadius = 7
                pic.layer?.cornerCurve = .continuous
                pic.layer?.masksToBounds = true
                pic.layer?.borderWidth = 0.5
                pic.layer?.borderColor = NSColor.separatorColor.cgColor
                fix(pic, w, h)
                return pic
            case .symbol(let name, let color):
                let s = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage())
                s.symbolConfiguration = .init(pointSize: 16, weight: .medium)
                s.contentTintColor = color
                return s
            case .color(let c):
                let dot = NSView()
                dot.wantsLayer = true
                dot.layer?.cornerRadius = 11
                dot.layer?.backgroundColor = c.cgColor
                dot.layer?.borderWidth = 1
                dot.layer?.borderColor = NSColor.separatorColor.cgColor
                fix(dot, 22, 22)
                return dot
            case .spinner:
                // the system's wheel as a symbol, in the text's color: the control itself is very
                // faint on dark glass
                if #available(macOS 15.0, *), let wheel = NSImage(systemSymbolName: "progress.indicator", accessibilityDescription: nil) {
                    let s = NSImageView(image: wheel)
                    s.symbolConfiguration = .init(pointSize: 16, weight: .semibold)
                    s.contentTintColor = .labelColor
                    s.addSymbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeat(.continuous))
                    return s
                }
                let s = NSProgressIndicator()
                s.style = .spinning
                s.controlSize = .small
                s.isIndeterminate = true
                s.startAnimation(nil)
                return s
            }
        }

        override func mouseEntered(with event: NSEvent) { hovered = true }
        override func mouseExited(with event: NSEvent) { hovered = false }
        /// The whole banner is one button: its pictures and texts never take the click for themselves.
        override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {}
        override func mouseUp(with event: NSEvent) {
            if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }   // let go outside: no
        }
        override func resetCursorRects() { if action != nil { addCursorRect(bounds, cursor: .pointingHand) } }
    }
}

extension Notice {
    /// An image is on the clipboard.
    static func copied(_ img: CGImage) {
        show(.picture(img), L.t("imageCopied"), "\(img.width) × \(img.height)")
    }

    /// Text is on the clipboard, with how it begins.
    static func copied(text: String, title: String, on screen: NSScreen? = nil) {
        let first = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        let short = first.count > 60 ? String(first.prefix(60)) + "…" : first
        show(.symbol("checkmark.circle.fill", .systemGreen), title, short.isEmpty ? nil : short.replacingOccurrences(of: "\t", with: "  "), on: screen)
    }
}
