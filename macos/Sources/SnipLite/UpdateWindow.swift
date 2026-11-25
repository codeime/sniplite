import AppKit

/// A new version: what is in it, and whether to install it. Opened by a check the user asked for or
/// from the menu; a check in the background offers it without taking the keyboard, when the user is
/// not in the middle of something.
@MainActor
final class UpdateWindow: NSObject, NSWindowDelegate {
    private(set) static var shared: UpdateWindow?
    private static var pending: Timer?

    /// `activate`: the user asked for it.
    static func show(activate: Bool) {
        pending?.invalidate()
        pending = nil
        guard let r = Updater.shared.latest, Updater.newer(r.version, than: Updater.current) else { return }
        if let s = shared, s.release.version != r.version { s.window.close() }       // an older one left open
        let w = shared ?? UpdateWindow(r)
        let new = shared == nil
        shared = w
        if new { w.window.center() }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            w.window.makeKeyAndOrderFront(nil)
        } else {
            w.window.orderFrontRegardless()
        }
    }

    /// From a check in the background: now, or when the user is free.
    static func offer() {
        if shared != nil || !busy() { show(activate: false); return }
        pending?.invalidate()
        let t = Timer(timeInterval: 3, repeats: true) { t in
            MainActor.assumeIsolated {
                guard case .available = Updater.shared.state else { t.invalidate(); pending = nil; return }
                if !busy() { show(activate: false) }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        pending = t
    }

    /// A capture is open, permissions are being given, or the screen is locked. (The tests take its place.)
    static var busy: () -> Bool = {
        if CaptureSession.current != nil || PermissionsWindow.shared?.window?.isVisible == true { return true }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return (session?["CGSSessionScreenIsLocked"] as? Bool) == true || (session?["kCGSSessionOnConsoleKey"] as? Bool) == false
    }

    // MARK: the window

    let window: NSWindow
    let release: Updater.Release
    private let bar = NSProgressIndicator()
    private let status = NSTextField(labelWithString: "")
    private let pins = NSTextField(labelWithString: "")
    private let skip = NSButton(), later = NSButton(), go = NSButton(), stop = NSButton()
    private let working = NSView()
    private var buttons = NSStackView()
    private weak var notes: NSTextView?
    private static let width: CGFloat = 480, side: CGFloat = 24

    private init(_ r: Updater.Release) {
        release = r
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
                          styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        window.title = L.t("softwareUpdate")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self
        build()
        Updater.shared.onChange[ObjectIdentifier(self)] = { [weak self] st in self?.update(st) }
        update(Updater.shared.state)
        window.contentView?.layoutSubtreeIfNeeded()
        notes?.scroll(.zero)                               // from its first line
    }

    private func build() {
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        let title = Self.label(String(format: L.t("updTitle"), release.version), 16, .semibold)
        let from = Self.label(String(format: L.t("updFrom"), Updater.current), 12, .regular, .secondaryLabelColor)
        let names = Self.column([title, from], 3)
        let top = NSStackView(views: [icon, names])
        top.spacing = 14
        top.alignment = .centerY

        var views: [NSView] = [top]
        if release.notes.isEmpty {
            // nothing to show here: the release's page has it
            let page = release.page
            views.append(LinkButton("", L.t("releaseNotes")) { NSWorkspace.shared.open(page) })
        } else {
            views.append(notesBox())
        }

        // what updating means, said before
        let shield = NSImageView(image: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil) ?? NSImage())
        shield.contentTintColor = .secondaryLabelColor
        shield.symbolConfiguration = .init(pointSize: 12, weight: .regular)
        let names2 = Permission.allCases.filter(\.required).map(\.name).joined(separator: L.t("listSep"))
        let perms = Self.label(String(format: L.t("updPerms"), names2), 11.5, .regular, .secondaryLabelColor)
        perms.lineBreakMode = .byWordWrapping
        perms.maximumNumberOfLines = 2
        perms.preferredMaxLayoutWidth = Self.width - Self.side * 2 - 22
        perms.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pins.font = .systemFont(ofSize: 11.5)
        pins.textColor = .secondaryLabelColor
        pins.lineBreakMode = .byWordWrapping
        pins.maximumNumberOfLines = 3
        pins.preferredMaxLayoutWidth = Self.width - Self.side * 2 - 22
        let said = Self.column([perms, pins], 4)
        let warn = NSView()
        for v in [shield, said] {
            v.translatesAutoresizingMaskIntoConstraints = false
            warn.addSubview(v)
        }
        NSLayoutConstraint.activate([
            shield.leadingAnchor.constraint(equalTo: warn.leadingAnchor), shield.widthAnchor.constraint(equalToConstant: 16),
            shield.centerYAnchor.constraint(equalTo: perms.firstBaselineAnchor, constant: -4.3),      // the middle of the first line
            said.leadingAnchor.constraint(equalTo: warn.leadingAnchor, constant: 22), said.trailingAnchor.constraint(equalTo: warn.trailingAnchor),
            said.topAnchor.constraint(equalTo: warn.topAnchor), said.bottomAnchor.constraint(equalTo: warn.bottomAnchor)])
        views.append(warn)

        for (b, t, a) in [(skip, "updSkip", #selector(skipClicked)), (later, "updLater", #selector(laterClicked)),
                          (go, "updGo", #selector(goClicked)), (stop, "updCancel", #selector(stopClicked))] {
            b.title = L.t(t)
            b.bezelStyle = .push
            b.controlSize = .large
            b.target = self
            b.action = a
        }
        go.keyEquivalent = "\r"
        later.keyEquivalent = "\u{1b}"
        let gap = NSView()
        gap.setContentHuggingPriority(.init(1), for: .horizontal)
        buttons = NSStackView(views: [skip, gap, later, go])
        buttons.spacing = 10

        bar.isIndeterminate = false
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 1
        status.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // the bar and Cancel on one line, what is going on under the bar
        stop.setContentHuggingPriority(.required, for: .horizontal)
        for v in [bar, status, stop] {
            v.translatesAutoresizingMaskIntoConstraints = false
            working.addSubview(v)
        }
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: working.leadingAnchor), bar.centerYAnchor.constraint(equalTo: working.centerYAnchor),
            bar.trailingAnchor.constraint(equalTo: stop.leadingAnchor, constant: -14),
            stop.trailingAnchor.constraint(equalTo: working.trailingAnchor), stop.centerYAnchor.constraint(equalTo: working.centerYAnchor),
            status.leadingAnchor.constraint(equalTo: bar.leadingAnchor), status.trailingAnchor.constraint(lessThanOrEqualTo: bar.trailingAnchor),
            status.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 2),
            working.heightAnchor.constraint(equalToConstant: 34)])
        // both in one place of one height: the window does not change when one takes the other's
        let foot = NSView()
        for v in [buttons, working] {
            v.translatesAutoresizingMaskIntoConstraints = false
            foot.addSubview(v)
            NSLayoutConstraint.activate([v.leadingAnchor.constraint(equalTo: foot.leadingAnchor), v.trailingAnchor.constraint(equalTo: foot.trailingAnchor),
                                         v.centerYAnchor.constraint(equalTo: foot.centerYAnchor)])
        }
        foot.heightAnchor.constraint(equalToConstant: 34).isActive = true
        views.append(foot)

        let all = Self.column(views, 14)
        all.edgeInsets = NSEdgeInsets(top: 34, left: Self.side, bottom: 22, right: Self.side)
        for v in views.dropFirst() where !(v is LinkButton) {
            v.widthAnchor.constraint(equalTo: all.widthAnchor, constant: -Self.side * 2).isActive = true
        }
        let root = NSView()
        all.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(all)
        NSLayoutConstraint.activate([all.topAnchor.constraint(equalTo: root.topAnchor), all.bottomAnchor.constraint(equalTo: root.bottomAnchor),
                                     all.leadingAnchor.constraint(equalTo: root.leadingAnchor), all.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                                     all.widthAnchor.constraint(equalToConstant: Self.width)])
        window.contentView = root
    }

    /// What is new, in a box as tall as it needs, up to a point: then it scrolls.
    private func notesBox() -> NSView {
        let w = Self.width - Self.side * 2
        let t = NSTextView(frame: NSRect(x: 0, y: 0, width: w, height: 10))
        t.isEditable = false
        t.drawsBackground = false
        t.textContainerInset = NSSize(width: 8, height: 10)
        t.isVerticallyResizable = true
        t.autoresizingMask = [.width]
        let ps = NSMutableParagraphStyle()
        ps.headIndent = 13
        ps.paragraphSpacing = 6
        ps.lineSpacing = 2
        ps.tabStops = [NSTextTab(textAlignment: .left, location: 13)]
        let s = release.notes.map { "•\t" + $0 }.joined(separator: "\n")
        t.textStorage?.setAttributedString(NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: 12.5), .foregroundColor: NSColor.labelColor, .paragraphStyle: ps]))
        var h: CGFloat = 60
        if let lm = t.layoutManager, let tc = t.textContainer { lm.ensureLayout(for: tc); h = ceil(lm.usedRect(for: tc).height) + 20 }
        t.setFrameSize(NSSize(width: w, height: h))
        let scroll = NSScrollView()
        scroll.documentView = t
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false     // it is not under the title bar
        notes = t
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = 10
        box.borderWidth = 0.5
        box.borderColor = .separatorColor
        box.fillColor = .quaternarySystemFill
        box.contentViewMargins = .zero
        box.contentView = scroll
        box.heightAnchor.constraint(equalToConstant: min(h, 190)).isActive = true
        return box
    }

    private static func label(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        return l
    }
    private static func column(_ v: [NSView], _ spacing: CGFloat) -> NSStackView {
        let s = NSStackView(views: v)
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = spacing
        return s
    }

    // MARK: its states

    private func update(_ st: Updater.State) {
        let n = PinWindow.count
        pins.stringValue = n > 0 ? String(format: L.t("updPins"), n) : ""
        pins.isHidden = n == 0
        var error: String?
        var atWork = true
        stop.isEnabled = true
        status.textColor = .secondaryLabelColor
        switch st {
        case .downloading(let f):
            if bar.isIndeterminate { bar.stopAnimation(nil); bar.isIndeterminate = false }
            bar.doubleValue = f
            let size = Self.megabytes
            status.stringValue = release.size > 0
                ? String(format: L.t("updProgress"), size.string(fromByteCount: Int64(Double(release.size) * f)), size.string(fromByteCount: Int64(release.size)))
                : String(format: L.t("updDownloading"), Int(f * 100))
        case .installing:
            bar.isIndeterminate = true
            bar.startAnimation(nil)
            status.stringValue = L.t("updInstalling")
            stop.isEnabled = false
        case .waiting:
            if bar.isIndeterminate { bar.stopAnimation(nil); bar.isIndeterminate = false }
            bar.doubleValue = 1                               // it is all here
            status.stringValue = L.t("updWaiting")
        case .failed(let m):
            atWork = false
            error = m
        default:
            atWork = false
        }
        buttons.isHidden = atWork
        working.isHidden = !atWork
        if let error {
            pins.stringValue = error                          // said where it is read: over the buttons
            pins.toolTip = error
            pins.textColor = .systemRed
            pins.isHidden = false
            go.title = L.t("updRetry")
        } else {
            pins.textColor = .secondaryLabelColor
            pins.toolTip = nil
            go.title = L.t("updGo")
        }
        // as tall as what it holds, from its top
        let h = window.contentView?.fittingSize.height ?? 300
        let f = window.frame, new = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: Self.width, height: h))
        if abs(new.height - f.height) > 0.5 || f.width != new.width {
            window.setFrame(NSRect(x: f.minX, y: f.maxY - new.height, width: new.width, height: new.height), display: true)
        }
    }
    private static let megabytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB]
        f.countStyle = .file
        return f
    }()

    @objc private func goClicked() {
        Updater.shared.install()
        // an app that cannot be replaced where it is: the release's page is open instead
        if case .available = Updater.shared.state { window.close() }
    }
    @objc private func laterClicked() { window.close() }
    @objc private func skipClicked() { Updater.shared.skip(); window.close() }
    @objc private func stopClicked() { Updater.shared.cancel() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if case .installing = Updater.shared.state { return false }       // a moment, then it is over
        return true
    }
    func windowWillClose(_ n: Notification) {
        Updater.shared.onChange[ObjectIdentifier(self)] = nil
        Updater.shared.cancel()
        if UpdateWindow.shared === self { UpdateWindow.shared = nil }
    }
}
