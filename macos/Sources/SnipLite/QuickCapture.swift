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
                AppDelegate.snip()                        // the menu bar icon says it every time
                if Prefs.shared.quickNotice {             // and the banner, with where it went, if wanted
                    CornerNotice.show(title: L.t("quickSaved"), file: url, image: shot.image, on: screen) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
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

    /// A banner like a macOS notification: a thumbnail of what was saved, the app, the title, the
    /// folder and file name, and a chevron; one click on it runs `action`.
    static func show(title: String, file: URL, image: CGImage?, on screen: NSScreen, action: @escaping () -> Void) {
        panel?.orderOut(nil)
        panel = nil
        let place = Prefs.shared.noticePosition
        let height: CGFloat = 78
        // as wide as what it holds (no blank before the chevron), within reason
        let view = NoticeView(frame: NSRect(x: 0, y: 0, width: 420, height: height), title: title,
                              file: file, thumb: thumbnail(image)) { }
        let width = min(420, max(280, ceil(view.contentWidth)))
        view.setFrameSize(NSSize(width: width, height: height))
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
        view.onClick = { [weak p] in
            action()
            p?.orderOut(nil)
            if panel === p { panel = nil }
        }
        p.contentView = view
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
        panel = p
        fade(p, after: 4)
    }

    /// A small copy of the capture for the banner (the full one is not kept).
    private static func thumbnail(_ img: CGImage?) -> NSImage? {
        guard let img else { return nil }
        let w = 160, h = max(1, Int(CGFloat(img.height) / CGFloat(img.width) * 160))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: CGFloat(w) / 2, height: CGFloat(h) / 2)) }
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

    /// The folder in sniplite's language (the Desktop), then the file name.
    static func place(of file: URL) -> String {
        let folder = file.deletingLastPathComponent().standardizedFileURL
        let name = folder == FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.standardizedFileURL
            ? L.t("desktopName") : FileManager.default.displayName(atPath: folder.path)
        return name + " · " + file.lastPathComponent
    }

    private final class NoticeView: NSVisualEffectView {
        var onClick: () -> Void
        private var row = NSStackView()
        /// The width its content asks for.
        var contentWidth: CGFloat { row.fittingSize.width }
        private let sheen = NSView()
        private(set) var hovered = false { didSet { sheen.animator().alphaValue = hovered ? 1 : 0 } }
        init(frame: NSRect, title: String, file: URL, thumb: NSImage?, onClick: @escaping () -> Void) {
            self.onClick = onClick
            super.init(frame: frame)
            material = .popover
            blendingMode = .behindWindow
            state = .active
            let r: CGFloat = 18                      // rounded like a notification; the shadow follows the mask
            let mask = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
                NSColor.black.setFill(); NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill(); return true
            }
            mask.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
            mask.resizingMode = .stretch
            maskImage = mask

            // a light wash on hover: it is a button
            sheen.wantsLayer = true
            sheen.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
            sheen.alphaValue = 0
            sheen.frame = bounds
            sheen.autoresizingMask = [.width, .height]
            addSubview(sheen)

            // the thumbnail: what was saved
            let pic = NSImageView()
            pic.image = thumb ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            pic.imageScaling = .scaleProportionallyUpOrDown
            pic.wantsLayer = true
            pic.layer?.cornerRadius = 7
            pic.layer?.masksToBounds = true
            pic.layer?.borderWidth = 0.5
            pic.layer?.borderColor = NSColor.separatorColor.cgColor
            pic.translatesAutoresizingMaskIntoConstraints = false
            let picW: CGFloat = thumb == nil ? 44 : 72, picH: CGFloat = thumb == nil ? 44 : 46
            pic.widthAnchor.constraint(equalToConstant: picW).isActive = true
            pic.heightAnchor.constraint(equalToConstant: picH).isActive = true
            let holder = NSView()                    // a soft shadow under the thumbnail
            holder.wantsLayer = true
            holder.shadow = NSShadow()
            holder.layer?.shadowColor = NSColor.black.cgColor
            holder.layer?.shadowOpacity = 0.18
            holder.layer?.shadowRadius = 4
            holder.layer?.shadowOffset = CGSize(width: 0, height: -1)
            holder.translatesAutoresizingMaskIntoConstraints = false
            holder.addSubview(pic)
            NSLayoutConstraint.activate([
                pic.leadingAnchor.constraint(equalTo: holder.leadingAnchor), pic.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                pic.topAnchor.constraint(equalTo: holder.topAnchor), pic.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            ])

            // the texts: the app (small, with its icon), the title, the folder and file
            let appIcon = NSImageView(image: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
            appIcon.imageScaling = .scaleProportionallyUpOrDown
            appIcon.translatesAutoresizingMaskIntoConstraints = false
            appIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            appIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true
            let app = NSTextField(labelWithString: "sniplite")
            app.font = .systemFont(ofSize: 11, weight: .medium)
            app.textColor = .secondaryLabelColor
            let now = NSTextField(labelWithString: "· " + L.t("justNow"))
            now.font = .systemFont(ofSize: 11)
            now.textColor = .tertiaryLabelColor
            let top = NSStackView(views: [appIcon, app, now])
            top.spacing = 4
            top.alignment = .centerY
            let t = NSTextField(labelWithString: title)
            t.font = .systemFont(ofSize: 13.5, weight: .semibold)
            t.textColor = .labelColor
            let d = NSTextField(labelWithString: CornerNotice.place(of: file))
            d.font = .systemFont(ofSize: 12)
            d.textColor = .secondaryLabelColor
            d.lineBreakMode = .byTruncatingMiddle
            d.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let text = NSStackView(views: [top, t, d])
            text.orientation = .vertical
            text.alignment = .leading
            text.spacing = 2
            text.setCustomSpacing(3, after: top)
            text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let chevron = NSImageView(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)!)
            chevron.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
            chevron.contentTintColor = .tertiaryLabelColor

            row = NSStackView(views: [holder, text, chevron])
            row.spacing = 12
            row.alignment = .centerY
            row.setCustomSpacing(10, after: text)
            row.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 16)
            row.translatesAutoresizingMaskIntoConstraints = false
            addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
                row.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            toolTip = L.t("showInFinder")
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }
        required init?(coder: NSCoder) { fatalError() }
        override func mouseEntered(with event: NSEvent) { hovered = true }
        override func mouseExited(with event: NSEvent) { hovered = false }
        /// The whole banner is one button: its pictures and texts never take the click for themselves.
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
