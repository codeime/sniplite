import AppKit
import ServiceManagement

/// The settings, kept in UserDefaults (~/Library/Preferences/<bundle id>.plist).
final class Prefs {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    var language: String {
        get { d.string(forKey: "language") ?? "system" }
        set { d.set(newValue, forKey: "language") }
    }
    var pinOnTop: Bool {
        get { d.object(forKey: "pinOnTop") as? Bool ?? true }
        set { d.set(newValue, forKey: "pinOnTop") }
    }
    /// The F1–F12 shortcuts on Mac keyboards (an event tap; needs the Accessibility permission).
    var topRowKeys: Bool { true }   // always: F1 should just work, as on Windows
    /// Text recognition: its buttons, menu items and F4 / ⇧F4. Off until turned on.
    var ocrEnabled: Bool {
        get { d.object(forKey: "ocrEnabled") as? Bool ?? false }
        set { d.set(newValue, forKey: "ocrEnabled") }
    }
    /// Index into Palette.colors and Palette.sizes, remembered between captures.
    var colorIndex: Int {
        get { d.object(forKey: "colorIndex") as? Int ?? 0 }
        set { d.set(newValue, forKey: "colorIndex") }
    }
    /// The width of the drawing tools (also sets text size, number size and mosaic squares).
    /// Where ⇧F1 (quick capture) saves: the Desktop unless chosen.
    var quickFolder: URL {
        get {
            if let p = d.string(forKey: "quickFolder") { return URL(fileURLWithPath: p, isDirectory: true) }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        set { d.set(newValue.path, forKey: "quickFolder") }
    }
    /// ⇧F1 quick capture (and its menu item): off until turned on.
    var quickEnabled: Bool {
        get { d.object(forKey: "quickEnabled") as? Bool ?? false }
        set { d.set(newValue, forKey: "quickEnabled") }
    }
    /// After a quick capture: a banner (with the path), or only the menu bar scissors snipping.
    var quickNotice: Bool {
        get { d.object(forKey: "quickNotice") as? Bool ?? false }
        set { d.set(newValue, forKey: "quickNotice") }
    }
    /// Where that banner shows: "topRight", "bottomRight", "topCenter" or "center".
    var noticePosition: String {
        get { d.string(forKey: "noticePosition") ?? "topRight" }
        set { d.set(newValue, forKey: "noticePosition") }
    }
    /// Ask before leaving a capture that has drawings (Esc, ✕, right-click back).
    var askBeforeLeaving: Bool {
        get { d.object(forKey: "askBeforeLeaving") as? Bool ?? true }
        set { d.set(newValue, forKey: "askBeforeLeaving") }
    }
    /// The capture toolbar: "system" (follows macOS), "light" or "dark".
    var toolbarTheme: String {
        get { d.string(forKey: "toolbarTheme") ?? "system" }
        set { d.set(newValue, forKey: "toolbarTheme") }
    }

    /// Each tool has its own size, remembered between captures; one does not change another.
    /// The defaults are on the small side: lines 3 px, text about 17 pt, numbers about 19 pt across.
    static let defaultWidths: [Tool: CGFloat] = [.rect: 3, .ellipse: 3, .line: 3, .arrow: 3, .pen: 3,
                                                  .marker: 3, .mosaic: 4, .text: 3, .number: 3]
    private var widths: [Tool: CGFloat] = [:]

    func width(for t: Tool) -> CGFloat {
        if let w = widths[t] { return w }
        let w = (d.object(forKey: "width.\(t)") as? Double).map { CGFloat($0) } ?? Self.defaultWidths[t] ?? 3
        widths[t] = w
        return w
    }

    /// Each tool's opacity too (1 = opaque), remembered between captures.
    private var opacities: [Tool: CGFloat] = [:]
    func opacity(for t: Tool) -> CGFloat {
        if let o = opacities[t] { return o }
        let o = (d.object(forKey: "opacity.\(t)") as? Double).map { CGFloat($0) } ?? 1
        opacities[t] = o
        return o
    }
    func setOpacity(_ o: CGFloat, for t: Tool) {
        opacities[t] = o
        d.set(Double(o), forKey: "opacity.\(t)")
    }

    func setWidth(_ w: CGFloat, for t: Tool) {
        widths[t] = w
        d.set(Double(w), forKey: "width.\(t)")
    }
    var mosaicMode: MosaicMode {
        get { MosaicMode(rawValue: d.string(forKey: "mosaicMode") ?? "") ?? .rect }   // "fill" from before: a box
        set { d.set(newValue.rawValue, forKey: "mosaicMode") }
    }
    /// The hide tool covers with the color instead of mosaic.
    var mosaicSolid: Bool {
        get { d.bool(forKey: "mosaicSolid") }
        set { d.set(newValue, forKey: "mosaicSolid") }
    }

    /// nil: no shortcut for that action.
    func hotkey(_ a: HotAction) -> HotKey? {
        let key = "hotkey." + a.rawValue
        guard let data = d.data(forKey: key) else { return a.defaultKey }
        if data.isEmpty { return nil }
        return (try? JSONDecoder().decode(HotKey.self, from: data)) ?? a.defaultKey
    }
    func setHotkey(_ a: HotAction, _ k: HotKey?) {
        let key = "hotkey." + a.rawValue
        if let k, let data = try? JSONEncoder().encode(k) { d.set(data, forKey: key) } else { d.set(Data(), forKey: key) }
    }
}

/// A field that records a shortcut: click it, then press the keys. Delete or Backspace clears it.
final class HotKeyField: NSButton {
    var hotkey: HotKey? { didSet { refresh() } }
    var onChange: ((HotKey?) -> Void)?
    private var recording = false { didSet { refresh(); HotKeyField.active = recording ? self : nil } }

    /// The field recording now: the event tap hands it the F keys (it would run their shortcuts
    /// otherwise, since on a Mac keyboard F1 without fn never reaches a key-down here).
    static weak var active: HotKeyField?

    /// An F key seen by the event tap while recording.
    func takeFKey(_ code: Int, mods: UInt32) {
        guard recording, let label = HotKey.fKeys[code] else { return }
        hotkey = HotKey(keyCode: UInt32(code), mods: mods, label: label)
        onChange?(hotkey)
        window?.makeFirstResponder(nil)
    }

    init(_ k: HotKey?) {
        hotkey = k
        super.init(frame: .zero)
        bezelStyle = .push
        controlSize = .small
        font = .monospacedSystemFont(ofSize: 11.5, weight: .medium)
        setButtonType(.momentaryPushIn)
        target = self; action = #selector(start)
        widthAnchor.constraint(equalToConstant: 120).isActive = true
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        title = recording ? L.t("recordHint") : (hotkey?.display ?? L.t("none"))
    }

    @objc private func start() {
        recording = true
        HotKeyCenter.shared.unregisterAll()   // so the old shortcut can be pressed again
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }
    override func resignFirstResponder() -> Bool {
        if recording { recording = false; HotKeyCenter.shared.registerAll() }
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        if recording { keyDown(with: e); return true }
        return super.performKeyEquivalent(with: e)
    }

    override func keyDown(with e: NSEvent) {
        guard recording else { super.keyDown(with: e); return }
        let code = Int(e.keyCode)
        if code == 0x35 { window?.makeFirstResponder(nil); return }                // Esc: keep the old one
        if (code == 0x33 || code == 0x75) && e.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            hotkey = nil                                                           // Backspace / Delete
        } else {
            guard let label = HotKey.label(for: e) else { return }
            let mods = HotKey.carbonMods(e.modifierFlags)
            let isF = HotKey.fKeys[code] != nil
            if mods == 0 && !isF { NSSound.beep(); return }   // a plain letter would block typing everywhere
            hotkey = HotKey(keyCode: UInt32(code), mods: mods, label: label)
        }
        onChange?(hotkey)
        window?.makeFirstResponder(nil)
    }
}

/// Settings, in the style of System Settings: grouped cards, a switch at the end of each row.
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    static var shared: SettingsWindow?

    static func show() {
        if shared == nil { shared = SettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        shared?.window?.center()
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        shared?.refreshPermissions()
    }

    private let width: CGFloat = 500

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]   // opens on the current desktop
        w.title = L.t("settings").replacingOccurrences(of: "…", with: "")
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: building blocks

    /// A row: a colored icon, the title (and a smaller line under it), then the control at the end.
    private func row(_ icon: (String, NSColor)?, _ title: String, _ detail: String? = nil, _ control: NSView) -> NSStackView {
        let t = NSTextField(labelWithString: title)
        t.font = .systemFont(ofSize: 13)
        var texts: [NSView] = [t]
        if let detail {
            let d = NSTextField(wrappingLabelWithString: detail)
            d.font = .systemFont(ofSize: 11)
            d.textColor = .secondaryLabelColor
            d.preferredMaxLayoutWidth = 280
            d.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
            // a window's fitting size counts a wrapped label as one line: say how tall it is
            let h = d.attributedStringValue.boundingRect(with: NSSize(width: 274, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
            d.heightAnchor.constraint(greaterThanOrEqualToConstant: ceil(h)).isActive = true
            texts.append(d)
        }
        let text = NSStackView(views: texts)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        text.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        var views: [NSView] = [text, spacer, control]
        if let (symbol, color) = icon { views.insert(IconTile(symbol, color), at: 0) }
        let r = NSStackView(views: views)
        r.alignment = .centerY
        r.spacing = 10
        r.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        r.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        r.heightAnchor.constraint(greaterThanOrEqualTo: text.heightAnchor, constant: 16).isActive = true   // never clip the text
        return r
    }

    /// Rows in one card, with hairlines between them that start under the text, as in System Settings.
    private func group(_ rows: [NSView]) -> NSView {
        var views: [NSView] = []
        for (i, r) in rows.enumerated() {
            if i > 0 {
                let line = NSBox()
                line.boxType = .separator
                let inset = NSStackView(views: [line])
                inset.edgeInsets = NSEdgeInsets(top: 0, left: 46, bottom: 0, right: 12)
                views.append(inset)
            }
            views.append(r)
        }
        let st = NSStackView(views: views)
        st.orientation = .vertical
        st.spacing = 0
        for v in views { v.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true }
        return card(st, inset: 0, soft: true)
    }

    /// A small grey line under a card.
    private func note(_ s: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.preferredMaxLayoutWidth = width - 64
        return l
    }

    /// A card with a heading above it and a note under it.
    private func section(_ title: String?, _ rows: [NSView], _ foot: NSView? = nil) -> NSView {
        var views: [NSView] = []
        if let title {
            let l = NSTextField(labelWithString: title)
            l.font = .systemFont(ofSize: 12, weight: .semibold)
            l.textColor = .secondaryLabelColor
            let h = NSStackView(views: [l])
            h.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            views.append(h)
        }
        let g = group(rows)
        views.append(g)
        if let foot {
            let f = NSStackView(views: [foot])
            f.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
            views.append(f)
        }
        let st = NSStackView(views: views)
        st.orientation = .vertical
        st.alignment = .leading
        st.spacing = 6
        for v in views { v.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true }
        return st
    }

    private func toggle(_ on: Bool, _ action: Selector) -> NSSwitch {
        let s = NSSwitch()
        s.controlSize = .small
        s.state = on ? .on : .off
        s.target = self
        s.action = action
        return s
    }

    private func popup(_ items: [(String, String)], _ current: String, _ action: Selector) -> NSPopUpButton {
        let p = NSPopUpButton()
        p.controlSize = .small
        for (code, title) in items {
            p.addItem(withTitle: title); p.lastItem?.representedObject = code
            if current == code { p.select(p.lastItem) }
        }
        p.target = self; p.action = action
        return p
    }

    /// Rows that only matter while another setting is on stay visible, quieter and out of reach.
    private func setActive(_ v: NSView?, _ on: Bool) {
        guard let v else { return }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; v.animator().alphaValue = on ? 1 : 0.4 }
        func walk(_ v: NSView) { (v as? NSControl)?.isEnabled = on; v.subviews.forEach(walk) }
        walk(v)
    }

    // MARK: the pages

    private var keyRows: [HotAction: NSView] = [:]
    private var folderRow, noticeRow, placeRow: NSView?
    private let keyNote = NSTextField(wrappingLabelWithString: "")
    private let generalNote = NSTextField(wrappingLabelWithString: "")
    private var permRights: [Permission: NSStackView] = [:]
    private var pages: [NSViewController] = []

    private func build() {
        // shortcuts
        let keyIcons: [HotAction: (String, NSColor)] = [
            .capture: ("scissors", .systemBlue), .quickCapture: ("camera.fill", .systemIndigo),
            .pinClipboard: ("pin.fill", .systemOrange), .togglePins: ("eye.slash.fill", .systemTeal),
            .ocr: ("text.viewfinder", .systemGreen), .ocrCopy: ("doc.on.doc.fill", .systemMint)]
        var rows: [NSView] = []
        for a in HotAction.allCases {
            let f = HotKeyField(Prefs.shared.hotkey(a))
            f.onChange = { [weak self] k in
                Prefs.shared.setHotkey(a, k)
                let failed = HotKeyCenter.shared.registerAll()
                self?.say(failed.contains(a) ? L.t("hkConflict") : L.t("hkFoot"), in: self?.keyNote, error: failed.contains(a))
            }
            let r = row(keyIcons[a], a.title, nil, f)
            keyRows[a] = r
            rows.append(r)
        }
        for l in [keyNote, generalNote] {
            l.font = .systemFont(ofSize: 11)
            l.textColor = .secondaryLabelColor
            l.preferredMaxLayoutWidth = width - 64
        }
        keyNote.stringValue = L.t("hkFoot")
        let shortcuts = section(nil, rows, keyNote)

        // general
        let general = stack([
            section(L.t("secCapture"), [
                row(("text.viewfinder", .systemGreen), L.t("ocrTitle2"), L.t("ocrDetail"), toggle(Prefs.shared.ocrEnabled, #selector(toggleOCR(_:)))),
                row(("exclamationmark.bubble.fill", .systemYellow), L.t("askLeave"), nil, toggle(Prefs.shared.askBeforeLeaving, #selector(toggleAskLeave(_:)))),
                row(("circle.lefthalf.filled", .systemGray), L.t("toolbarTheme"), nil,
                    popup([("system", L.t("themeSystem")), ("light", L.t("themeLight")), ("dark", L.t("themeDark"))],
                          Prefs.shared.toolbarTheme, #selector(pickTheme(_:)))),
            ]),
            section(L.t("secPins"), [
                row(("pin.fill", .systemOrange), L.t("pinTop"), nil, toggle(Prefs.shared.pinOnTop, #selector(togglePinTop(_:)))),
            ]),
            section(L.t("secApp"), [
                row(("power", .systemPink), L.t("launchAtLogin"), nil, toggle(SMAppService.mainApp.status == .enabled, #selector(toggleLogin(_:)))),
                row(("globe", .systemBlue), L.t("language"), nil,
                    popup([(L.Lang.system.rawValue, L.t("langSystem")), (L.Lang.en.rawValue, "English"),
                           (L.Lang.zhHans.rawValue, "简体中文"), (L.Lang.zhHant.rawValue, "繁體中文")],
                          Prefs.shared.language, #selector(pickLang(_:)))),
            ], generalNote),
        ])

        // quick capture
        folderButton.controlSize = .small
        folderButton.bezelStyle = .push
        folderButton.target = self
        folderButton.action = #selector(chooseFolder)
        folderButton.title = folderTitle()
        folderButton.lineBreakMode = .byTruncatingMiddle
        folderButton.widthAnchor.constraint(lessThanOrEqualToConstant: 190).isActive = true
        let fr = row(("folder.fill", .systemCyan), L.t("quickFolder"), nil, folderButton)
        let nr = row(("bell.badge.fill", .systemRed), L.t("quickNotice"), L.t("quickNoticeDetail"),
                     toggle(Prefs.shared.quickNotice, #selector(toggleQuickNotice(_:))))
        let pr = row(("macwindow", .systemGray), L.t("noticePosition"), nil,
                     popup([("topRight", L.t("posTopRight")), ("bottomRight", L.t("posBottomRight")),
                            ("topCenter", L.t("posTopCenter")), ("center", L.t("posCenter"))],
                           Prefs.shared.noticePosition, #selector(pickNoticePlace(_:))))
        (folderRow, noticeRow, placeRow) = (fr, nr, pr)
        let quick = stack([
            section(nil, [
                row(("camera.fill", .systemIndigo), L.t("quickEnable"), L.t("quickFolderDetail"),
                    toggle(Prefs.shared.quickEnabled, #selector(toggleQuick(_:)))),
                fr,
            ]),
            section(L.t("secNotice"), [nr, pr]),
        ])

        // permissions: each one, its state, and the way to allow it
        var permRows: [NSView] = []
        for p in Permission.allCases {
            let right = NSStackView()
            right.spacing = 5
            right.alignment = .centerY
            permRights[p] = right
            permRows.append(row(p == .screenRecording ? ("record.circle", .systemPurple) : ("accessibility", .systemBlue),
                                p.name, p.purpose, right))
        }
        let perms = section(nil, permRows, note(L.t("permFoot")))

        // the pages in a macOS settings toolbar: icons above names, the window as tall as each page
        let pageList: [(String, String, NSView)] = [("keyboard", L.t("hotkeys"), shortcuts),
                                                  ("gearshape", L.t("general"), general),
                                                  ("camera.viewfinder", L.t("quickTab"), quick),
                                                  ("lock.shield", L.t("permissions"), perms)]
        let tabs = SettingsTabs()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]
        for (symbol, name, page) in pageList {
            let host = NSView()
            page.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 24),
                page.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -24),
                page.topAnchor.constraint(equalTo: host.topAnchor, constant: 18),
                page.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -24),
                host.widthAnchor.constraint(equalToConstant: width),
            ])
            let vc = NSViewController()
            vc.view = host
            vc.title = name
            pages.append(vc)
            let item = NSTabViewItem(viewController: vc)
            item.label = name
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: name)
            tabs.addTabViewItem(item)
        }
        refit()
        window?.styleMask.remove(.fullSizeContentView)
        window?.titlebarAppearsTransparent = false
        window?.isMovableByWindowBackground = false
        window?.toolbarStyle = .preference
        window?.contentViewController = tabs
        window?.title = pageList[0].1
        quickChanged()
        refreshPermissions()
    }

    private func stack(_ views: [NSView]) -> NSView {
        let st = NSStackView(views: views)
        st.orientation = .vertical
        st.alignment = .leading
        st.spacing = 20
        for v in views { v.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true }
        return st
    }

    /// Each page as tall as what it holds; the window follows when its page grows.
    private func refit() {
        for vc in pages {
            // measured at its real width: a card's content follows the card's frame
            if vc.view.frame.width != width { vc.view.setFrameSize(NSSize(width: width, height: 600)) }
            vc.view.layoutSubtreeIfNeeded()
            vc.preferredContentSize = vc.view.fittingSize
            // the page on show: grow or shrink the window from its top edge
            if let w = window, vc.view.window === w {
                let old = w.frame
                let content = w.frameRect(forContentRect: NSRect(origin: .zero, size: vc.preferredContentSize))
                guard abs(content.height - old.height) > 0.5 else { continue }
                w.setFrame(NSRect(x: old.minX, y: old.maxY - content.height, width: old.width, height: content.height),
                           display: true, animate: true)
            }
        }
    }

    private func say(_ s: String, in l: NSTextField?, error: Bool = false) {
        guard let l else { return }
        l.stringValue = s
        l.textColor = error ? .systemRed : .secondaryLabelColor
        refit()
    }

    private func quickChanged() {
        let q = Prefs.shared.quickEnabled
        keyRows[.quickCapture]?.alphaValue = q ? 1 : 0.4
        for a in [HotAction.ocr, .ocrCopy] { keyRows[a]?.alphaValue = Prefs.shared.ocrEnabled ? 1 : 0.4 }
        setActive(folderRow, q)
        setActive(noticeRow, q)
        setActive(placeRow, q && Prefs.shared.quickNotice)
    }

    private func refreshPermissions() {
        for (p, right) in permRights {
            right.arrangedSubviews.forEach { $0.removeFromSuperview() }
            if p.granted {
                let i = NSImageView(image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) ?? NSImage())
                i.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
                i.contentTintColor = .systemGreen
                let t = NSTextField(labelWithString: L.t("granted"))
                t.font = .systemFont(ofSize: 12)
                t.textColor = .secondaryLabelColor
                right.addArrangedSubview(i)
                right.addArrangedSubview(t)
            } else {
                let b = NSButton(title: L.t("grant"), target: self, action: #selector(openPermissions))
                b.controlSize = .small
                b.bezelStyle = .push
                b.keyEquivalent = "\r"
                right.addArrangedSubview(b)
            }
        }
        refit()
    }

    // MARK: actions

    @objc private func toggleLogin(_ b: NSSwitch) {
        do {
            if b.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            say(error.localizedDescription, in: generalNote, error: true)
            b.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func toggleOCR(_ b: NSSwitch) {
        Prefs.shared.ocrEnabled = b.state == .on
        HotKeyCenter.shared.registerAll()
        quickChanged()
    }

    @objc private func togglePinTop(_ b: NSSwitch) {
        Prefs.shared.pinOnTop = b.state == .on
        PinWindow.applyLevelToAll()
    }

    @objc private func pickLang(_ p: NSPopUpButton) {
        Prefs.shared.language = p.selectedItem?.representedObject as? String ?? "system"
        say(L.t("langRestart"), in: generalNote)
    }

    @objc private func openPermissions() { PermissionsWindow.show() }

    private let folderButton = NSButton(title: "", target: nil, action: nil)

    private func folderTitle() -> String {
        FileManager.default.displayName(atPath: Prefs.shared.quickFolder.path)
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = Prefs.shared.quickFolder
        panel.prompt = L.t("chooseFolder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Prefs.shared.quickFolder = url
        folderButton.title = folderTitle()
    }

    @objc private func toggleQuick(_ b: NSSwitch) {
        Prefs.shared.quickEnabled = b.state == .on
        HotKeyCenter.shared.registerAll()
        quickChanged()
    }

    @objc private func toggleQuickNotice(_ b: NSSwitch) { Prefs.shared.quickNotice = b.state == .on; quickChanged() }

    @objc private func pickNoticePlace(_ p: NSPopUpButton) {
        Prefs.shared.noticePosition = p.selectedItem?.representedObject as? String ?? "topRight"
    }

    @objc private func toggleAskLeave(_ b: NSSwitch) { Prefs.shared.askBeforeLeaving = b.state == .on }

    @objc private func pickTheme(_ p: NSPopUpButton) {
        Prefs.shared.toolbarTheme = p.selectedItem?.representedObject as? String ?? "system"
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshPermissions() }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

/// The settings toolbar; the window is named after the page it shows.
private final class SettingsTabs: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {
        super.tabView(tabView, didSelect: item)
        if let item { view.window?.title = item.label }
    }
}

/// A rounded square of color with a white symbol, as beside each row of System Settings.
private final class IconTile: NSView {
    private let color: NSColor
    init(_ symbol: String, _ color: NSColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        let img = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        img.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        img.contentTintColor = .white
        img.translatesAutoresizingMaskIntoConstraints = false
        addSubview(img)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24), heightAnchor.constraint(equalToConstant: 24),
            img.centerXAnchor.constraint(equalTo: centerXAnchor), img.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSGradient(starting: color.blended(withFraction: 0.22, of: .white) ?? color, ending: color)?.draw(in: path, angle: -90)
    }
}
