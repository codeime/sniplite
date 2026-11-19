import AppKit

/// ⇧F1: the screen under the mouse straight to a file, no capture screen (from sniplite 1.4 for
/// Windows). The file goes to the folder chosen in Settings (the Desktop by default); a notice
/// like a macOS banner says so, and a click on it shows the file in Finder.
enum QuickCapture {
    static func run() {
        Task { @MainActor in
            guard Permission.screenRecording.granted else { PermissionsWindow.show(); return }
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
            do {
                guard let shot = try await Capture.captureAll(only: screen).first else { return }
                let url = try save(shot)
                Log.write("quick capture: \(url.path)")
                if Prefs.shared.quickNotice {
                    CornerNotice.show(title: L.t("quickSaved"), detail: url.path, on: screen) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } else {
                    AppDelegate.snip()                    // the menu bar scissors say it, quietly
                }
            } catch CaptureError.noPermission {
                AppDelegate.askForPermission()
            } catch {
                NSSound.beep()
                Log.write("quick capture failed: \(error)")
            }
            CaptureSession.releaseMemory()
        }
    }

    /// sniplite_<date>_<time>.png in the folder; a number added if that name is taken.
    static func save(_ shot: DisplayShot) throws -> URL {
        let folder = Prefs.shared.quickFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        let base = "sniplite_\(f.string(from: Date()))"
        var url = folder.appendingPathComponent(base + ".png")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base)_\(n).png"); n += 1
        }
        let rep = NSBitmapImageRep(cgImage: shot.image)
        rep.size = shot.screen.frame.size
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.failed("png")
        }
        try data.write(to: url)
        return url
    }
}

/// A notice like a macOS notification banner: in the top right corner of the screen, frosted,
/// with sniplite's icon and name, a title and a line (a path, shortened in the middle); a click
/// runs `action`. It fades after a few seconds, later while the mouse is on it.
enum CornerNotice {
    private static var panel: NSPanel?

    static func show(title: String, detail: String, on screen: NSScreen, action: @escaping () -> Void) {
        panel?.orderOut(nil)
        panel = nil
        // a banner in a corner or at the top; a square card in the middle
        let place = Prefs.shared.noticePosition
        let card = false                         // one look everywhere: a banner, compact in the middle
        let compact = place == "center"
        let width: CGFloat = compact ? 300 : 344, height: CGFloat = compact ? 60 : 72
        let vis = screen.visibleFrame
        let origin: CGPoint
        switch place {
        case "bottomRight": origin = CGPoint(x: vis.maxX - width - 12, y: vis.minY + 12)
        case "topCenter": origin = CGPoint(x: vis.midX - width / 2, y: vis.maxY - height - 12)
        case "center": origin = CGPoint(x: vis.midX - width / 2, y: vis.midY - height / 2)
        default: origin = CGPoint(x: vis.maxX - width - 12, y: vis.maxY - height - 12)
        }
        let p = NSPanel(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        // weak: the panel holds the view, the view this closure; a strong reference would keep
        // every notice alive
        p.contentView = NoticeView(frame: NSRect(x: 0, y: 0, width: width, height: height), title: title,
                                   detail: detail, card: card) { [weak p] in
            action()
            p?.orderOut(nil)
            if panel === p { panel = nil }
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.invalidateShadow()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; p.animator().alphaValue = 1 }
        panel = p
        fade(p, after: 4)
    }

    private static func fade(_ p: NSPanel, after s: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s) {
            guard panel === p else { return }
            if (p.contentView as? NoticeView)?.hovered == true { fade(p, after: 1); return }   // still being read
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; p.animator().alphaValue = 0 }) {
                p.orderOut(nil)
                if panel === p { panel = nil }
            }
        }
    }

    private final class NoticeView: NSVisualEffectView {
        let onClick: () -> Void
        private(set) var hovered = false
        init(frame: NSRect, title: String, detail: String, card: Bool, onClick: @escaping () -> Void) {
            self.onClick = onClick
            super.init(frame: frame)
            material = .popover
            blendingMode = .behindWindow
            state = .active
            let r: CGFloat = card ? 20 : 16          // rounded like a banner; the shadow follows the mask
            let mask = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
                NSColor.black.setFill(); NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill(); return true
            }
            mask.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
            mask.resizingMode = .stretch
            maskImage = mask

            let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.translatesAutoresizingMaskIntoConstraints = false
            let side: CGFloat = card ? 48 : (frame.height < 66 ? 30 : 38)
            icon.widthAnchor.constraint(equalToConstant: side).isActive = true
            icon.heightAnchor.constraint(equalToConstant: side).isActive = true
            let app = NSTextField(labelWithString: "sniplite")
            app.font = .systemFont(ofSize: 11, weight: .semibold)
            app.textColor = .secondaryLabelColor
            let t = NSTextField(labelWithString: title)
            t.font = .systemFont(ofSize: 13, weight: .semibold)
            t.textColor = .labelColor
            let d = NSTextField(labelWithString: detail)
            d.font = .systemFont(ofSize: 12)
            d.textColor = .secondaryLabelColor
            d.lineBreakMode = .byTruncatingMiddle
            d.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let text = NSStackView(views: [app, t, d])
            text.orientation = .vertical
            text.alignment = card ? .centerX : .leading
            text.spacing = 1
            text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            if card {
                // in the middle: the icon above, everything centered, like a macOS HUD
                for f in [app, t, d] { f.alignment = .center }
                t.font = .systemFont(ofSize: 15, weight: .semibold)
                let col = NSStackView(views: [icon, text])
                col.orientation = .vertical
                col.alignment = .centerX
                col.spacing = 10
                col.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
                col.translatesAutoresizingMaskIntoConstraints = false
                addSubview(col)
                NSLayoutConstraint.activate([
                    col.leadingAnchor.constraint(equalTo: leadingAnchor), col.trailingAnchor.constraint(equalTo: trailingAnchor),
                    col.centerYAnchor.constraint(equalTo: centerYAnchor),
                    text.widthAnchor.constraint(lessThanOrEqualTo: col.widthAnchor, constant: -32),
                ])
            } else {
                let row = NSStackView(views: [icon, text])
                row.spacing = 10
                row.alignment = .centerY
                row.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 16)
                row.translatesAutoresizingMaskIntoConstraints = false
                addSubview(row)
                NSLayoutConstraint.activate([
                    row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
                    row.centerYAnchor.constraint(equalTo: centerYAnchor),
                ])
            }
            toolTip = L.t("showInFinder")
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }
        required init?(coder: NSCoder) { fatalError() }
        override func mouseEntered(with event: NSEvent) { hovered = true }
        override func mouseExited(with event: NSEvent) { hovered = false }
        /// The whole banner is one button: its icon and texts never take the click for themselves.
        override func hitTest(_ point: NSPoint) -> NSView? {
            frame.contains(point) ? self : nil
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {}
        override func mouseUp(with event: NSEvent) {
            if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }   // let go outside: no
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    }
}
